///|
/// Interoperability Tests
/// Chat Completions (Harmony) <-> Responses API conversion

// =============================================================================
// Responses API Input → Chat Completions Messages
// =============================================================================

///|
test "responses_input_to_messages: basic user message" {
  let input : Array[Json] = [
    { "role": "system", "content": "You are helpful." },
    { "role": "user", "content": "Hello" },
  ]
  let messages = responses_input_to_messages(input)
  inspect(messages.length(), content="2")
  match messages[0] {
    @types.ModelMessage::System(content) =>
      inspect(content, content="You are helpful.")
    _ => fail("Expected System message")
  }
  match messages[1] {
    @types.ModelMessage::User(content~, ..) => inspect(content, content="Hello")
    _ => fail("Expected User message")
  }
}

///|
test "responses_input_to_messages: function_call and output" {
  let input : Array[Json] = [
    { "role": "user", "content": "What time is it?" },
    {
      "type": "function_call",
      "call_id": "fc_123",
      "name": "datetime",
      "arguments": "{}",
      "status": "completed",
    },
    {
      "type": "function_call_output",
      "call_id": "fc_123",
      "output": "{\"time\":\"15:00\"}",
    },
  ]
  let messages = responses_input_to_messages(input)
  inspect(messages.length(), content="3")
  // User message
  match messages[0] {
    @types.ModelMessage::User(content~, ..) =>
      inspect(content, content="What time is it?")
    _ => fail("Expected User message")
  }
  // Assistant with tool call
  match messages[1] {
    @types.ModelMessage::Assistant(tool_calls=Some(calls), ..) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].id, content="fc_123")
      inspect(calls[0].name, content="datetime")
    }
    _ => fail("Expected Assistant message with tool_calls")
  }
  // Tool result
  match messages[2] {
    @types.ModelMessage::ToolResult(tool_call_id~, content~) => {
      inspect(tool_call_id, content="fc_123")
      inspect(content, content="{\"time\":\"15:00\"}")
    }
    _ => fail("Expected ToolResult message")
  }
}

///|
test "responses_input_to_messages: multi-turn with tool call" {
  // Simulates: User -> Assistant(tool_call) -> ToolResult -> User(follow-up)
  let input : Array[Json] = [
    { "role": "system", "content": "You are helpful." },
    { "role": "user", "content": "List files" },
    {
      "type": "function_call",
      "call_id": "fc_abc",
      "name": "shell",
      "arguments": "{\"command\":\"ls\"}",
    },
    {
      "type": "function_call_output",
      "call_id": "fc_abc",
      "output": "file1.txt\nfile2.txt",
    },
    { "role": "user", "content": "Now show details" },
  ]
  let messages = responses_input_to_messages(input)
  inspect(messages.length(), content="5")
  // System
  match messages[0] {
    @types.ModelMessage::System(_) => ()
    _ => fail("Expected System")
  }
  // User 1
  match messages[1] {
    @types.ModelMessage::User(content~, ..) =>
      inspect(content, content="List files")
    _ => fail("Expected User")
  }
  // Assistant with tool call
  match messages[2] {
    @types.ModelMessage::Assistant(tool_calls=Some(calls), ..) =>
      inspect(calls[0].name, content="shell")
    _ => fail("Expected Assistant with tool_calls")
  }
  // Tool result
  match messages[3] {
    @types.ModelMessage::ToolResult(tool_call_id~, ..) =>
      inspect(tool_call_id, content="fc_abc")
    _ => fail("Expected ToolResult")
  }
  // User 2
  match messages[4] {
    @types.ModelMessage::User(content~, ..) =>
      inspect(content, content="Now show details")
    _ => fail("Expected User")
  }
}

// =============================================================================
// ModelResponse → Responses API JSON
// =============================================================================

///|
test "model_response_to_responses_json: text response" {
  let response = @types.ModelResponse::Text("Hello, world!")
  let json = model_response_to_responses_json(response, response_id="resp_001")
  match json {
    { "id": String(id), "output": Array(output), .. } => {
      inspect(id, content="resp_001")
      inspect(output.length(), content="1")
      match output[0] {
        {
          "type": String("message"),
          "content": Array(content_arr),
          ..
        } => {
          match content_arr[0] {
            { "type": String("output_text"), "text": String(t), .. } =>
              inspect(t, content="Hello, world!")
            _ => fail("Expected output_text")
          }
        }
        _ => fail("Expected message output")
      }
    }
    _ => fail("Expected valid response JSON")
  }
}

///|
test "model_response_to_responses_json: tool calls" {
  let calls : Array[@types.ToolCallRequest] = [
    @types.ToolCallRequest::new(
      id="fc_001",
      name="datetime",
      arguments={ "tz": "UTC" },
    ),
  ]
  let response = @types.ModelResponse::ToolCalls(calls)
  let json = model_response_to_responses_json(response)
  match json {
    { "output": Array(output), .. } => {
      inspect(output.length(), content="1")
      match output[0] {
        {
          "type": String("function_call"),
          "name": String(name),
          "call_id": String(call_id),
          ..
        } => {
          inspect(name, content="datetime")
          inspect(call_id, content="fc_001")
        }
        _ => fail("Expected function_call output")
      }
    }
    _ => fail("Expected valid response JSON")
  }
}

// =============================================================================
// Harmony SSE → Responses API Events
// =============================================================================

///|
test "HarmonyToResponsesTranslator: text streaming" {
  let translator = HarmonyToResponsesTranslator::new(response_id="resp_test")
  // First chunk with role
  let event1 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        { "index": 0, "delta": { "role": "assistant", "content": "" } },
      ]),
    },
  }
  let events1 = translator.translate(event1)
  // Should emit response.created
  inspect(events1.length(), content="1")
  inspect(events1[0].0, content="response.created")
  // Content chunk
  let event2 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        { "index": 0, "delta": { "content": "Hello" } },
      ]),
    },
  }
  let events2 = translator.translate(event2)
  inspect(events2.length(), content="1")
  inspect(events2[0].0, content="response.output_text.delta")
  // Final chunk with stop
  let event3 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        { "index": 0, "delta": {}, "finish_reason": "stop" },
      ]),
    },
  }
  let events3 = translator.translate(event3)
  // Should emit output_text.done and completed
  inspect(events3.length(), content="2")
  inspect(events3[0].0, content="response.output_text.done")
  inspect(events3[1].0, content="response.completed")
}

///|
test "HarmonyToResponsesTranslator: tool call streaming" {
  let translator = HarmonyToResponsesTranslator::new()
  // First chunk
  let event1 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        { "index": 0, "delta": { "role": "assistant", "content": "" } },
      ]),
    },
  }
  ignore(translator.translate(event1))
  // Tool call chunk
  let event2 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        {
          "index": 0,
          "delta": {
            "tool_calls": Json::array([
              {
                "id": "fc_xyz",
                "type": "function",
                "function": { "name": "datetime", "arguments": "{}" },
              },
            ]),
          },
        },
      ]),
    },
  }
  let events2 = translator.translate(event2)
  // Should emit output_item.added and arguments.delta
  let mut found_added = false
  for e in events2 {
    if e.0 == "response.output_item.added" {
      found_added = true
    }
  }
  inspect(found_added, content="true")
  // Final chunk
  let event3 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        { "index": 0, "delta": {}, "finish_reason": "tool_calls" },
      ]),
    },
  }
  let events3 = translator.translate(event3)
  inspect(events3.length(), content="1")
  inspect(events3[0].0, content="response.completed")
}

// =============================================================================
// Responses API Request → Chat Completions Request
// =============================================================================

///|
test "responses_request_to_chat_completions: basic request" {
  let request : Json = {
    "model": "openai/gpt-oss-20b",
    "input": Json::array([
      { "role": "system", "content": "You are helpful." },
      { "role": "user", "content": "Hello" },
    ]),
  }
  let chat_request = responses_request_to_chat_completions(request)
  match chat_request {
    { "model": String(model), "messages": Array(msgs), "stream": True, .. } => {
      inspect(model, content="openai/gpt-oss-20b")
      inspect(msgs.length(), content="2")
    }
    _ => fail("Expected valid Chat Completions request")
  }
}

///|
test "responses_request_to_chat_completions: with tools" {
  let request : Json = {
    "model": "openai/gpt-oss-20b",
    "input": Json::array([{ "role": "user", "content": "What time?" }]),
    "tools": Json::array([
      {
        "type": "function",
        "function": {
          "name": "datetime",
          "description": "Get time",
          "parameters": {},
        },
      },
    ]),
    "tool_choice": "auto",
  }
  let chat_request = responses_request_to_chat_completions(request)
  match chat_request {
    { "tools": Array(tools), "tool_choice": String(choice), .. } => {
      inspect(tools.length(), content="1")
      inspect(choice, content="auto")
    }
    _ => fail("Expected tools in request")
  }
}

// =============================================================================
// Round-trip Tests: Real Harmony Fixtures
// =============================================================================

///|
test "round-trip: Harmony fixture Turn 1 → Responses API events" {
  // Parse actual Harmony fixture and convert to Responses API events
  let jsonl =
    #| {"id":"chatcmpl-430931d8","choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}
    #| {"id":"chatcmpl-430931d8","choices":[{"index":0,"delta":{"reasoning":"We need","channel":"analysis"},"finish_reason":null}]}
    #| {"id":"chatcmpl-430931d8","choices":[{"index":0,"delta":{"tool_calls":[{"id":"fc_4ebfd2ae","type":"function","function":{"name":"datetime","arguments":"{}"}}]},"finish_reason":null}]}
    #| {"id":"chatcmpl-430931d8","choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
  let events = @sse.parse_chat_completions_jsonl(jsonl)
  let translator = HarmonyToResponsesTranslator::new()
  let all_events : Array[(String, Json)] = []
  for event in events {
    let translated = translator.translate(event)
    for t in translated {
      all_events.push(t)
    }
  }
  // Should have: created, output_item.added, arguments.delta, completed
  let mut found_created = false
  let mut found_item_added = false
  let mut found_completed = false
  for e in all_events {
    if e.0 == "response.created" {
      found_created = true
    }
    if e.0 == "response.output_item.added" {
      found_item_added = true
    }
    if e.0 == "response.completed" {
      found_completed = true
    }
  }
  inspect(found_created, content="true")
  inspect(found_item_added, content="true")
  inspect(found_completed, content="true")
  // Reasoning should be captured
  let reasoning = translator.get_reasoning()
  inspect(reasoning.contains("We need"), content="true")
}

// =============================================================================
// Multiple Tool Calls (Parallel Execution)
// =============================================================================

///|
test "responses_input_to_messages: multiple parallel tool calls" {
  // Simulates: User -> Assistant(tool_call_1, tool_call_2) -> ToolResult_1 -> ToolResult_2
  let input : Array[Json] = [
    { "role": "user", "content": "Get time and weather" },
    {
      "type": "function_call",
      "call_id": "fc_time",
      "name": "datetime",
      "arguments": "{}",
    },
    {
      "type": "function_call",
      "call_id": "fc_weather",
      "name": "weather",
      "arguments": "{\"city\":\"Tokyo\"}",
    },
    {
      "type": "function_call_output",
      "call_id": "fc_time",
      "output": "{\"time\":\"15:00\"}",
    },
    {
      "type": "function_call_output",
      "call_id": "fc_weather",
      "output": "{\"temp\":\"20C\"}",
    },
  ]
  let messages = responses_input_to_messages(input)
  // Should be: User, Assistant(2 tool_calls), ToolResult, ToolResult
  inspect(messages.length(), content="4")
  // User
  match messages[0] {
    @types.ModelMessage::User(content~, ..) =>
      inspect(content, content="Get time and weather")
    _ => fail("Expected User")
  }
  // Assistant with 2 tool calls
  match messages[1] {
    @types.ModelMessage::Assistant(tool_calls=Some(calls), ..) => {
      inspect(calls.length(), content="2")
      inspect(calls[0].name, content="datetime")
      inspect(calls[1].name, content="weather")
    }
    _ => fail("Expected Assistant with 2 tool_calls")
  }
  // Tool results
  match messages[2] {
    @types.ModelMessage::ToolResult(tool_call_id~, ..) =>
      inspect(tool_call_id, content="fc_time")
    _ => fail("Expected ToolResult for fc_time")
  }
  match messages[3] {
    @types.ModelMessage::ToolResult(tool_call_id~, ..) =>
      inspect(tool_call_id, content="fc_weather")
    _ => fail("Expected ToolResult for fc_weather")
  }
}

///|
test "model_response_to_responses_json: multiple tool calls" {
  let calls : Array[@types.ToolCallRequest] = [
    @types.ToolCallRequest::new(
      id="fc_001",
      name="datetime",
      arguments={},
    ),
    @types.ToolCallRequest::new(
      id="fc_002",
      name="weather",
      arguments={ "city": "Tokyo" },
    ),
  ]
  let response = @types.ModelResponse::ToolCalls(calls)
  let json = model_response_to_responses_json(response)
  match json {
    { "output": Array(output), .. } => {
      inspect(output.length(), content="2")
      match output[0] {
        { "type": String("function_call"), "name": String(n), .. } =>
          inspect(n, content="datetime")
        _ => fail("Expected first function_call")
      }
      match output[1] {
        { "type": String("function_call"), "name": String(n), .. } =>
          inspect(n, content="weather")
        _ => fail("Expected second function_call")
      }
    }
    _ => fail("Expected valid response JSON")
  }
}

///|
test "HarmonyToResponsesTranslator: multiple tool calls in single chunk" {
  let translator = HarmonyToResponsesTranslator::new()
  // First chunk
  let event1 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        { "index": 0, "delta": { "role": "assistant", "content": "" } },
      ]),
    },
  }
  ignore(translator.translate(event1))
  // Multiple tool calls in single chunk
  let event2 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        {
          "index": 0,
          "delta": {
            "tool_calls": Json::array([
              {
                "id": "fc_time",
                "type": "function",
                "function": { "name": "datetime", "arguments": "{}" },
              },
              {
                "id": "fc_weather",
                "type": "function",
                "function": {
                  "name": "weather",
                  "arguments": "{\"city\":\"Tokyo\"}",
                },
              },
            ]),
          },
        },
      ]),
    },
  }
  let events2 = translator.translate(event2)
  // Should emit 2 output_item.added events
  let mut added_count = 0
  for e in events2 {
    if e.0 == "response.output_item.added" {
      added_count = added_count + 1
    }
  }
  inspect(added_count, content="2")
}

// =============================================================================
// Streaming Arguments Fragmentation
// =============================================================================

///|
test "HarmonyToResponsesTranslator: streaming arguments across chunks" {
  let translator = HarmonyToResponsesTranslator::new()
  // First chunk with role
  let event1 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        { "index": 0, "delta": { "role": "assistant", "content": "" } },
      ]),
    },
  }
  ignore(translator.translate(event1))
  // Tool call start with partial arguments
  let event2 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        {
          "index": 0,
          "delta": {
            "tool_calls": Json::array([
              {
                "id": "fc_search",
                "type": "function",
                "function": { "name": "search", "arguments": "{\"q\":" },
              },
            ]),
          },
        },
      ]),
    },
  }
  let events2 = translator.translate(event2)
  let mut found_added = false
  let mut found_args_delta = false
  for e in events2 {
    if e.0 == "response.output_item.added" {
      found_added = true
    }
    if e.0 == "response.function_call_arguments.delta" {
      found_args_delta = true
    }
  }
  inspect(found_added, content="true")
  inspect(found_args_delta, content="true")
  // Arguments continuation chunk
  let event3 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        {
          "index": 0,
          "delta": {
            "tool_calls": Json::array([
              { "function": { "arguments": "\"MoonBit\"}" } },
            ]),
          },
        },
      ]),
    },
  }
  let events3 = translator.translate(event3)
  let mut args_delta_count = 0
  for e in events3 {
    if e.0 == "response.function_call_arguments.delta" {
      args_delta_count = args_delta_count + 1
    }
  }
  inspect(args_delta_count, content="1")
  // Finish
  let event4 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        { "index": 0, "delta": {}, "finish_reason": "tool_calls" },
      ]),
    },
  }
  let events4 = translator.translate(event4)
  let mut found_completed = false
  for e in events4 {
    if e.0 == "response.completed" {
      found_completed = true
    }
  }
  inspect(found_completed, content="true")
}

// =============================================================================
// Two-Phase Conversation (Tool Call → Result → Follow-up)
// =============================================================================

///|
test "responses_input_to_messages: two-phase with follow-up after tool result" {
  // Phase 1: User -> tool_call -> tool_result
  // Phase 2: User follow-up -> model text response
  let input : Array[Json] = [
    { "role": "system", "content": "You are helpful." },
    { "role": "user", "content": "What time is it?" },
    {
      "type": "function_call",
      "call_id": "fc_123",
      "name": "datetime",
      "arguments": "{}",
    },
    {
      "type": "function_call_output",
      "call_id": "fc_123",
      "output": "{\"time\":\"15:42\",\"tz\":\"JST\"}",
    },
    { "role": "user", "content": "Thanks! What about UTC?" },
  ]
  let messages = responses_input_to_messages(input)
  inspect(messages.length(), content="5")
  // System
  match messages[0] {
    @types.ModelMessage::System(_) => ()
    _ => fail("Expected System")
  }
  // User 1
  match messages[1] {
    @types.ModelMessage::User(content~, ..) =>
      inspect(content, content="What time is it?")
    _ => fail("Expected User 1")
  }
  // Assistant with tool call
  match messages[2] {
    @types.ModelMessage::Assistant(tool_calls=Some(calls), ..) =>
      inspect(calls[0].id, content="fc_123")
    _ => fail("Expected Assistant with tool_calls")
  }
  // Tool result
  match messages[3] {
    @types.ModelMessage::ToolResult(tool_call_id~, content~) => {
      inspect(tool_call_id, content="fc_123")
      inspect(content.contains("15:42"), content="true")
    }
    _ => fail("Expected ToolResult")
  }
  // User 2 (follow-up)
  match messages[4] {
    @types.ModelMessage::User(content~, ..) =>
      inspect(content, content="Thanks! What about UTC?")
    _ => fail("Expected User 2")
  }
}

///|
test "round-trip: two-phase tool call conversation" {
  // Phase 1 request
  let phase1_request : Json = {
    "model": "openai/gpt-oss-20b",
    "input": Json::array([
      { "role": "user", "content": "What time is it?" },
    ]),
    "tools": Json::array([
      {
        "type": "function",
        "function": { "name": "datetime", "parameters": {} },
      },
    ]),
  }
  let chat_request1 = responses_request_to_chat_completions(phase1_request)
  match chat_request1 {
    { "messages": Array(msgs), .. } => inspect(msgs.length(), content="1")
    _ => fail("Expected messages")
  }
  // Simulate phase 1 response (tool call)
  let phase1_response_jsonl =
    #| {"choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{"tool_calls":[{"id":"fc_123","type":"function","function":{"name":"datetime","arguments":"{}"}}]},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
  let model_response1 = @sse.accumulate_harmony(phase1_response_jsonl)
  let responses_json1 = model_response_to_responses_json(model_response1)
  match responses_json1 {
    { "output": Array(output), .. } => {
      inspect(output.length(), content="1")
      match output[0] {
        { "type": String("function_call"), .. } => ()
        _ => fail("Expected function_call")
      }
    }
    _ => fail("Expected valid response")
  }
  // Phase 2 request (with tool result and follow-up)
  let phase2_request : Json = {
    "model": "openai/gpt-oss-20b",
    "input": Json::array([
      { "role": "user", "content": "What time is it?" },
      {
        "type": "function_call",
        "call_id": "fc_123",
        "name": "datetime",
        "arguments": "{}",
      },
      {
        "type": "function_call_output",
        "call_id": "fc_123",
        "output": "{\"time\":\"15:42\"}",
      },
      { "role": "user", "content": "And in UTC?" },
    ]),
    "tools": Json::array([
      {
        "type": "function",
        "function": { "name": "datetime", "parameters": {} },
      },
    ]),
  }
  let chat_request2 = responses_request_to_chat_completions(phase2_request)
  match chat_request2 {
    { "messages": Array(msgs), .. } => {
      // Should be: User, Assistant(tool_call), ToolResult, User(follow-up)
      inspect(msgs.length(), content="4")
    }
    _ => fail("Expected messages")
  }
}

// =============================================================================
// Error Handling & Edge Cases
// =============================================================================

///|
test "responses_input_to_messages: malformed arguments JSON" {
  // Arguments that are not valid JSON should be parsed as empty object
  let input : Array[Json] = [
    { "role": "user", "content": "Test" },
    {
      "type": "function_call",
      "call_id": "fc_bad",
      "name": "test",
      "arguments": "{invalid json}",
    },
  ]
  let messages = responses_input_to_messages(input)
  inspect(messages.length(), content="2")
  match messages[1] {
    @types.ModelMessage::Assistant(tool_calls=Some(calls), ..) => {
      // Should gracefully handle bad JSON
      inspect(calls[0].name, content="test")
    }
    _ => fail("Expected Assistant with tool_calls")
  }
}

///|
test "responses_input_to_messages: unicode in arguments" {
  let input : Array[Json] = [
    { "role": "user", "content": "日本語テスト" },
    {
      "type": "function_call",
      "call_id": "fc_jp",
      "name": "translate",
      "arguments": "{\"text\":\"こんにちは世界\",\"emoji\":\"🌸\"}",
    },
    {
      "type": "function_call_output",
      "call_id": "fc_jp",
      "output": "{\"result\":\"Hello World 🌍\"}",
    },
  ]
  let messages = responses_input_to_messages(input)
  inspect(messages.length(), content="3")
  // User message with Japanese
  match messages[0] {
    @types.ModelMessage::User(content~, ..) =>
      inspect(content, content="日本語テスト")
    _ => fail("Expected User")
  }
  // Tool call with Unicode arguments
  match messages[1] {
    @types.ModelMessage::Assistant(tool_calls=Some(calls), ..) => {
      inspect(calls[0].name, content="translate")
      // Arguments should be parsed JSON with Unicode
      match calls[0].arguments {
        { "text": String(t), .. } => inspect(t, content="こんにちは世界")
        _ => fail("Expected text field")
      }
    }
    _ => fail("Expected Assistant")
  }
  // Tool result with emoji
  match messages[2] {
    @types.ModelMessage::ToolResult(content~, ..) =>
      inspect(content.contains("🌍"), content="true")
    _ => fail("Expected ToolResult")
  }
}

///|
test "responses_input_to_messages: empty tool calls array" {
  // Edge case: function_call with empty arguments
  let input : Array[Json] = [
    { "role": "user", "content": "Test" },
    {
      "type": "function_call",
      "call_id": "fc_empty",
      "name": "ping",
      "arguments": "",
    },
  ]
  let messages = responses_input_to_messages(input)
  inspect(messages.length(), content="2")
  match messages[1] {
    @types.ModelMessage::Assistant(tool_calls=Some(calls), ..) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="ping")
    }
    _ => fail("Expected Assistant")
  }
}

///|
test "HarmonyToResponsesTranslator: empty content delta" {
  let translator = HarmonyToResponsesTranslator::new()
  // First chunk
  let event1 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([
        { "index": 0, "delta": { "role": "assistant", "content": "" } },
      ]),
    },
  }
  let events1 = translator.translate(event1)
  inspect(events1.length(), content="1") // Only response.created
  // Empty content chunk (no output_text.delta should be emitted)
  let event2 : @sse.SseEvent = {
    event: "",
    data: {
      "choices": Json::array([{ "index": 0, "delta": { "content": "" } }]),
    },
  }
  let events2 = translator.translate(event2)
  // Should be empty - no delta for empty content
  inspect(events2.length(), content="0")
}

// =============================================================================
// Full Round-trip Tests
// =============================================================================

///|
test "round-trip: Responses API request → Chat Completions → Harmony → Responses API response" {
  // 1. Start with Responses API request
  let responses_request : Json = {
    "model": "openai/gpt-oss-20b",
    "input": Json::array([
      { "role": "system", "content": "You are helpful." },
      { "role": "user", "content": "What time is it?" },
    ]),
    "tools": Json::array([
      {
        "type": "function",
        "function": { "name": "datetime", "parameters": {} },
      },
    ]),
  }
  // 2. Convert to Chat Completions request
  let chat_request = responses_request_to_chat_completions(responses_request)
  match chat_request {
    { "messages": Array(msgs), "stream": True, .. } => {
      inspect(msgs.length(), content="2")
    }
    _ => fail("Expected valid Chat Completions request")
  }
  // 3. Simulate Harmony response (using accumulator)
  let harmony_jsonl =
    #| {"choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{"tool_calls":[{"id":"fc_test","type":"function","function":{"name":"datetime","arguments":"{}"}}]},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
  let model_response = @sse.accumulate_harmony(harmony_jsonl)
  // 4. Convert ModelResponse to Responses API format
  let responses_json = model_response_to_responses_json(model_response)
  match responses_json {
    { "output": Array(output), "status": String("completed"), .. } => {
      inspect(output.length(), content="1")
      match output[0] {
        { "type": String("function_call"), "name": String(name), .. } =>
          inspect(name, content="datetime")
        _ => fail("Expected function_call")
      }
    }
    _ => fail("Expected valid Responses API response")
  }
}
