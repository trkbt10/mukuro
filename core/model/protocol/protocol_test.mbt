///|
/// Protocol Package Tests
/// Migrated from adapters/models/models_test.mbt and cmd/main/runtime_model_native_test.mbt

// =============================================================================
// Helper
// =============================================================================

///|
fn assert_true(condition : Bool) -> Unit raise {
  if not(condition) {
    fail("Assertion failed: expected true")
  }
}

///|
/// 文字列中の部分文字列の位置を返す
fn string_index_of(haystack : String, needle : String) -> Int? {
  let h_len = haystack.length()
  let n_len = needle.length()
  if n_len == 0 {
    return Some(0)
  }
  if n_len > h_len {
    return None
  }
  for i = 0; i <= h_len - n_len; i = i + 1 {
    let sub = haystack.unsafe_substring(start=i, end=i + n_len)
    if sub == needle {
      return Some(i)
    }
  }
  None
}

// =============================================================================
// Message Conversion Tests (Anthropic Format)
// =============================================================================

///|
test "message_to_anthropic_json converts System message" {
  let msg = @types.ModelMessage::System("You are a helpful assistant")
  let json = message_to_anthropic_json(msg)
  match json {
    { "role": "system", "content": "You are a helpful assistant", .. } => ()
    _ => fail("Unexpected JSON format")
  }
}

///|
test "message_to_anthropic_json converts User message without name" {
  let msg = @types.ModelMessage::User(content="Hello", name=None)
  let json = message_to_anthropic_json(msg)
  match json {
    { "role": "user", "content": "Hello", .. } => ()
    _ => fail("Unexpected JSON format")
  }
}

///|
test "message_to_anthropic_json converts User message with name" {
  let msg = @types.ModelMessage::User(content="Hello", name=Some("Alice"))
  let json = message_to_anthropic_json(msg)
  match json {
    { "role": "user", "content": "Hello", "name": "Alice", .. } => ()
    _ => fail("Unexpected JSON format")
  }
}

///|
test "message_to_anthropic_json converts Assistant message" {
  let msg = @types.ModelMessage::Assistant(content="Hi there!", tool_calls=None)
  let json = message_to_anthropic_json(msg)
  match json {
    { "role": "assistant", "content": "Hi there!", .. } => ()
    _ => fail("Unexpected JSON format")
  }
}

///|
test "message_to_anthropic_json converts Assistant with tool_calls" {
  let calls = [
    @types.ToolCallRequest::new(id="call_1", name="get_weather", arguments={
      "location": "Tokyo",
    }),
  ]
  let msg = @types.ModelMessage::Assistant(content="", tool_calls=Some(calls))
  let json = message_to_anthropic_json(msg)
  match json {
    { "role": "assistant", "content": Array(items), .. } => {
      inspect(items.length(), content="1")
      match items[0] {
        { "type": "tool_use", "id": "call_1", "name": "get_weather", .. } => ()
        _ => fail("Unexpected tool_use format")
      }
    }
    _ => fail("Unexpected JSON format")
  }
}

///|
test "message_to_anthropic_json converts ToolResult message" {
  let msg = @types.ModelMessage::ToolResult(
    tool_call_id="call_123",
    content="Result data",
  )
  let json = message_to_anthropic_json(msg)
  match json {
    { "role": "user", "content": Array(items), .. } => {
      inspect(items.length(), content="1")
      match items[0] {
        {
          "type": "tool_result",
          "tool_use_id": "call_123",
          "content": "Result data",
          ..
        } => ()
        _ => fail("Unexpected tool result format")
      }
    }
    _ => fail("Unexpected JSON format")
  }
}

// =============================================================================
// Message Conversion Tests (OpenAI Format)
// =============================================================================

///|
test "message_to_openai_json converts System message" {
  let msg = @types.ModelMessage::System("You are a helpful assistant")
  let json = message_to_openai_json(msg)
  match json {
    { "role": "system", "content": "You are a helpful assistant", .. } => ()
    _ => fail("Unexpected JSON format")
  }
}

///|
test "message_to_openai_json converts User message" {
  let msg = @types.ModelMessage::User(content="Hello", name=None)
  let json = message_to_openai_json(msg)
  match json {
    { "role": "user", "content": "Hello", .. } => ()
    _ => fail("Unexpected JSON format")
  }
}

///|
test "message_to_openai_json converts ToolResult message" {
  let msg = @types.ModelMessage::ToolResult(
    tool_call_id="call_456",
    content="Tool output",
  )
  let json = message_to_openai_json(msg)
  match json {
    { "role": "tool", "tool_call_id": "call_456", "content": "Tool output", .. } =>
      ()
    _ => fail("Unexpected JSON format")
  }
}

// =============================================================================
// Tool Definition Conversion Tests
// =============================================================================

///|
test "tool_to_anthropic_json converts correctly" {
  let tool = @types.ToolDefinition::new(
    name="search",
    description="Search the web",
    parameters={ "type": "object", "properties": {} },
  )
  let json = tool_to_anthropic_json(tool)
  match json {
    {
      "name": "search",
      "description": "Search the web",
      "input_schema": { "type": "object", .. },
      ..
    } => ()
    _ => fail("Unexpected JSON format")
  }
}

///|
test "tool_to_openai_json converts correctly" {
  let tool = @types.ToolDefinition::new(
    name="calculator",
    description="Perform calculations",
    parameters={ "type": "object" },
  )
  let json = tool_to_openai_json(tool)
  match json {
    {
      "type": "function",
      "function": {
        "name": "calculator",
        "description": "Perform calculations",
        "parameters": { "type": "object", .. },
        ..
      },
      ..
    } => ()
    _ => fail("Unexpected JSON format")
  }
}

///|
test "tool_to_responses_api_json converts correctly" {
  let tool = @types.ToolDefinition::new(
    name="datetime",
    description="Get current date/time",
    parameters={
      "type": "object",
      "properties": { "action": { "type": "string" } },
    },
  )
  let json = tool_to_responses_api_json(tool)
  let s = json.stringify()
  inspect(s.contains("\"type\":\"function\""), content="true")
  inspect(s.contains("\"name\":\"datetime\""), content="true")
  inspect(s.contains("\"parameters\""), content="true")
}

///|
test "tools_to_openai_json wraps in function object" {
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(name="get_weather", description="Get weather", parameters={
      "type": "object",
    }),
  ]
  let json_tools = tools_to_openai_json(tools)
  inspect(json_tools.length(), content="1")
  let s = json_tools[0].stringify()
  inspect(s.contains("\"function\""), content="true")
  inspect(s.contains("\"name\":\"get_weather\""), content="true")
}

///|
test "tools_to_responses_api_json produces correct format" {
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(
      name="datetime",
      description="Get current date/time",
      parameters={
        "type": "object",
        "properties": { "action": { "type": "string" } },
      },
    ),
  ]
  let json_tools = tools_to_responses_api_json(tools)
  inspect(json_tools.length(), content="1")
  let s = json_tools[0].stringify()
  inspect(s.contains("\"type\":\"function\""), content="true")
  inspect(s.contains("\"name\":\"datetime\""), content="true")
  inspect(s.contains("\"parameters\""), content="true")
}

///|
test "tools_to_anthropic_json uses input_schema" {
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(name="get_weather", description="Get weather", parameters={
      "type": "object",
    }),
  ]
  let json_tools = tools_to_anthropic_json(tools)
  inspect(json_tools.length(), content="1")
  let s = json_tools[0].stringify()
  inspect(s.contains("\"input_schema\""), content="true")
  inspect(s.contains("\"name\":\"get_weather\""), content="true")
  // Anthropic does NOT use "type":"function"
  inspect(s.contains("\"type\":\"function\""), content="false")
}

// =============================================================================
// Anthropic Response Parsing Tests
// =============================================================================

///|
test "parse_anthropic_response handles text response" {
  let response_json : Json = {
    "content": Json::array([{ "type": "text", "text": "Hello, world!" }]),
    "stop_reason": "end_turn",
  }
  let result = parse_anthropic_response(response_json)
  match result {
    @types.ModelResponse::Text(content) =>
      inspect(content, content="Hello, world!")
    _ => fail("Expected Text response")
  }
}

///|
test "parse_anthropic_response handles tool_use response" {
  let response_json : Json = {
    "content": Json::array([
      {
        "type": "tool_use",
        "id": "call_001",
        "name": "get_weather",
        "input": { "location": "Tokyo" },
      },
    ]),
    "stop_reason": "tool_use",
  }
  let result = parse_anthropic_response(response_json)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].id, content="call_001")
      inspect(calls[0].name, content="get_weather")
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "parse_anthropic_response handles error response" {
  let response_json : Json = { "error": { "message": "Invalid API key" } }
  let result = parse_anthropic_response(response_json)
  match result {
    @types.ModelResponse::ModelError(msg) =>
      inspect(msg, content="Invalid API key")
    _ => fail("Expected ModelError response")
  }
}

///|
test "parse_anthropic_response handles unknown format" {
  let response_json : Json = { "unexpected": "format" }
  let result = parse_anthropic_response(response_json)
  match result {
    @types.ModelResponse::ModelError(msg) =>
      inspect(msg, content="Unknown response format")
    _ => fail("Expected ModelError response")
  }
}

///|
test "parse_anthropic_response handles multiple text blocks" {
  let response_json : Json = {
    "content": Json::array([
      { "type": "text", "text": "First part." },
      { "type": "text", "text": "Second part." },
    ]),
    "stop_reason": "end_turn",
  }
  let result = parse_anthropic_response(response_json)
  match result {
    @types.ModelResponse::Text(content) =>
      inspect(content, content="First part.\nSecond part.")
    _ => fail("Expected Text response")
  }
}

///|
test "parse_anthropic_response extracts tool_use calls from string body" {
  let body =
    #| {
    #|   "content": [
    #|     {"type": "text", "text": "Let me check."},
    #|     {"type": "tool_use", "id": "toolu_001", "name": "get_weather", "input": {"location": "Tokyo"}}
    #|   ],
    #|   "stop_reason": "tool_use"
    #| }
  let json : Json = @json.parse(body)
  let result = parse_anthropic_response(json)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].id, content="toolu_001")
      inspect(calls[0].name, content="get_weather")
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "parse_anthropic_response returns text for end_turn" {
  let body =
    #| {
    #|   "content": [
    #|     {"type": "text", "text": "It's 22°C in Tokyo."}
    #|   ],
    #|   "stop_reason": "end_turn"
    #| }
  let json : Json = @json.parse(body)
  let result = parse_anthropic_response(json)
  match result {
    @types.ModelResponse::Text(content) => assert_true(content.contains("22"))
    _ => fail("Expected Text response")
  }
}

// =============================================================================
// OpenAI Chat Completions Response Parsing Tests
// =============================================================================

///|
test "parse_openai_chat_response handles text response" {
  let response_json : Json = {
    "choices": Json::array([
      {
        "message": { "role": "assistant", "content": "Hello!" },
        "finish_reason": "stop",
      },
    ]),
  }
  let result = parse_openai_chat_response(response_json)
  match result {
    @types.ModelResponse::Text(content) => inspect(content, content="Hello!")
    _ => fail("Expected Text response")
  }
}

///|
test "parse_openai_chat_response handles tool_calls response" {
  let response_json : Json = {
    "choices": Json::array([
      {
        "message": {
          "role": "assistant",
          "content": Json::null(),
          "tool_calls": Json::array([
            {
              "id": "call_abc",
              "type": "function",
              "function": {
                "name": "get_time",
                "arguments": "{\"timezone\": \"UTC\"}",
              },
            },
          ]),
        },
        "finish_reason": "tool_calls",
      },
    ]),
  }
  let result = parse_openai_chat_response(response_json)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].id, content="call_abc")
      inspect(calls[0].name, content="get_time")
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "parse_openai_chat_response handles error response" {
  let response_json : Json = { "error": { "message": "Rate limit exceeded" } }
  let result = parse_openai_chat_response(response_json)
  match result {
    @types.ModelResponse::ModelError(msg) =>
      inspect(msg, content="Rate limit exceeded")
    _ => fail("Expected ModelError response")
  }
}

///|
test "parse_openai_chat_response handles empty choices" {
  let response_json : Json = { "choices": Json::array([]) }
  let result = parse_openai_chat_response(response_json)
  match result {
    @types.ModelResponse::ModelError(msg) =>
      inspect(msg, content="No choices in response")
    _ => fail("Expected ModelError response")
  }
}

///|
test "parse_openai_chat_response extracts tool calls from string body" {
  let body =
    #| {
    #|   "choices": [{
    #|     "index": 0,
    #|     "message": {
    #|       "role": "assistant",
    #|       "tool_calls": [{
    #|         "id": "call_001",
    #|         "type": "function",
    #|         "function": {
    #|           "name": "datetime",
    #|           "arguments": "{\"action\":\"now\"}"
    #|         }
    #|       }]
    #|     },
    #|     "finish_reason": "tool_calls"
    #|   }]
    #| }
  let json : Json = @json.parse(body)
  let result = parse_openai_chat_response(json)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].id, content="call_001")
      inspect(calls[0].name, content="datetime")
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "parse_openai_chat_response returns text when no tool calls" {
  let body =
    #| {
    #|   "choices": [{
    #|     "index": 0,
    #|     "message": {
    #|       "role": "assistant",
    #|       "content": "The weather is 22°C."
    #|     },
    #|     "finish_reason": "stop"
    #|   }]
    #| }
  let json : Json = @json.parse(body)
  let result = parse_openai_chat_response(json)
  match result {
    @types.ModelResponse::Text(content) => assert_true(content.contains("22"))
    _ => fail("Expected Text response")
  }
}

// =============================================================================
// Responses API Response Parsing Tests
// =============================================================================

///|
test "parse_responses_api_response text" {
  let json : Json = {
    "output": Json::array([
      {
        "id": "msg_1",
        "type": "message",
        "status": "completed",
        "content": Json::array([
          {
            "type": "output_text",
            "annotations": Json::array([]),
            "text": "Four.",
          },
        ]),
        "role": "assistant",
      },
    ]),
    "status": "completed",
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::Text(content) => inspect(content, content="Four.")
    _ => fail("Expected Text response")
  }
}

///|
test "parse_responses_api_response tool call" {
  let json : Json = {
    "output": Json::array([
      {
        "id": "fc_1",
        "type": "function_call",
        "status": "completed",
        "arguments": "{\"location\":\"Tokyo\"}",
        "call_id": "call_xyz",
        "name": "get_weather",
      },
    ]),
    "status": "completed",
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
      inspect(calls[0].id, content="call_xyz")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "parse_responses_api_response with reasoning + text" {
  let json : Json = {
    "output": Json::array([
      {
        "type": "reasoning",
        "id": "r1",
        "content": Json::array([
          { "type": "reasoning_text", "text": "The user wants 2+2..." },
        ]),
      },
      {
        "type": "message",
        "id": "msg_1",
        "status": "completed",
        "role": "assistant",
        "content": Json::array([{ "type": "output_text", "text": "4" }]),
      },
    ]),
    "status": "completed",
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::Text(content) => inspect(content, content="4")
    _ => fail("Expected Text response")
  }
}

///|
test "parse_responses_api_response with reasoning + function_call" {
  let json : Json = {
    "output": Json::array([
      {
        "type": "reasoning",
        "id": "r1",
        "content": Json::array([
          { "type": "reasoning_text", "text": "Use get_weather tool." },
        ]),
      },
      {
        "type": "function_call",
        "id": "fc_001",
        "status": "completed",
        "call_id": "fc_001",
        "name": "get_weather",
        "arguments": "{\"location\":\"Tokyo\"}",
      },
    ]),
    "status": "completed",
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "parse_responses_api_response error" {
  let json : Json = {
    "error": { "message": "Invalid API key", "type": "invalid_request_error" },
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::ModelError(msg) =>
      inspect(msg, content="Invalid API key")
    _ => fail("Expected ModelError response")
  }
}

// =============================================================================
// Tool Call Parsing Tests
// =============================================================================

///|
test "parse_anthropic_tool_calls extracts tool calls" {
  let content : Json = Json::array([
    {
      "type": "tool_use",
      "id": "call_1",
      "name": "read_file",
      "input": { "path": "/tmp/test.txt" },
    },
    {
      "type": "tool_use",
      "id": "call_2",
      "name": "write_file",
      "input": { "path": "/tmp/out.txt", "content": "data" },
    },
  ])
  let calls = parse_anthropic_tool_calls(content)
  inspect(calls.length(), content="2")
  inspect(calls[0].id, content="call_1")
  inspect(calls[0].name, content="read_file")
  inspect(calls[1].id, content="call_2")
  inspect(calls[1].name, content="write_file")
}

///|
test "parse_anthropic_tool_calls handles non-tool_use items" {
  let content : Json = Json::array([
    { "type": "text", "text": "Some text" },
    { "type": "tool_use", "id": "call_1", "name": "test", "input": {} },
  ])
  let calls = parse_anthropic_tool_calls(content)
  inspect(calls.length(), content="1")
  inspect(calls[0].name, content="test")
}

///|
test "parse_anthropic_tool_calls handles empty array" {
  let content : Json = Json::array([])
  let calls = parse_anthropic_tool_calls(content)
  inspect(calls.length(), content="0")
}

///|
test "parse_openai_tool_calls extracts tool calls" {
  let tool_calls : Json = Json::array([
    {
      "id": "call_xyz",
      "type": "function",
      "function": { "name": "search", "arguments": "{\"query\": \"test\"}" },
    },
  ])
  let calls = parse_openai_tool_calls(tool_calls)
  inspect(calls.length(), content="1")
  inspect(calls[0].id, content="call_xyz")
  inspect(calls[0].name, content="search")
}

///|
test "parse_openai_tool_calls handles invalid JSON arguments" {
  let tool_calls : Json = Json::array([
    {
      "id": "call_1",
      "type": "function",
      "function": { "name": "test", "arguments": "invalid json {" },
    },
  ])
  let calls = parse_openai_tool_calls(tool_calls)
  inspect(calls.length(), content="1")
  inspect(calls[0].name, content="test")
}

// =============================================================================
// Array Message Conversion Tests
// =============================================================================

///|
test "messages_to_openai_json converts all message types" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are helpful"),
    @types.ModelMessage::User(content="Hello", name=None),
    @types.ModelMessage::Assistant(content="Hi!", tool_calls=None),
    @types.ModelMessage::ToolResult(tool_call_id="call_1", content="result"),
  ]
  let result = messages_to_openai_json(messages)
  inspect(result.length(), content="4")
  match result[0] {
    { "role": "system", .. } => ()
    _ => fail("Expected system role")
  }
  match result[3] {
    { "role": "tool", "tool_call_id": "call_1", .. } => ()
    _ => fail("Expected tool role")
  }
}

///|
test "messages_to_anthropic_json excludes System messages" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are helpful"),
    @types.ModelMessage::User(content="Hello", name=None),
    @types.ModelMessage::Assistant(content="Hi!", tool_calls=None),
  ]
  let result = messages_to_anthropic_json(messages)
  inspect(result.length(), content="2")
  match result[0] {
    { "role": "user", .. } => ()
    _ => fail("Expected user role as first")
  }
}

///|
test "messages_to_anthropic_json includes text+tool_use in assistant" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::Assistant(
      content="Let me check.",
      tool_calls=Some([
        @types.ToolCallRequest::new(id="toolu_001", name="get_weather", arguments={
          "location": "Tokyo",
        }),
      ]),
    ),
  ]
  let result = messages_to_anthropic_json(messages)
  inspect(result.length(), content="1")
  let s = result[0].stringify()
  // Should have text block and tool_use block in content array
  assert_true(s.contains("\"type\":\"text\""))
  assert_true(s.contains("\"type\":\"tool_use\""))
}

///|
test "messages_to_responses_input converts all message types" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are helpful"),
    @types.ModelMessage::User(content="Hello", name=None),
    @types.ModelMessage::Assistant(
      content="",
      tool_calls=Some([
        @types.ToolCallRequest::new(id="fc_001", name="get_weather", arguments={
          "location": "Tokyo",
        }),
      ]),
    ),
    @types.ModelMessage::ToolResult(
      tool_call_id="fc_001",
      content="{\"temperature\":22}",
    ),
  ]
  let result = messages_to_responses_input(messages)
  // system + user + function_call + function_call_output = 4
  inspect(result.length(), content="4")
  match result[0] {
    { "role": "system", .. } => ()
    _ => fail("Expected system role")
  }
  match result[2] {
    { "type": "function_call", "call_id": "fc_001", .. } => ()
    _ => fail("Expected function_call")
  }
  match result[3] {
    { "type": "function_call_output", "call_id": "fc_001", .. } => ()
    _ => fail("Expected function_call_output")
  }
}

///|
test "extract_system_message finds first system message" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("Be helpful"),
    @types.ModelMessage::User(content="Hi", name=None),
  ]
  inspect(extract_system_message(messages), content="Be helpful")
}

///|
test "extract_system_message returns empty when no system" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hi", name=None),
  ]
  inspect(extract_system_message(messages), content="")
}

// =============================================================================
// Body Builder Tests
// =============================================================================

///|
test "build_openai_chat_body without tools omits tools and tool_choice" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hello", name=None),
  ]
  let body = build_openai_chat_body("gpt-4", messages, [])
  let s = body.stringify()
  inspect(s.contains("\"tools\""), content="false")
  inspect(s.contains("\"tool_choice\""), content="false")
  inspect(s.contains("\"model\":\"gpt-4\""), content="true")
}

///|
test "build_openai_chat_body with tools includes tool_choice auto" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hello", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(name="calc", description="Calculator", parameters={
      "type": "object",
    }),
  ]
  let body = build_openai_chat_body("gpt-4", messages, tools)
  let s = body.stringify()
  inspect(s.contains("\"tools\""), content="true")
  inspect(s.contains("\"tool_choice\":\"auto\""), content="true")
}

///|
test "build_openai_chat_body with optional params" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hi", name=None),
  ]
  let body = build_openai_chat_body(
    "gpt-4",
    messages,
    [],
    max_tokens=Some(1000),
    temperature=Some(0.5),
  )
  let s = body.stringify()
  assert_true(s.contains("\"max_tokens\""))
  assert_true(s.contains("\"temperature\""))
}

///|
test "build_responses_api_body without tools omits tools" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hello", name=None),
  ]
  let body = build_responses_api_body("gpt-4", messages, [])
  let s = body.stringify()
  inspect(s.contains("\"tools\""), content="false")
  inspect(s.contains("\"tool_choice\""), content="false")
  inspect(s.contains("\"input\""), content="true")
}

///|
test "build_responses_api_body with tools includes tool_choice auto" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hello", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(name="datetime", description="Get time", parameters={
      "type": "object",
    }),
  ]
  let body = build_responses_api_body("gpt-4", messages, tools)
  let s = body.stringify()
  inspect(s.contains("\"tools\""), content="true")
  inspect(s.contains("\"tool_choice\":\"auto\""), content="true")
  inspect(s.contains("\"type\":\"function\""), content="true")
}

///|
test "build_anthropic_body includes system and max_tokens" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are helpful"),
    @types.ModelMessage::User(content="Hi", name=None),
  ]
  let body = build_anthropic_body("claude-3", messages, [])
  let s = body.stringify()
  assert_true(s.contains("\"system\":\"You are helpful\""))
  assert_true(s.contains("\"max_tokens\""))
  // System message should NOT be in messages array
  match body {
    { "messages": Array(msgs), .. } =>
      // Only user message
      inspect(msgs.length(), content="1")
    _ => fail("Expected messages array")
  }
}

///|
test "build_anthropic_body with tools includes tools array" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hi", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(name="get_weather", description="Get weather", parameters={
      "type": "object",
    }),
  ]
  let body = build_anthropic_body("claude-3", messages, tools)
  let s = body.stringify()
  assert_true(s.contains("\"tools\""))
  assert_true(s.contains("\"input_schema\""))
}

// =============================================================================
// Regression: Groq 400 error prevention
// =============================================================================

///|
test "regression: responses_api body includes function_call before function_call_output" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(
      content="What is the weather in Tokyo?",
      name=None,
    ),
    @types.ModelMessage::Assistant(
      content="",
      tool_calls=Some([
        @types.ToolCallRequest::new(id="fc_001", name="get_weather", arguments={
          "location": "Tokyo",
        }),
      ]),
    ),
    @types.ModelMessage::ToolResult(
      tool_call_id="fc_001",
      content="{\"temperature\":22,\"condition\":\"Partly cloudy\"}",
    ),
  ]
  let body = build_responses_api_body("openai/gpt-oss-20b", messages, [])
  let s = body.stringify()
  // Must contain function_call item
  inspect(s.contains("function_call"), content="true")
  // Must contain function_call_output item
  inspect(s.contains("function_call_output"), content="true")
  // function_call must appear BEFORE function_call_output
  match
    (
      string_index_of(s, "function_call\""),
      string_index_of(s, "function_call_output"),
    ) {
    (Some(fc_pos), Some(fco_pos)) => inspect(fc_pos < fco_pos, content="true")
    _ => fail("Both function_call and function_call_output must be present")
  }
  // call_id must be preserved
  inspect(s.contains("fc_001"), content="true")
}

///|
test "regression: chat_completions body includes tool_calls and tool role for multi-turn" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(
      content="What is the weather in Tokyo?",
      name=None,
    ),
    @types.ModelMessage::Assistant(
      content="",
      tool_calls=Some([
        @types.ToolCallRequest::new(id="call_abc", name="get_weather", arguments={
          "location": "Tokyo",
        }),
      ]),
    ),
    @types.ModelMessage::ToolResult(
      tool_call_id="call_abc",
      content="{\"temperature\":22}",
    ),
  ]
  let body = build_openai_chat_body("gpt-4", messages, [])
  let s = body.stringify()
  // Assistant message must have tool_calls array
  inspect(s.contains("\"tool_calls\""), content="true")
  // Tool result must have role "tool" and tool_call_id
  inspect(s.contains("\"role\":\"tool\""), content="true")
  inspect(s.contains("\"tool_call_id\":\"call_abc\""), content="true")
}

///|
test "regression: anthropic body includes tool_use and tool_result for multi-turn" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are a helpful assistant."),
    @types.ModelMessage::User(
      content="What is the weather in Tokyo?",
      name=None,
    ),
    @types.ModelMessage::Assistant(
      content="Let me check.",
      tool_calls=Some([
        @types.ToolCallRequest::new(id="toolu_001", name="get_weather", arguments={
          "location": "Tokyo",
        }),
      ]),
    ),
    @types.ModelMessage::ToolResult(
      tool_call_id="toolu_001",
      content="{\"temperature\":22}",
    ),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(name="get_weather", description="Get weather", parameters={
      "type": "object",
      "properties": { "location": { "type": "string" } },
    }),
  ]
  let body = build_anthropic_body("claude-3", messages, tools)
  let s = body.stringify()
  // System prompt extracted
  inspect(
    s.contains("\"system\":\"You are a helpful assistant.\""),
    content="true",
  )
  // tool_use in assistant message
  inspect(s.contains("\"type\":\"tool_use\""), content="true")
  // tool_result in user message
  inspect(s.contains("\"type\":\"tool_result\""), content="true")
  inspect(s.contains("\"tool_use_id\":\"toolu_001\""), content="true")
  // input_schema in tools
  inspect(s.contains("\"input_schema\""), content="true")
}

///|
test "regression: tool_choice auto with non-empty tools" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hello", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(name="test", description="Test tool", parameters={
      "type": "object",
    }),
  ]
  // OpenAI Chat Completions
  let chat_body = build_openai_chat_body("gpt-4", messages, tools)
  inspect(
    chat_body.stringify().contains("\"tool_choice\":\"auto\""),
    content="true",
  )
  // Responses API
  let resp_body = build_responses_api_body("gpt-4", messages, tools)
  inspect(
    resp_body.stringify().contains("\"tool_choice\":\"auto\""),
    content="true",
  )
}

///|
test "regression: no tool_choice when tools empty" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hello", name=None),
  ]
  let empty_tools : Array[@types.ToolDefinition] = []
  // OpenAI Chat Completions
  let chat_body = build_openai_chat_body("gpt-4", messages, empty_tools)
  inspect(chat_body.stringify().contains("tool_choice"), content="false")
  // Responses API
  let resp_body = build_responses_api_body("gpt-4", messages, empty_tools)
  inspect(resp_body.stringify().contains("tool_choice"), content="false")
}

///|
/// Regression test for two-phase conversation with tool calls
/// Simulates: User -> Assistant(tool_call) -> ToolResult -> User(follow-up)
/// This pattern failed with Groq Responses API: "Tools should have a name!"
test "regression: two_phase_conversation_with_tool_call_openai_chat" {
  // Phase 1: Initial exchange with tool call
  // Phase 2: Follow-up question after tool result
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are a helpful assistant."),
    // Turn 1: User asks
    @types.ModelMessage::User(
      content="List files in current directory",
      name=None,
    ),
    // Turn 1: Assistant responds with tool call
    @types.ModelMessage::Assistant(
      content="",
      tool_calls=Some([
        @types.ToolCallRequest::new(id="call_abc123", name="shell", arguments={
          "command": "ls",
        }),
      ]),
    ),
    // Turn 1: Tool result
    @types.ModelMessage::ToolResult(
      tool_call_id="call_abc123",
      content="file1.txt\nfile2.txt\ndir1",
    ),
    // Turn 2: User follow-up (THIS IS WHERE IT FAILED)
    @types.ModelMessage::User(content="Now show details with ls -la", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(
      name="shell",
      description="Execute shell commands",
      parameters={
        "type": "object",
        "properties": { "command": { "type": "string" } },
        "required": ["command"],
      },
    ),
  ]
  let body = build_openai_chat_body("openai/gpt-oss-20b", messages, tools)
  let s = body.stringify()
  // Verify structure
  inspect(s.contains("\"model\":\"openai/gpt-oss-20b\""), content="true")
  inspect(s.contains("\"messages\""), content="true")
  inspect(s.contains("\"tools\""), content="true")
  inspect(s.contains("\"tool_choice\":\"auto\""), content="true")
  // Verify tool call in assistant message
  inspect(s.contains("\"tool_calls\""), content="true")
  inspect(s.contains("\"id\":\"call_abc123\""), content="true")
  inspect(s.contains("\"name\":\"shell\""), content="true")
  // Verify tool result
  inspect(s.contains("\"role\":\"tool\""), content="true")
  inspect(s.contains("\"tool_call_id\":\"call_abc123\""), content="true")
  // Verify tools have name
  inspect(s.contains("\"function\":{\"name\":\"shell\""), content="true")
  // Verify follow-up user message exists
  let body_json = @json.parse(s) catch { _ => return fail("Invalid JSON") }
  match body_json {
    { "messages": Array(msgs), .. } => {
      // Should have 5 messages
      inspect(msgs.length(), content="5")
      // Last message should be user follow-up
      match msgs[4] {
        { "role": String("user"), "content": String(content), .. } =>
          inspect(content, content="Now show details with ls -la")
        _ => fail("Last message should be user follow-up")
      }
    }
    _ => fail("Expected messages array")
  }
}

///|
/// Regression test for two-phase conversation with Responses API format
test "regression: two_phase_conversation_with_tool_call_responses_api" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are a helpful assistant."),
    @types.ModelMessage::User(content="List files", name=None),
    @types.ModelMessage::Assistant(
      content="",
      tool_calls=Some([
        @types.ToolCallRequest::new(id="fc_xyz789", name="shell", arguments={
          "command": "ls",
        }),
      ]),
    ),
    @types.ModelMessage::ToolResult(
      tool_call_id="fc_xyz789",
      content="a.txt\nb.txt",
    ),
    @types.ModelMessage::User(content="Show details", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(
      name="shell",
      description="Execute shell commands",
      parameters={
        "type": "object",
        "properties": { "command": { "type": "string" } },
      },
    ),
  ]
  let body = build_responses_api_body("openai/gpt-oss-20b", messages, tools)
  let s = body.stringify()
  // Verify Responses API structure
  inspect(s.contains("\"model\":\"openai/gpt-oss-20b\""), content="true")
  inspect(s.contains("\"input\""), content="true")
  inspect(s.contains("\"tools\""), content="true")
  inspect(s.contains("\"tool_choice\":\"auto\""), content="true")
  // Verify function_call in input
  inspect(s.contains("\"type\":\"function_call\""), content="true")
  inspect(s.contains("\"call_id\":\"fc_xyz789\""), content="true")
  inspect(s.contains("\"name\":\"shell\""), content="true")
  // Verify function_call_output
  inspect(s.contains("\"type\":\"function_call_output\""), content="true")
  // Verify tools have name at top level (Responses API format)
  inspect(
    s.contains("\"type\":\"function\",\"name\":\"shell\""),
    content="true",
  )
  // Parse and verify structure
  let body_json = @json.parse(s) catch { _ => return fail("Invalid JSON") }
  match body_json {
    { "input": Array(items), "tools": Array(tool_defs), .. } => {
      // Verify tools have name
      for tool_def in tool_defs {
        match tool_def {
          { "name": String(name), .. } =>
            inspect(name.length() > 0, content="true")
          _ => fail("Tool definition missing name")
        }
      }
      // Count input items
      inspect(items.length() > 0, content="true")
    }
    _ => fail("Expected input and tools arrays")
  }
}

///|
/// Regression test for chained tool calls: multiple tool calls in sequence
test "regression: chained_toolcalls_responses_api" {
  // Scenario: User asks for file list + content, model makes two tool calls
  // 1. shell(ls) -> result -> 2. shell(cat README.md) -> result -> 3. text response
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are a helpful assistant."),
    @types.ModelMessage::User(
      content="List files and then show me the content of the first file",
      name=None,
    ),
    // First tool call
    @types.ModelMessage::Assistant(
      content="",
      tool_calls=Some([
        @types.ToolCallRequest::new(id="fc_001", name="shell", arguments={
          "command": "ls",
        }),
      ]),
    ),
    @types.ModelMessage::ToolResult(
      tool_call_id="fc_001",
      content="README.md\nconfig.json\nmain.py",
    ),
    // Second tool call (chained)
    @types.ModelMessage::Assistant(
      content="",
      tool_calls=Some([
        @types.ToolCallRequest::new(id="fc_002", name="shell", arguments={
          "command": "cat README.md",
        }),
      ]),
    ),
    @types.ModelMessage::ToolResult(
      tool_call_id="fc_002",
      content="# My Project\n\nThis is a sample project.",
    ),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(
      name="shell",
      description="Execute shell commands",
      parameters={
        "type": "object",
        "properties": { "command": { "type": "string" } },
        "required": ["command"],
      },
    ),
  ]
  let body = build_responses_api_body("openai/gpt-oss-20b", messages, tools)
  let s = body.stringify()
  // Verify both function_calls are present
  let fc_001_count = count_occurrences(s, "fc_001")
  let fc_002_count = count_occurrences(s, "fc_002")
  inspect(fc_001_count, content="2") // call_id appears in function_call and function_call_output
  inspect(fc_002_count, content="2")
  // Verify function_call_output for both
  let output_count = count_occurrences(s, "function_call_output")
  inspect(output_count, content="2")
  // Parse and verify input items count
  let body_json = @json.parse(s) catch { _ => return fail("Invalid JSON") }
  match body_json {
    { "input": Array(items), .. } =>
      // system + user + fc1 + fc1_output + fc2 + fc2_output = 6 items
      inspect(items.length(), content="6")
    _ => fail("Expected input array")
  }
}

///|
/// Helper to count substring occurrences
fn count_occurrences(haystack : String, needle : String) -> Int {
  let mut count = 0
  let mut pos = 0
  let haystack_chars = haystack.to_array()
  let needle_chars = needle.to_array()
  while pos <= haystack_chars.length() - needle_chars.length() {
    let mut match_found = true
    for i in 0..<needle_chars.length() {
      if haystack_chars[pos + i] != needle_chars[i] {
        match_found = false
        break
      }
    }
    if match_found {
      count = count + 1
      pos = pos + needle_chars.length()
    } else {
      pos = pos + 1
    }
  }
  count
}

///|
/// Test parsing chained tool call response from Groq Responses API
test "parse_responses_api_response - chained_toolcall" {
  // Response fixture: model makes second tool call after first result
  let json_str =
    #|{
    #|  "id": "resp_01kjpjhcmse1kb4tmmt55r04bb",
    #|  "object": "response",
    #|  "status": "completed",
    #|  "output": [
    #|    {
    #|      "type": "function_call",
    #|      "id": "fc_e85599c2-2f7a-4864-b0bb-9fb740ee5bde",
    #|      "status": "completed",
    #|      "call_id": "fc_e85599c2-2f7a-4864-b0bb-9fb740ee5bde",
    #|      "name": "shell",
    #|      "arguments": "{\"command\":\"cat README.md\"}"
    #|    }
    #|  ],
    #|  "model": "openai/gpt-oss-20b"
    #|}
  let json = @json.parse(json_str) catch { _ => return fail("Invalid JSON") }
  let response = parse_responses_api_response(json)
  match response {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="shell")
      inspect(
        calls[0].arguments.stringify().contains("cat README.md"),
        content="true",
      )
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
/// Test parsing final text response after chained tool calls
test "parse_responses_api_response - chained_final_text" {
  // Response fixture: final text response after two tool call cycles
  let json_str =
    #|{
    #|  "id": "resp_01kjpjhqhnfhhbmdpq77agxz22",
    #|  "object": "response",
    #|  "status": "completed",
    #|  "output": [
    #|    {
    #|      "type": "message",
    #|      "id": "msg_01kjpjhqhnfhj8yy8eey0nmnem",
    #|      "status": "completed",
    #|      "role": "assistant",
    #|      "content": [
    #|        {
    #|          "type": "output_text",
    #|          "text": "**Files:**\n1. README.md\n2. config.json",
    #|          "annotations": []
    #|        }
    #|      ]
    #|    }
    #|  ],
    #|  "model": "openai/gpt-oss-20b"
    #|}
  let json = @json.parse(json_str) catch { _ => return fail("Invalid JSON") }
  let response = parse_responses_api_response(json)
  match response {
    @types.ModelResponse::Text(content) => {
      inspect(content.contains("README.md"), content="true")
      inspect(content.contains("config.json"), content="true")
    }
    _ => fail("Expected Text response")
  }
}

// =============================================================================
// Regression Tests: Text-Only Conversation Continuation
// =============================================================================

///|
/// 回帰テスト: 純粋テキスト会話の Responses API 変換
/// ツール呼び出しなしの会話が正しく変換されることを確認
/// バグ: 2ターン目で ModelCallFailed が発生（純粋テキスト版）
test "messages_to_responses_input: text_only_conversation" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are a helpful assistant."),
    @types.ModelMessage::User(content="ブースとラプう", name=None),
    @types.ModelMessage::Assistant(
      content="「ブースとラプう」について、もう少し詳しく教えてください。",
      tool_calls=None,
    ),
    @types.ModelMessage::User(content="bootstrapって完了した？", name=None),
  ]

  let input = messages_to_responses_input(messages)

  // 4 items: system, user, assistant, user
  inspect(input.length(), content="4")

  // Check each item has correct structure
  match input[0] {
    Object(obj) => {
      inspect(obj.get("role"), content="Some(String(\"system\"))")
      inspect(
        obj.get("content"),
        content="Some(String(\"You are a helpful assistant.\"))",
      )
    }
    _ => fail("Expected object at index 0")
  }

  match input[1] {
    Object(obj) => {
      inspect(obj.get("role"), content="Some(String(\"user\"))")
      inspect(obj.get("content"), content="Some(String(\"ブースとラプう\"))")
    }
    _ => fail("Expected object at index 1")
  }

  match input[2] {
    Object(obj) => {
      inspect(obj.get("role"), content="Some(String(\"assistant\"))")
      inspect(
        obj.get("content"),
        content="Some(String(\"「ブースとラプう」について、もう少し詳しく教えてください。\"))",
      )
      // 重要: function_call 系のフィールドがないこと
      inspect(obj.get("type"), content="None")
      inspect(obj.get("call_id"), content="None")
    }
    _ => fail("Expected object at index 2")
  }

  match input[3] {
    Object(obj) => {
      inspect(obj.get("role"), content="Some(String(\"user\"))")
      inspect(
        obj.get("content"),
        content="Some(String(\"bootstrapって完了した？\"))",
      )
    }
    _ => fail("Expected object at index 3")
  }
}

///|
/// 回帰テスト: build_responses_api_body でツールなしの場合
/// tools が空配列の場合、tool_choice フィールドが含まれないこと
test "build_responses_api_body: no_tools_no_tool_choice" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are a helpful assistant."),
    @types.ModelMessage::User(content="Hello", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = []

  let body = build_responses_api_body("openai/gpt-oss-20b", messages, tools)

  // tools フィールドがないこと
  match body {
    Object(obj) => {
      inspect(obj.get("tools"), content="None")
      inspect(obj.get("tool_choice"), content="None")
    }
    _ => fail("Expected object body")
  }
}

///|
/// 回帰テスト: build_responses_api_body でツールありの場合
/// tools がある場合、tool_choice: "auto" が含まれること
test "build_responses_api_body: with_tools_has_tool_choice" {
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are a helpful assistant."),
    @types.ModelMessage::User(content="List files", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(
      name="shell",
      description="Execute shell commands",
      parameters={ "type": "object" },
    ),
  ]

  let body = build_responses_api_body("openai/gpt-oss-20b", messages, tools)

  // tool_choice: "auto" があること
  match body {
    Object(obj) => {
      match obj.get("tool_choice") {
        Some(String(choice)) => inspect(choice, content="auto")
        _ => fail("Expected tool_choice: auto")
      }
    }
    _ => fail("Expected object body")
  }
}
