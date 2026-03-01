///|
/// WebSocket Chat Handler (Native)
/// Direct browser WebSocket connections for /ws/chat endpoint

///|
/// Chat WebSocket message types
pub(all) enum ChatWsMessageType {
  Send
  LoadHistory
  Ping
  Unknown
} derive(Eq, Show)

///|
/// Chat WebSocket handler dependencies
pub(all) struct ChatWsDeps {
  /// Session store for managing chat sessions
  session_store : &@interfaces.SessionStore
  /// Agent handler: process inbound message and return response
  agent_handler : async (@types.InboundEnvelope) -> @types.OutboundMessage raise
  /// Generate unique chat_id
  generate_chat_id : () -> String
  /// Get current timestamp in milliseconds
  get_timestamp : () -> Int64
}

///|
/// Chat WebSocket handler
pub struct ChatWsHandler {
  deps : ChatWsDeps
  chat_id : String
}

///|
/// Create new chat WebSocket handler
pub fn ChatWsHandler::new(deps : ChatWsDeps) -> ChatWsHandler {
  let chat_id = (deps.generate_chat_id)()
  { deps, chat_id }
}

///|
/// Parse incoming WebSocket message
pub fn parse_chat_ws_message(
  text : String,
) -> (ChatWsMessageType, String?, String?) {
  let json : Json = @json.parse(text) catch { _ => return (Unknown, None, None) }
  match json {
    Object(obj) => {
      let msg_type = match obj.get("type") {
        Some(String("send")) => Send
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
  ws.send_text(json.stringify()) catch { _ => () }
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
/// Create session in session store
fn ChatWsHandler::create_session(self : ChatWsHandler) -> Unit {
  let timestamp = (self.deps.get_timestamp)()
  let key = @types.SessionKey::new(
    channel="web_chat",
    chat_id=self.chat_id,
    user_id=None,
  )
  let session = @types.Session::new(key, timestamp)
  self.deps.session_store.save(session) catch { _ => () }
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
  let envelope : @types.InboundEnvelope = {
    channel: "web_chat",
    chat_id: self.chat_id,
    sender_id: "dashboard_user",
    sender_name: sender_name.unwrap_or("User"),
    content,
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: (self.deps.get_timestamp)(),
  }
  let outbound = (self.deps.agent_handler)(envelope) catch {
    e => {
      ws_send_error(ws, "Agent handler failed: \{e}", None)
      return
    }
  }
  ws_send_message(
    ws,
    "assistant",
    outbound.content,
    (self.deps.get_timestamp)(),
  )
}

///|
/// Handle "load_history" message
async fn ChatWsHandler::handle_load_history(
  self : ChatWsHandler,
  ws : @async_ws.Conn,
) -> Unit {
  let key = @types.SessionKey::new(
    channel="web_chat",
    chat_id=self.chat_id,
    user_id=None,
  )
  let session = self.deps.session_store.get(key) catch { _ => None }
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
              None => messages.push({ "role": "user", "content": content.to_json() })
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
  // Create session and send assignment
  self.create_session()
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
          LoadHistory => self.handle_load_history(ws)
          Ping => ws_send_pong(ws)
          Unknown => ws_send_error(ws, "Unknown message type", None)
        }
      }
      @async_ws.Binary => ws_send_error(ws, "Binary messages not supported", None)
    }
  }
}
