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
test "ModelOptions::default has empty model_name" {
  let opts = ModelOptions::default()
  inspect(opts.model_name, content="")
  inspect(opts.temperature, content="None")
  inspect(opts.max_tokens, content="None")
}

///|
test "AgentConfig::default has reasonable values" {
  let config = AgentConfig::default()
  inspect(config.max_iterations, content="10")
  inspect(config.timeout_ms, content="120000")
}
