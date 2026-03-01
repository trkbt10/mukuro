///|
/// WebSocket Chat Handler Tests

// =============================================================================
// parse_chat_ws_message Tests
// =============================================================================

test "parse_chat_ws_message: send with content" {
  let input =
    #|{"type":"send","content":"Hello world"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Send)
  assert_eq(content, Some("Hello world"))
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: send with content and sender_name" {
  let input =
    #|{"type":"send","content":"Hi","sender_name":"Alice"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Send)
  assert_eq(content, Some("Hi"))
  assert_eq(sender_name, Some("Alice"))
}

test "parse_chat_ws_message: load_history" {
  let input =
    #|{"type":"load_history"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::LoadHistory)
  assert_eq(content, None)
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: ping" {
  let input =
    #|{"type":"ping"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Ping)
  assert_eq(content, None)
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: unknown type" {
  let input =
    #|{"type":"unknown_action"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Unknown)
  assert_eq(content, None)
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: missing type" {
  let input =
    #|{"content":"no type field"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Unknown)
  assert_eq(content, Some("no type field"))
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: invalid json" {
  let (msg_type, content, sender_name) = parse_chat_ws_message("not valid json")
  assert_eq(msg_type, ChatWsMessageType::Unknown)
  assert_eq(content, None)
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: empty string" {
  let (msg_type, content, sender_name) = parse_chat_ws_message("")
  assert_eq(msg_type, ChatWsMessageType::Unknown)
  assert_eq(content, None)
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: json array instead of object" {
  let (msg_type, content, sender_name) = parse_chat_ws_message("[1,2,3]")
  assert_eq(msg_type, ChatWsMessageType::Unknown)
  assert_eq(content, None)
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: json number instead of object" {
  let (msg_type, content, sender_name) = parse_chat_ws_message("42")
  assert_eq(msg_type, ChatWsMessageType::Unknown)
  assert_eq(content, None)
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: content is number not string" {
  let input =
    #|{"type":"send","content":123}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Send)
  assert_eq(content, None) // content must be string
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: type is number not string" {
  let input =
    #|{"type":1,"content":"test"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Unknown)
  assert_eq(content, Some("test"))
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: unicode content" {
  let input =
    #|{"type":"send","content":"こんにちは世界"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Send)
  assert_eq(content, Some("こんにちは世界"))
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: emoji content" {
  let input =
    #|{"type":"send","content":"Hello 👋 World 🌍"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Send)
  assert_eq(content, Some("Hello 👋 World 🌍"))
  assert_eq(sender_name, None)
}

test "parse_chat_ws_message: escaped characters" {
  let input =
    #|{"type":"send","content":"Line1\nLine2\tTabbed"}
  let (msg_type, content, sender_name) = parse_chat_ws_message(input)
  assert_eq(msg_type, ChatWsMessageType::Send)
  assert_eq(content, Some("Line1\nLine2\tTabbed"))
  assert_eq(sender_name, None)
}

// =============================================================================
// ChatWsMessageType Equality Tests
// =============================================================================

test "ChatWsMessageType: equality" {
  assert_eq(ChatWsMessageType::Send, ChatWsMessageType::Send)
  assert_eq(ChatWsMessageType::LoadHistory, ChatWsMessageType::LoadHistory)
  assert_eq(ChatWsMessageType::Ping, ChatWsMessageType::Ping)
  assert_eq(ChatWsMessageType::Unknown, ChatWsMessageType::Unknown)
  assert_not_eq(ChatWsMessageType::Send, ChatWsMessageType::Ping)
  assert_not_eq(ChatWsMessageType::LoadHistory, ChatWsMessageType::Unknown)
}

// =============================================================================
// ChatWsHandler Creation Tests (with mock dependencies)
// =============================================================================

///|
/// Mock session store for testing
struct MockSessionStore {
  saved_sessions : Array[@types.Session]
  get_result : @types.Session?
}

///|
fn MockSessionStore::new() -> MockSessionStore {
  { saved_sessions: [], get_result: None }
}

///|
impl @interfaces.SessionStore for MockSessionStore with save(self, session) {
  self.saved_sessions.push(session)
}

///|
impl @interfaces.SessionStore for MockSessionStore with get(self, _key) {
  self.get_result
}

///|
impl @interfaces.SessionStore for MockSessionStore with delete(_self, _key) {
  ()
}

///|
impl @interfaces.SessionStore for MockSessionStore with list_keys(_self) {
  []
}

test "ChatWsHandler::new: generates chat_id from dependency" {
  let store = MockSessionStore::new()
  let deps : ChatWsDeps = {
    session_store: store,
    agent_handler: fn(_env) {
      @types.OutboundMessage::{
        channel: "web_chat",
        chat_id: "test",
        content: "response",
        reply_to: None,
        attachments: None,
        options: None,
      }
    },
    generate_chat_id: fn() { "test-chat-id-123" },
    get_timestamp: fn() { 1000L },
  }
  let handler = ChatWsHandler::new(deps)
  assert_eq(handler.chat_id, "test-chat-id-123")
}

// =============================================================================
// JSON Output Format Tests (test the expected message formats)
// =============================================================================

test "session message format" {
  let json : Json = { "type": "session", "chat_id": Json::string("abc-123") }
  let text = json.stringify()
  assert_true(text.contains("\"type\":\"session\""))
  assert_true(text.contains("\"chat_id\":\"abc-123\""))
}

test "status message format" {
  let json : Json = { "type": "status", "status": Json::string("thinking") }
  let text = json.stringify()
  assert_true(text.contains("\"type\":\"status\""))
  assert_true(text.contains("\"status\":\"thinking\""))
}

test "message response format" {
  let json : Json = {
    "type": "message",
    "role": Json::string("assistant"),
    "content": Json::string("Hello!"),
    "timestamp": Json::number(1234567890.0),
  }
  let text = json.stringify()
  assert_true(text.contains("\"type\":\"message\""))
  assert_true(text.contains("\"role\":\"assistant\""))
  assert_true(text.contains("\"content\":\"Hello!\""))
  assert_true(text.contains("\"timestamp\":"))
}

test "history response format" {
  let messages : Array[Json] = [
    { "role": "user", "content": Json::string("Hi") },
    { "role": "assistant", "content": Json::string("Hello") },
  ]
  let json : Json = { "type": "history", "messages": Json::array(messages) }
  let text = json.stringify()
  assert_true(text.contains("\"type\":\"history\""))
  assert_true(text.contains("\"messages\":"))
}

test "pong message format" {
  let json : Json = { "type": "pong" }
  let text = json.stringify()
  assert_true(text.contains("\"type\":\"pong\""))
}

test "error message format without code" {
  let obj : Map[String, Json] = {
    "type": Json::string("error"),
    "error": Json::string("Something went wrong"),
  }
  let json = Json::object(obj)
  let text = json.stringify()
  assert_true(text.contains("\"type\":\"error\""))
  assert_true(text.contains("\"error\":\"Something went wrong\""))
  assert_false(text.contains("\"code\":"))
}

test "error message format with code" {
  let obj : Map[String, Json] = {
    "type": Json::string("error"),
    "error": Json::string("Auth failed"),
  }
  obj["code"] = Json::string("AUTH_ERROR")
  let json = Json::object(obj)
  let text = json.stringify()
  assert_true(text.contains("\"type\":\"error\""))
  assert_true(text.contains("\"error\":\"Auth failed\""))
  assert_true(text.contains("\"code\":\"AUTH_ERROR\""))
}
