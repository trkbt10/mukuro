///|
/// WebSocket Chat Handler (Native)
/// Direct browser WebSocket connections for /ws/chat endpoint

///|
/// Chat WebSocket message types
pub(all) enum ChatWsMessageType {
  Send
  SendStream
  LoadHistory
  Ping
  Unknown
} derive(Eq, Show)

///|
/// Chat WebSocket handler
/// SessionManager を source of truth として使用
pub struct ChatWsHandler {
  chat_id : String
}

///|
/// Create new chat WebSocket handler
/// If resume_chat_id is provided, use it instead of generating a new one
pub fn ChatWsHandler::new(resume_chat_id? : String? = None) -> ChatWsHandler {
  let chat_id = match resume_chat_id {
    Some(id) => id
    None => generate_ws_chat_id()
  }
  { chat_id, }
}

///|
/// Parse incoming WebSocket message
pub fn parse_chat_ws_message(
  text : String,
) -> (ChatWsMessageType, String?, String?) {
  let json : Json = @json.parse(text) catch {
    _ => return (Unknown, None, None)
  }
  match json {
    Object(obj) => {
      let msg_type = match obj.get("type") {
        Some(String("send")) => Send
        Some(String("send_stream")) => SendStream
        Some(String("load_history")) => LoadHistory
        Some(String("ping")) => Ping
        _ => Unknown
      }
      let content = match obj.get("content") {
        Some(String(s)) => Some(s)
        _ => None
      }
      let sender_name = match obj.get("sender_name") {
        Some(String(s)) => Some(s)
        _ => None
      }
      (msg_type, content, sender_name)
    }
    _ => (Unknown, None, None)
  }
}

///|
/// Send JSON message over WebSocket
async fn ws_send_json(ws : @async_ws.Conn, json : Json) -> Unit {
  ws.send_text(json.stringify()) catch {
    _ => ()
  }
}

///|
/// Send session assignment message
async fn ws_send_session(ws : @async_ws.Conn, chat_id : String) -> Unit {
  ws_send_json(ws, { "type": "session", "chat_id": Json::string(chat_id) })
}

///|
/// Send status message
async fn ws_send_status(ws : @async_ws.Conn, status : String) -> Unit {
  ws_send_json(ws, { "type": "status", "status": Json::string(status) })
}

///|
/// Send chat message response
async fn ws_send_message(
  ws : @async_ws.Conn,
  role : String,
  content : String,
  timestamp : Int64,
) -> Unit {
  ws_send_json(ws, {
    "type": "message",
    "role": Json::string(role),
    "content": Json::string(content),
    "timestamp": Json::number(timestamp.to_double()),
  })
}

///|
/// Send history response
async fn ws_send_history(ws : @async_ws.Conn, messages : Array[Json]) -> Unit {
  ws_send_json(ws, { "type": "history", "messages": Json::array(messages) })
}

///|
/// Send error message
async fn ws_send_error(
  ws : @async_ws.Conn,
  error : String,
  code : String?,
) -> Unit {
  let obj : Map[String, Json] = {
    "type": Json::string("error"),
    "error": Json::string(error),
  }
  match code {
    Some(c) => obj["code"] = Json::string(c)
    None => ()
  }
  ws_send_json(ws, Json::object(obj))
}

///|
/// Send pong response
async fn ws_send_pong(ws : @async_ws.Conn) -> Unit {
  ws_send_json(ws, { "type": "pong" })
}

///|
fn get_timestamp_ms() -> Int64 {
  @native.c_time() * 1000
}

///|
/// Create or reuse session using SessionManager
/// SessionManager reads from History (JSONL) as source of truth
/// Returns true if this is an existing (resumed) session
fn ChatWsHandler::ensure_session(self : ChatWsHandler) -> Bool {
  let key = @types.SessionKey::new(
    channel="web_chat",
    chat_id=self.chat_id,
    user_id=None,
  )
  // Check if session already exists in History (source of truth)
  let existing = get_global_session_manager().get(key) catch { _ => None }
  match existing {
    Some(_) => true // Session exists (loaded from History), don't overwrite
    None => {
      // Create new session via SessionManager
      let timestamp = get_timestamp_ms()
      ignore(
        get_global_session_manager().get_or_create(key, now=timestamp) catch {
          _ => @types.Session::new(key, timestamp)
        },
      )
      false
    }
  }
}

///|
/// Handle "send" message - dispatch to agent loop
async fn ChatWsHandler::handle_send(
  self : ChatWsHandler,
  ws : @async_ws.Conn,
  content : String,
  sender_name : String?,
) -> Unit {
  ws_send_status(ws, "thinking")
  let timestamp = get_timestamp_ms()
  let envelope : @types.InboundEnvelope = {
    channel: "web_chat",
    chat_id: self.chat_id,
    sender_id: "dashboard_user",
    sender_name: sender_name.unwrap_or("User"),
    content,
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp,
  }
  // SessionManager handles all history recording - no separate recorder needed
  let outbound = handle_inbound_with_agent_loop(envelope, None) catch {
    e => {
      ws_send_error(ws, "Agent handler failed: \{e}", None)
      return
    }
  }
  ws_send_message(ws, "assistant", outbound.content, get_timestamp_ms())
}

///|
/// Send streaming event over WebSocket
async fn ws_send_stream_event(
  ws : @async_ws.Conn,
  event_type : String,
  data : Json,
) -> Unit {
  ws_send_json(ws, {
    "type": "stream",
    "event": Json::string(event_type),
    "data": data,
  })
}

///|
/// Handle "send_stream" message - simulated streaming with Harmony translation
/// Uses non-streaming model call but emits Responses API events for translation verification
async fn ChatWsHandler::handle_send_stream(
  self : ChatWsHandler,
  ws : @async_ws.Conn,
  content : String,
  sender_name : String?,
) -> Unit {
  ws_send_status(ws, "streaming")
  let timestamp = get_timestamp_ms()
  let envelope : @types.InboundEnvelope = {
    channel: "web_chat",
    chat_id: self.chat_id,
    sender_id: "dashboard_user",
    sender_name: sender_name.unwrap_or("User"),
    content,
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp,
  }
  // Use agent loop (which uses translation layer when use_responses_api: true with Groq)
  let outbound = handle_inbound_with_agent_loop(envelope, None) catch {
    e => {
      ws_send_error(ws, "Agent handler failed: \{e}", None)
      return
    }
  }
  // Convert response to Responses API stream events for translation verification
  let response = @types.ModelResponse::Text(outbound.content)
  let stream_events = model_response_to_stream_events(response)
  // Send each translated event
  for evt in stream_events {
    ws_send_stream_event(ws, evt.0, evt.1)
  }
  // Send final message
  ws_send_message(ws, "assistant", outbound.content, get_timestamp_ms())
}

///|
/// Handle "load_history" message
/// Uses SessionManager which reads from History (JSONL) as source of truth
async fn ChatWsHandler::handle_load_history(
  self : ChatWsHandler,
  ws : @async_ws.Conn,
) -> Unit {
  let key = @types.SessionKey::new(
    channel="web_chat",
    chat_id=self.chat_id,
    user_id=None,
  )
  // SessionManager.get() reads from History (JSONL) and materializes Session
  let session = get_global_session_manager().get(key) catch { _ => None }
  let messages : Array[Json] = []
  match session {
    Some(s) =>
      for msg in s.history {
        match msg {
          @types.ModelMessage::User(content~, name~) =>
            match name {
              Some(n) =>
                messages.push({
                  "role": "user",
                  "content": content.to_json(),
                  "name": n.to_json(),
                })
              None =>
                messages.push({ "role": "user", "content": content.to_json() })
            }
          @types.ModelMessage::Assistant(content~, ..) =>
            messages.push({ "role": "assistant", "content": content.to_json() })
          _ => ()
        }
      }
    None => ()
  }
  ws_send_history(ws, messages)
}

///|
/// Handle a single WebSocket chat connection
/// This is the main message loop
pub async fn ChatWsHandler::handle_connection(
  self : ChatWsHandler,
  ws : @async_ws.Conn,
) -> Unit {
  // Create or reuse session via SessionManager (records SessionMeta for new sessions)
  let _ = self.ensure_session()
  ws_send_session(ws, self.chat_id)

  // Message loop
  for {
    let msg = ws.recv() catch {
      @async_ws.ConnectionClosed(_, _) => break
      _ => break
    }
    match msg.kind {
      @async_ws.Text => {
        let data : &@io.Data = @io.Reader::read_all(msg) catch { _ => continue }
        let text = data.text() catch { _ => continue }
        let (msg_type, content, sender_name) = parse_chat_ws_message(text)
        match msg_type {
          Send =>
            match content {
              Some(c) => self.handle_send(ws, c, sender_name)
              None => ws_send_error(ws, "Missing content", None)
            }
          SendStream =>
            match content {
              Some(c) => self.handle_send_stream(ws, c, sender_name)
              None => ws_send_error(ws, "Missing content", None)
            }
          LoadHistory => self.handle_load_history(ws)
          Ping => ws_send_pong(ws)
          Unknown => ws_send_error(ws, "Unknown message type", None)
        }
      }
      @async_ws.Binary =>
        ws_send_error(ws, "Binary messages not supported", None)
    }
  }

  // Close session via SessionManager on WebSocket disconnect
  let key = @types.SessionKey::new(
    channel="web_chat",
    chat_id=self.chat_id,
    user_id=None,
  )
  get_global_session_manager().close_session(key) catch {
    _ => ()
  }
}
