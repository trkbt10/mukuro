///|
/// Chat API Handlers
/// HTTP handlers for /api/v1/chat/* endpoints
/// Manages web chat sessions and conversation history

///|
/// Chat state holder
pub(all) struct ChatState {
  session_store : &@interfaces.SessionStore
}

///|
/// Create new chat state
pub fn ChatState::new(
  session_store : &@interfaces.SessionStore,
) -> ChatState {
  { session_store, }
}

///|
/// Create chat handlers
pub fn create_chat_handlers(state : ChatState) -> @api.ChatApiHandlers {
  {
    list_sessions: @api.RouteHandler(fn(ctx) { handle_list_sessions(state, ctx) }),
    get_history: @api.RouteHandler(fn(ctx) { handle_get_history(state, ctx) }),
    delete_session: @api.RouteHandler(
      fn(ctx) { handle_delete_session(state, ctx) },
    ),
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
        500,
        "internal_error",
        "Failed to list sessions",
      )
  }
  let sessions : Array[Json] = []
  for key in keys {
    if key.channel == "web_chat" {
      let session = state.session_store.get(key) catch { _ => continue }
      match session {
        Some(s) =>
          sessions.push(
            {
              "chat_id": key.chat_id.to_json(),
              "message_count": s.history.length().to_json(),
              "created_at": s.created_at.to_double().to_json(),
              "last_active_at": s.last_active_at.to_double().to_json(),
            },
          )
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
  let key = @types.SessionKey::new(
    channel="web_chat",
    chat_id~,
    user_id=None,
  )
  let session = state.session_store.get(key) catch {
    _ =>
      return @api.error_response(
        500,
        "internal_error",
        "Failed to retrieve session",
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
  @api.json_response(
    200,
    {
      "data": {
        "chat_id": chat_id.to_json(),
        "messages": Json::array(messages),
      },
    },
  )
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
  let key = @types.SessionKey::new(
    channel="web_chat",
    chat_id~,
    user_id=None,
  )
  state.session_store.delete(key) catch {
    _ =>
      return @api.error_response(
        500,
        "internal_error",
        "Failed to delete session",
      )
  }
  @api.json_response(200, { "ok": true })
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
          {
            "role": "user",
            "content": content.to_json(),
            "name": n.to_json(),
          }
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
