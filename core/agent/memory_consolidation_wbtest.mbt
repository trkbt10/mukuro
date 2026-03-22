///|
test "summarize_messages_simple counts messages" {
  let messages : Array[@llm_types.ModelMessage] = [
    @llm_types.ModelMessage::User(content="Hello", name=None),
    @llm_types.ModelMessage::Assistant(content="Hi there", tool_calls=None),
    @llm_types.ModelMessage::User(content="How are you?", name=None),
    @llm_types.ModelMessage::Assistant(content="I'm fine", tool_calls=None),
  ]
  let summary = summarize_messages_simple(messages)
  assert_true(summary.contains("2 user messages"))
  assert_true(summary.contains("2 assistant responses"))
}

///|
test "summarize_messages_simple includes last topic" {
  let messages : Array[@llm_types.ModelMessage] = [
    @llm_types.ModelMessage::User(content="Tell me about MoonBit", name=None),
    @llm_types.ModelMessage::Assistant(
      content="MoonBit is a language",
      tool_calls=None,
    ),
  ]
  let summary = summarize_messages_simple(messages)
  assert_true(summary.contains("Tell me about MoonBit"))
}

///|
test "maybe_consolidate returns None for short sessions" {
  let messages : Array[@llm_types.ModelMessage] = [
    @llm_types.ModelMessage::User(content="Hi", name=None),
    @llm_types.ModelMessage::Assistant(content="Hello", tool_calls=None),
  ]
  inspect(maybe_consolidate(messages) is None, content="true")
}

///|
test "summarize_messages_simple counts tool results" {
  let messages : Array[@llm_types.ModelMessage] = [
    @llm_types.ModelMessage::User(content="Do something", name=None),
    @llm_types.ModelMessage::Assistant(
      content="",
      tool_calls=Some([
        @llm_types.ToolCallRequest::new(id="1", name="shell", arguments={}),
      ]),
    ),
    @llm_types.ModelMessage::ToolResult(tool_call_id="1", content="done"),
    @llm_types.ModelMessage::Assistant(content="Done!", tool_calls=None),
  ]
  let summary = summarize_messages_simple(messages)
  assert_true(summary.contains("1 tool calls"))
}

///|
test "summarize_messages_simple truncates long content" {
  let long_msg = "a".repeat(200)
  let messages : Array[@llm_types.ModelMessage] = [
    @llm_types.ModelMessage::User(content=long_msg, name=None),
    @llm_types.ModelMessage::Assistant(content="ok", tool_calls=None),
  ]
  let summary = summarize_messages_simple(messages)
  assert_true(summary.contains("..."))
}

///|
test "maybe_consolidate returns None for empty" {
  let messages : Array[@llm_types.ModelMessage] = []
  inspect(maybe_consolidate(messages) is None, content="true")
}

///|
test "maybe_consolidate returns Some for long sessions" {
  let messages : Array[@llm_types.ModelMessage] = [
    @llm_types.ModelMessage::User(content="Q1", name=None),
    @llm_types.ModelMessage::Assistant(content="A1", tool_calls=None),
    @llm_types.ModelMessage::User(content="Q2", name=None),
    @llm_types.ModelMessage::Assistant(content="A2", tool_calls=None),
    @llm_types.ModelMessage::User(content="Q3", name=None),
    @llm_types.ModelMessage::Assistant(content="A3", tool_calls=None),
  ]
  match maybe_consolidate(messages) {
    Some(summary) => assert_true(summary.contains("3 user messages"))
    None => fail("Expected Some")
  }
}
