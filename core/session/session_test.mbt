///|
test "ConfigurableSessionResolver resolves per-chat key" {
  let resolver = ConfigurableSessionResolver::default()
  let envelope = @types.InboundEnvelope::{
    channel: "discord",
    chat_id: "123",
    sender_id: "user1",
    sender_name: "User One",
    content: "Hello",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 1000L,
  }
  let key = @interfaces.SessionResolver::resolve(resolver, envelope)
  inspect(key.channel, content="discord")
  inspect(key.chat_id, content="123")
  inspect(key.user_id, content="None")
}

///|
test "ConfigurableSessionResolver resolves per-user key" {
  let resolver = ConfigurableSessionResolver::new(
    strategy=SessionStrategy::PerUser,
  )
  let envelope = @types.InboundEnvelope::{
    channel: "telegram",
    chat_id: "456",
    sender_id: "user2",
    sender_name: "User Two",
    content: "Hi",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 2000L,
  }
  let key = @interfaces.SessionResolver::resolve(resolver, envelope)
  inspect(key.channel, content="telegram")
  inspect(key.chat_id, content="456")
  inspect(key.user_id, content="Some(\"user2\")")
}

///|
test "session_key_to_storage_key formats correctly" {
  let key = @types.SessionKey::new(channel="http", chat_id="test", user_id=None)
  let storage_key = session_key_to_storage_key(key)
  inspect(storage_key, content="session:http:test")
}

///|
test "parse_session_key parses correctly" {
  let key = parse_session_key("session:discord:123")
  match key {
    Some(k) => {
      inspect(k.channel, content="discord")
      inspect(k.chat_id, content="123")
    }
    None => fail("Expected Some")
  }
}

///|
test "parse_session_key returns None for invalid key" {
  let key = parse_session_key("invalid:key")
  inspect(key, content="None")
}

///|
test "HistoryManager truncates old messages" {
  let manager = HistoryManager::new(options=HistoryOptions::{
    max_messages: 3,
    max_tokens: 100000,
    truncate_old: true,
  })
  let key = @types.SessionKey::new(channel="http", chat_id="test", user_id=None)
  let mut session = @types.Session::new(key, 1000L)
  // 4つのメッセージを追加
  for i in 0..<4 {
    session = manager.add_message(
      session,
      @types.ModelMessage::User(content="Message \{i}", name=None),
    )
  }
  // 最大3件なので1件切り捨てられる
  inspect(session.history.length(), content="3")
}

///|
test "get_recent_messages returns last N messages" {
  let key = @types.SessionKey::new(channel="http", chat_id="test", user_id=None)
  let session = @types.Session::new(key, 1000L)
  for i in 0..<5 {
    session.history.push(
      @types.ModelMessage::User(content="Message \{i}", name=None),
    )
  }
  let recent = get_recent_messages(session, 2)
  inspect(recent.length(), content="2")
}
