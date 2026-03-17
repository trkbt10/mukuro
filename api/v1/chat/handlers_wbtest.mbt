///|
/// Resume Session Tests
/// Source of truth: History (JSONL) からセッションを復元し、
/// 元の chat_id を保持することを検証

// ============================================================
// テスト用 MockSessionManager
// tmp ディレクトリを使わず、メモリ内で動作するモック実装
// ============================================================

///|
struct MockSessionManager {
  sessions : Map[@types.SessionKey, @types.Session]
}

///|
fn MockSessionManager::new() -> MockSessionManager {
  { sessions: {} }
}

///|
/// テスト用にセッションを事前登録
fn MockSessionManager::add_session(
  self : MockSessionManager,
  key : @types.SessionKey,
  session : @types.Session,
) -> Unit {
  self.sessions[key] = session
}

///|
impl @interfaces.SessionManager for MockSessionManager with get(self, key) {
  match self.sessions.get(key) {
    Some(s) => Some(s)
    None => None
  }
}

///|
impl @interfaces.SessionManager for MockSessionManager with get_or_create(
  self,
  key,
  now~,
) {
  match self.sessions.get(key) {
    Some(s) => s
    None => {
      let s = @types.Session::new(key, now)
      self.sessions[key] = s
      s
    }
  }
}

///|
impl @interfaces.SessionManager for MockSessionManager with append_user_message(
  self,
  key,
  content~,
  name~,
  timestamp~,
) {
  match self.sessions.get(key) {
    Some(s) => {
      s.add_message(@llm_types.ModelMessage::User(content~, name~))
      // Use touch() to update timestamp (returns new Session, but we keep reference)
      ignore(s.touch(timestamp))
    }
    None => ()
  }
}

///|
impl @interfaces.SessionManager for MockSessionManager with append_assistant_message(
  self,
  key,
  content~,
  tool_calls~,
  timestamp~,
) {
  match self.sessions.get(key) {
    Some(s) => {
      s.add_message(@llm_types.ModelMessage::Assistant(content~, tool_calls~))
      ignore(s.touch(timestamp))
    }
    None => ()
  }
}

///|
impl @interfaces.SessionManager for MockSessionManager with record_tool_call(
  _self,
  _key,
  call_id~,
  tool_name~,
  arguments~,
  timestamp~,
) {
  ignore(call_id)
  ignore(tool_name)
  ignore(arguments)
  ignore(timestamp)
}

///|
impl @interfaces.SessionManager for MockSessionManager with record_tool_result(
  self,
  key,
  call_id~,
  content~,
  timestamp~,
) {
  match self.sessions.get(key) {
    Some(s) => {
      s.add_message(
        @llm_types.ModelMessage::ToolResult(tool_call_id=call_id, content~),
      )
      ignore(s.touch(timestamp))
    }
    None => ()
  }
}

///|
impl @interfaces.SessionManager for MockSessionManager with record_error(
  _self,
  _key,
  message~,
  timestamp~,
) {
  ignore(message)
  ignore(timestamp)
}

///|
impl @interfaces.SessionManager for MockSessionManager with delete(self, key) {
  self.sessions.remove(key)
}

///|
impl @interfaces.SessionManager for MockSessionManager with list_keys(self) {
  self.sessions.keys().collect()
}

///|
impl @interfaces.SessionManager for MockSessionManager with close_session(
  _self,
  _key,
) {
  // No-op for mock
}

// ============================================================
// Resume Session テスト
// ============================================================

///|
/// 根本原因1: resume は元の chat_id を返すこと (resumed_ prefix を生成しない)
test "handle_resume_session: returns original chat_id without resumed_ prefix" {
  // 1. 元の session を作成 (chat_id = "original-abc-123")
  let mock_mgr = MockSessionManager::new()
  let original_chat_id = "original-abc-123"
  let original_key = @types.SessionKey::new(
    channel="web_chat",
    chat_id=original_chat_id,
    user_id=None,
  )
  let original_session = @types.Session::new(original_key, 1000L)
  original_session.add_message(
    @llm_types.ModelMessage::User(content="Hello", name=None),
  )
  original_session.add_message(
    @llm_types.ModelMessage::Assistant(content="Hi!", tool_calls=None),
  )
  mock_mgr.add_session(original_key, original_session)

  // 2. ChatState を作成
  let state = ChatState::new_with_session_manager(mock_mgr)

  // 3. resume API を呼び出し (session_id = "web_chat:original-abc-123")
  let ctx : @api.ApiRequestContext = {
    http_method: "POST",
    path: "/chat/resume",
    segments: ["chat", "resume"],
    body: "{\"session_id\":\"web_chat:original-abc-123\"}",
    headers: {},
    query: {},
    role: @api.ApiRole::Admin,
    client_id: "",
  }
  let response = handle_resume_session(state, ctx)

  // 4. レスポンスを検証 - chat_id が "original-abc-123" であること
  let body_json : Json = @json.parse(response.body) catch {
    _ => fail("Failed to parse response body as JSON")
  }
  match body_json {
    { "data": { "chat_id": Json::String(returned_chat_id), .. }, .. } => {
      // 重要: resumed_ prefix がないこと
      assert_false(
        returned_chat_id.has_prefix("resumed_"),
        msg="chat_id should NOT have 'resumed_' prefix",
      )
      // 元の chat_id と一致すること
      assert_eq(
        returned_chat_id,
        original_chat_id,
        msg="chat_id should match original",
      )
    }
    _ => fail("Expected {data:{chat_id:...}} in response body")
  }
}

///|
/// 根本原因2: 存在しないセッションの resume は 404 を返すこと
test "handle_resume_session: returns 404 for non-existent session" {
  let mock_mgr = MockSessionManager::new()
  let state = ChatState::new_with_session_manager(mock_mgr)

  let ctx : @api.ApiRequestContext = {
    http_method: "POST",
    path: "/chat/resume",
    segments: ["chat", "resume"],
    body: "{\"session_id\":\"web_chat:non-existent-session\"}",
    headers: {},
    query: {},
    role: @api.ApiRole::Admin,
    client_id: "",
  }
  let response = handle_resume_session(state, ctx)

  assert_eq(
    response.status,
    404,
    msg="Should return 404 for non-existent session",
  )
}

///|
/// 根本原因3: resume 後にメッセージを追加すると元のセッションに追加されること
test "resume preserves session identity for subsequent messages" {
  // 1. 元のセッションを作成
  let mock_mgr = MockSessionManager::new()
  let original_chat_id = "chat-identity-test"
  let original_key = @types.SessionKey::new(
    channel="web_chat",
    chat_id=original_chat_id,
    user_id=None,
  )
  let original_session = @types.Session::new(original_key, 1000L)
  original_session.add_message(
    @llm_types.ModelMessage::User(content="Original message", name=None),
  )
  mock_mgr.add_session(original_key, original_session)

  // 2. Resume 後、同じセッションに新しいメッセージを追加
  mock_mgr.append_user_message(
    original_key,
    content="New message after resume",
    name=None,
    timestamp=2000L,
  )

  // 3. セッションを取得して検証
  let session = mock_mgr.get(original_key) catch { _ => None }
  match session {
    Some(s) => {
      // メッセージが2つあること
      assert_eq(s.history.length(), 2, msg="Should have 2 messages")
      // 2番目のメッセージが新しいものであること
      match s.history[1] {
        @llm_types.ModelMessage::User(content~, ..) =>
          assert_eq(
            content,
            "New message after resume",
            msg="New message should be added to same session",
          )
        _ => fail("Expected User message")
      }
    }
    None => fail("Session should exist after resume and append")
  }
}

///|
/// コロンがない session_id の場合は channel="default" として扱われ、
/// セッションが存在しないため 404 を返す
/// (split_session_id は "default" と元の文字列を返す)
test "handle_resume_session: returns 404 for session_id without colon" {
  let mock_mgr = MockSessionManager::new()
  let state = ChatState::new_with_session_manager(mock_mgr)

  // コロンがない session_id → channel="default", chat_id="invalid-no-colon"
  let ctx : @api.ApiRequestContext = {
    http_method: "POST",
    path: "/chat/resume",
    segments: ["chat", "resume"],
    body: "{\"session_id\":\"invalid-no-colon\"}",
    headers: {},
    query: {},
    role: @api.ApiRole::Admin,
    client_id: "",
  }
  let response = handle_resume_session(state, ctx)

  // split_session_id は ("default", "invalid-no-colon") を返す
  // セッションが存在しないので 404
  assert_eq(
    response.status,
    404,
    msg="Should return 404 for non-existent session",
  )
}

///|
/// 回帰テスト: resumed_ prefix が付いた既存セッションを resume しても
/// さらに新しい resumed_ を生成しないこと
test "handle_resume_session: does not double-prefix resumed_ sessions" {
  let mock_mgr = MockSessionManager::new()
  // 既存の resumed_ セッション (過去のバグで作られたもの)
  let existing_chat_id = "resumed_1772367949000"
  let existing_key = @types.SessionKey::new(
    channel="web_chat",
    chat_id=existing_chat_id,
    user_id=None,
  )
  let existing_session = @types.Session::new(existing_key, 1772367949000L)
  mock_mgr.add_session(existing_key, existing_session)

  let state = ChatState::new_with_session_manager(mock_mgr)

  let ctx : @api.ApiRequestContext = {
    http_method: "POST",
    path: "/chat/resume",
    segments: ["chat", "resume"],
    body: "{\"session_id\":\"web_chat:resumed_1772367949000\"}",
    headers: {},
    query: {},
    role: @api.ApiRole::Admin,
    client_id: "",
  }
  let response = handle_resume_session(state, ctx)

  let body_json : Json = @json.parse(response.body) catch {
    _ => fail("Failed to parse response body as JSON")
  }
  match body_json {
    { "data": { "chat_id": Json::String(returned_chat_id), .. }, .. } => {
      // resumed_resumed_ のような二重 prefix がないこと
      assert_false(
        returned_chat_id.has_prefix("resumed_resumed_"),
        msg="Should not have double resumed_ prefix",
      )
      // 元の chat_id (resumed_xxx) がそのまま返されること
      assert_eq(
        returned_chat_id,
        existing_chat_id,
        msg="Should return the existing chat_id as-is",
      )
    }
    _ => fail("Expected {data:{chat_id:...}} in response body")
  }
}

// ============================================================
// split_session_id テスト
// ============================================================

///|
test "split_session_id: correctly extracts channel and chat_id" {
  let (channel, chat_id) = @history.split_session_id("web_chat:abc-123")
  assert_eq(channel, "web_chat")
  assert_eq(chat_id, "abc-123")
}

///|
test "split_session_id: handles chat_id with colons" {
  let (channel, chat_id) = @history.split_session_id("web_chat:abc:def:123")
  assert_eq(channel, "web_chat")
  assert_eq(chat_id, "abc:def:123")
}

///|
/// コロンがない場合は channel="default"、chat_id=元の文字列 を返す
test "split_session_id: returns default for format without colon" {
  let (channel, chat_id) = @history.split_session_id("no-colon-here")
  assert_eq(channel, "default")
  assert_eq(chat_id, "no-colon-here")
}
