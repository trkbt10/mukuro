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
test "ConfigurableSessionResolver resolves PerRoutingScope with guild metadata" {
  let resolver = ConfigurableSessionResolver::new(
    strategy=SessionStrategy::PerRoutingScope,
  )
  let envelope = @types.InboundEnvelope::{
    channel: "discord",
    chat_id: "chat-default",
    sender_id: "user3",
    sender_name: "User Three",
    content: "Hello",
    message_type: @types.MessageType::Text,
    metadata: { "guild_id": Json::string("g-123") },
    timestamp: 3000L,
  }
  let key = @interfaces.SessionResolver::resolve(resolver, envelope)
  inspect(key.channel, content="discord")
  inspect(key.chat_id, content="guild-g-123")
  inspect(key.user_id, content="None")
}

///|
test "ConfigurableSessionResolver resolves PerRoutingScope fallback to chat_id" {
  let resolver = ConfigurableSessionResolver::new(
    strategy=SessionStrategy::PerRoutingScope,
  )
  let envelope = @types.InboundEnvelope::{
    channel: "slack",
    chat_id: "C12345",
    sender_id: "user4",
    sender_name: "User Four",
    content: "Hello",
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 4000L,
  }
  let key = @interfaces.SessionResolver::resolve(resolver, envelope)
  inspect(key.channel, content="slack")
  inspect(key.chat_id, content="C12345")
  inspect(key.user_id, content="None")
}

///|
test "ConfigurableSessionResolver resolves PerAgentBinding with agent_id metadata" {
  let resolver = ConfigurableSessionResolver::new(
    strategy=SessionStrategy::PerAgentBinding,
  )
  let envelope = @types.InboundEnvelope::{
    channel: "discord",
    chat_id: "chat-default",
    sender_id: "user-ab",
    sender_name: "User AB",
    content: "hello",
    message_type: @types.MessageType::Text,
    metadata: {
      "agent_id": Json::string("support"),
      "guild_id": Json::string("g-999"),
    },
    timestamp: 5000L,
  }
  let key = @interfaces.SessionResolver::resolve(resolver, envelope)
  inspect(key.channel, content="discord")
  inspect(key.chat_id, content="agent-support")
  inspect(key.user_id, content="None")
}

///|
test "ConfigurableSessionResolver PerAgentBinding fallback to routing scope" {
  let resolver = ConfigurableSessionResolver::new(
    strategy=SessionStrategy::PerAgentBinding,
  )
  let envelope = @types.InboundEnvelope::{
    channel: "slack",
    chat_id: "chat-default",
    sender_id: "user-cd",
    sender_name: "User CD",
    content: "hello",
    message_type: @types.MessageType::Text,
    metadata: { "team_id": Json::string("team-1") },
    timestamp: 6000L,
  }
  let key = @interfaces.SessionResolver::resolve(resolver, envelope)
  inspect(key.channel, content="slack")
  inspect(key.chat_id, content="team-team-1")
  inspect(key.user_id, content="None")
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
