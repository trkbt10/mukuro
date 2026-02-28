///|
/// Chat API Handlers
/// HTTP handlers for /api/v1/chat/* endpoints
/// Manages web chat sessions and conversation history

///|
/// Chat state holder
pub(all) struct ChatState {
  session_store : &@interfaces.SessionStore
  history_reader : (&@interfaces.HistoryReader)?
}

///|
/// Create new chat state
pub fn ChatState::new(
  session_store : &@interfaces.SessionStore,
  history_reader? : &@interfaces.HistoryReader,
) -> ChatState {
  { session_store, history_reader }
}

///|
/// Create chat handlers
pub fn create_chat_handlers(state : ChatState) -> @api.ChatApiHandlers {
  {
    list_sessions: @api.RouteHandler(fn(ctx) {
      handle_list_sessions(state, ctx)
    }),
    get_history: @api.RouteHandler(fn(ctx) { handle_get_history(state, ctx) }),
    delete_session: @api.RouteHandler(fn(ctx) {
      handle_delete_session(state, ctx)
    }),
    resume_session: @api.RouteHandler(fn(ctx) {
      handle_resume_session(state, ctx)
    }),
  }
}

///|
/// GET /chat/sessions - List web chat sessions
fn handle_list_sessions(
  state : ChatState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let keys = state.session_store.list_keys() catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to list sessions",
      )
  }
  let sessions : Array[Json] = []
  for key in keys {
    if key.channel == "web_chat" {
      let session = state.session_store.get(key) catch { _ => continue }
      match session {
        Some(s) =>
          sessions.push({
            "chat_id": key.chat_id.to_json(),
            "message_count": s.history.length().to_json(),
            "created_at": s.created_at.to_double().to_json(),
            "last_active_at": s.last_active_at.to_double().to_json(),
          })
        None => ()
      }
    }
  }
  @api.json_response(200, { "data": Json::array(sessions) })
}

///|
/// GET /chat/sessions/{chat_id}/history - Get session history
fn handle_get_history(
  state : ChatState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // segments: ["chat", "sessions", "{chat_id}", "history"]
  if ctx.segments.length() < 4 {
    return @api.error_response(400, "bad_request", "chat_id is required")
  }
  let chat_id = ctx.segments[2]
  let key = @types.SessionKey::new(channel="web_chat", chat_id~, user_id=None)
  let session = state.session_store.get(key) catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to retrieve session",
      )
  }
  let messages : Array[Json] = []
  match session {
    Some(s) =>
      for msg in s.history {
        messages.push(model_message_to_json(msg))
      }
    None => ()
  }
  @api.json_response(200, {
    "data": { "chat_id": chat_id.to_json(), "messages": Json::array(messages) },
  })
}

///|
/// DELETE /chat/sessions/{chat_id} - Delete a chat session
fn handle_delete_session(
  state : ChatState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // segments: ["chat", "sessions", "{chat_id}"]
  if ctx.segments.length() < 3 {
    return @api.error_response(400, "bad_request", "chat_id is required")
  }
  let chat_id = ctx.segments[2]
  let key = @types.SessionKey::new(channel="web_chat", chat_id~, user_id=None)
  state.session_store.delete(key) catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to delete session",
      )
  }
  @api.json_response(200, { "ok": true })
}

///|
/// POST /chat/resume - Resume from history session
fn handle_resume_session(
  state : ChatState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let reader = match state.history_reader {
    Some(r) => r
    None =>
      return @api.error_response(
        501, "not_implemented", "History reader not configured",
      )
  }
  // Parse body for session_id
  let obj = match @api.require_json_object(ctx.body) {
    Ok(o) => o
    Err(resp) => return resp
  }
  let session_id = match @api.require_string_field(obj, "session_id") {
    Ok(s) => s
    Err(resp) => return resp
  }
  // Read history records
  let records = reader.read_session(session_id~) catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to read history session",
      )
  }
  if records.length() == 0 {
    return @api.error_response(
      404, "not_found", "Session not found or empty: \{session_id}",
    )
  }
  // Reconstruct messages from history records
  let messages : Array[@types.ModelMessage] = []
  for record in records {
    match record.record_type {
      @interfaces.HistoryRecordType::UserMessage => {
        let content = match record.payload {
          Object(obj) =>
            match obj.get("content") {
              Some(String(s)) => s
              _ => continue
            }
          String(s) => s
          _ => continue
        }
        messages.push(@types.ModelMessage::User(content~, name=None))
      }
      @interfaces.HistoryRecordType::AssistantMessage => {
        let content = match record.payload {
          Object(obj) =>
            match obj.get("content") {
              Some(String(s)) => s
              _ => continue
            }
          String(s) => s
          _ => continue
        }
        messages.push(
          @types.ModelMessage::Assistant(content~, tool_calls=None),
        )
      }
      _ => () // Skip tool calls, session start/end, errors
    }
  }
  // Create new session with resumed history
  // Use first record's timestamp as a base to generate a unique chat_id
  let base_ts = records[0].timestamp
  let chat_id = "resumed_\{base_ts}"
  let key = @types.SessionKey::new(
    channel="web_chat",
    chat_id~,
    user_id=None,
  )
  let session = @types.Session::new(key, base_ts)
  for msg in messages {
    session.add_message(msg)
  }
  state.session_store.save(session) catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to save resumed session",
      )
  }
  @api.json_response(200, { "data": { "chat_id": chat_id.to_json() } })
}

///|
/// Convert ModelMessage to JSON for API response
fn model_message_to_json(msg : @types.ModelMessage) -> Json {
  match msg {
    @types.ModelMessage::System(text) =>
      { "role": "system", "content": text.to_json() }
    @types.ModelMessage::User(content~, name~) =>
      match name {
        Some(n) =>
          { "role": "user", "content": content.to_json(), "name": n.to_json() }
        None => { "role": "user", "content": content.to_json() }
      }
    @types.ModelMessage::Assistant(content~, ..) =>
      { "role": "assistant", "content": content.to_json() }
    @types.ModelMessage::ToolResult(tool_call_id~, content~) =>
      {
        "role": "tool",
        "tool_call_id": tool_call_id.to_json(),
        "content": content.to_json(),
      }
  }
}
