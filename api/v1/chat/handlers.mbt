///|
/// Chat API Handlers
/// HTTP handlers for /api/v1/chat/* endpoints
/// Manages web chat sessions and conversation history
///
/// History is the source of truth - all operations go through SessionManager

///|
/// Chat state holder - uses SessionManager as the single source of truth
pub(all) struct ChatState {
  /// SessionManager: History (JSONL) を唯一の source of truth として使用
  session_manager : &@interfaces.SessionManager
  /// タイムスタンプ取得関数
  get_timestamp : (() -> Int64)?
}

///|
/// Create new chat state with SessionManager
pub fn ChatState::new_with_session_manager(
  session_manager : &@interfaces.SessionManager,
  get_timestamp? : () -> Int64,
) -> ChatState {
  { session_manager, get_timestamp }
}

///|
/// Create chat handlers
pub fn create_chat_handlers(state : ChatState) -> @api.ChatApiHandlers {
  {
    create_session: @api.RouteHandler(fn(ctx) {
      handle_create_session(state, ctx)
    }),
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
/// Generate UUID v4 for chat_id
fn generate_chat_id() -> String {
  let random = @random.Rand::new()
  let bytes = Bytes::makei(16, fn(_i) { random.uint(limit=256U).to_byte() })
  @uuid.from_bytes(bytes).as_version(@uuid.V4).to_string() catch {
    _ => abort("unreachable: 16-byte UUID input is always valid")
  }
}

///|
/// POST /chat/sessions - Create new chat session
fn handle_create_session(
  state : ChatState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let chat_id = generate_chat_id()
  let timestamp = match state.get_timestamp {
    Some(f) => f()
    None => 0L
  }
  let key = @types.SessionKey::new(channel="web_chat", chat_id~, user_id=None)
  // SessionManager 経由でセッション作成（History に永続化される）
  let _ = state.session_manager.get_or_create(key, now=timestamp) catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to create session",
      )
  }
  @api.json_response(200, { "data": { "chat_id": Json::string(chat_id) } })
}

///|
/// GET /chat/sessions - List web chat sessions
fn handle_list_sessions(
  state : ChatState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // SessionManager から全キーを取得（History から読み込み）
  let keys = state.session_manager.list_keys() catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to list sessions",
      )
  }
  let sessions : Array[Json] = []
  for key in keys {
    if key.channel == "web_chat" {
      let session = state.session_manager.get(key) catch { _ => continue }
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
  // SessionManager.get() は History (JSONL) から読み込んで Session を構築
  let session = state.session_manager.get(key) catch {
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
  state.session_manager.delete(key) catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to delete session",
      )
  }
  @api.json_response(200, { "ok": true })
}

///|
/// POST /chat/resume - Resume from history session
/// session_id から元の chat_id を抽出し、そのまま返す
/// History が source of truth なので、新しい chat_id は生成しない
fn handle_resume_session(
  state : ChatState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // Parse body for session_id
  let obj = match @api.require_json_object(ctx.body) {
    Ok(o) => o
    Err(resp) => return resp
  }
  let session_id = match @api.require_string_field(obj, "session_id") {
    Ok(s) => s
    Err(resp) => return resp
  }
  // session_id から channel と chat_id を抽出
  // session_id の形式: "channel:chat_id" (例: "web_chat:abc-123")
  let (channel, chat_id) = @history.split_session_id(session_id)
  if channel.length() == 0 || chat_id.length() == 0 {
    return @api.error_response(
      400,
      "bad_request",
      "Invalid session_id format: \{session_id}",
    )
  }
  // SessionManager.get() で History から Session を読み込み
  let key = @types.SessionKey::new(channel~, chat_id~, user_id=None)
  let session = state.session_manager.get(key) catch {
    _ =>
      return @api.error_response(
        500, "internal_error", "Failed to read session from history",
      )
  }
  match session {
    Some(_) =>
      // セッションが存在 - 元の chat_id をそのまま返す
      @api.json_response(200, { "data": { "chat_id": chat_id.to_json() } })
    None =>
      @api.error_response(404, "not_found", "Session not found: \{session_id}")
  }
}

///|
/// Convert ModelMessage to JSON for API response
fn model_message_to_json(msg : @llm_types.ModelMessage) -> Json {
  match msg {
    @llm_types.ModelMessage::System(text) =>
      { "role": "system", "content": text.to_json() }
    @llm_types.ModelMessage::User(content~, name~) =>
      match name {
        Some(n) =>
          { "role": "user", "content": content.to_json(), "name": n.to_json() }
        None => { "role": "user", "content": content.to_json() }
      }
    @llm_types.ModelMessage::Assistant(content~, ..) =>
      { "role": "assistant", "content": content.to_json() }
    @llm_types.ModelMessage::ToolResult(tool_call_id~, content~) =>
      {
        "role": "tool",
        "tool_call_id": tool_call_id.to_json(),
        "content": content.to_json(),
      }
  }
}
