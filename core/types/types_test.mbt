///|
test "InboundEnvelope::default creates empty envelope" {
  let envelope = InboundEnvelope::default()
  inspect(envelope.channel, content="")
  inspect(envelope.chat_id, content="")
  inspect(envelope.content, content="")
  inspect(envelope.timestamp, content="0")
}

///|
test "OutboundMessage::default creates empty message" {
  let msg = OutboundMessage::default()
  inspect(msg.channel, content="")
  inspect(msg.content, content="")
  inspect(msg.reply_to, content="None")
}

///|
test "SessionKey::new creates key correctly" {
  let key = SessionKey::new(channel="discord", chat_id="123", user_id=None)
  inspect(key.channel, content="discord")
  inspect(key.chat_id, content="123")
  inspect(key.user_id, content="None")
}

///|
test "SessionKey::to_string formats correctly" {
  let key1 = SessionKey::new(channel="discord", chat_id="123", user_id=None)
  inspect(key1.to_string(), content="discord:123")
  let key2 = SessionKey::new(
    channel="telegram",
    chat_id="456",
    user_id=Some("user1"),
  )
  inspect(key2.to_string(), content="telegram:456:user1")
}

///|
test "Session::new creates active session" {
  let key = SessionKey::new(channel="http", chat_id="test", user_id=None)
  let session = Session::new(key, 1000L)
  inspect(session.state, content="Active")
  inspect(session.created_at, content="1000")
  inspect(session.history.length(), content="0")
}

///|
test "Session::add_message adds to history" {
  let key = SessionKey::new(channel="http", chat_id="test", user_id=None)
  let session = Session::new(key, 1000L)
  session.add_message(ModelMessage::User(content="Hello", name=None))
  inspect(session.history.length(), content="1")
}

///|
test "ToolCallRequest::new creates request" {
  let req = ToolCallRequest::new(id="call_1", name="read_file", arguments={
    "path": "/tmp/test.txt",
  })
  inspect(req.id, content="call_1")
  inspect(req.name, content="read_file")
}

///|
test "ToolDefinition::new creates definition" {
  let def = ToolDefinition::new(name="search", description="Search the web", parameters={
    "type": "object",
  })
  inspect(def.name, content="search")
  inspect(def.description, content="Search the web")
}

///|
test "ModelOptions::default has reasonable values" {
  let opts = ModelOptions::default()
  inspect(opts.model_name, content="claude-sonnet-4-20250514")
  inspect(opts.max_tokens, content="Some(4096)")
}

///|
test "AgentConfig::default has reasonable values" {
  let config = AgentConfig::default()
  inspect(config.max_iterations, content="10")
  inspect(config.timeout_ms, content="120000")
}

///|
test "build_json_schema creates valid schema" {
  let schema = build_json_schema(
    type_="object",
    properties={ "name": { "type": "string" } },
    required=["name"],
  )
  // スキーマが正しく構築されていることを確認
  match schema {
    { "type": "object", .. } => ()
    _ => fail("Expected object type")
  }
}
