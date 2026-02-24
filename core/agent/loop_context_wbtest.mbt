///|
test "extract_context_overrides reads metadata payload" {
  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-1",
    sender_id: "user-1",
    sender_name: "User",
    content: "hello",
    message_type: @types.MessageType::Text,
    metadata: {
      "bootstrap": Json::string("You are test assistant"),
      "memory_context": Json::array([
        Json::string("user likes tea"),
        Json::number(100),
      ]),
      "skills": Json::array([
        {
          "name": "web_search",
          "description": "search web",
          "instructions": "use for latest info",
        },
      ]),
    },
    timestamp: 1000L,
  }
  let overrides = extract_context_overrides(envelope)
  inspect(overrides.bootstrap, content="You are test assistant")
  inspect(overrides.memory_context.length(), content="1")
  inspect(overrides.memory_context[0], content="user likes tea")
  inspect(overrides.skills.length(), content="1")
  inspect(overrides.skills[0].name, content="web_search")
}

///|
test "extract_context_overrides ignores invalid metadata payload" {
  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-2",
    sender_id: "user-2",
    sender_name: "User2",
    content: "world",
    message_type: @types.MessageType::Text,
    metadata: {
      "bootstrap": Json::number(1),
      "memory_context": Json::array([Json::number(1), Json::boolean(true)]),
      "skills": Json::array([
        { "name": "only-name" },
        { "description": "only-description" },
      ]),
    },
    timestamp: 2000L,
  }
  let overrides = extract_context_overrides(envelope)
  inspect(overrides.bootstrap, content="")
  inspect(overrides.memory_context.length(), content="0")
  inspect(overrides.skills.length(), content="0")
}
