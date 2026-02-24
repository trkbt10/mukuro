///|
/// Model Provider Tests

// =============================================================================
// Base Helper Function Tests
// =============================================================================

///|
test "status_code_to_status returns Success for 2xx" {
  match status_code_to_status(200) {
    ApiResponseStatus::Success => ()
    _ => fail("Expected Success")
  }
  match status_code_to_status(201) {
    ApiResponseStatus::Success => ()
    _ => fail("Expected Success")
  }
  match status_code_to_status(204) {
    ApiResponseStatus::Success => ()
    _ => fail("Expected Success")
  }
}

///|
test "status_code_to_status returns RateLimited for 429" {
  match status_code_to_status(429) {
    ApiResponseStatus::RateLimited(retry_after) =>
      inspect(retry_after, content="60")
    _ => fail("Expected RateLimited")
  }
}

///|
test "status_code_to_status returns ClientError for 4xx" {
  match status_code_to_status(400) {
    ApiResponseStatus::ClientError(code) => inspect(code, content="400")
    _ => fail("Expected ClientError")
  }
  match status_code_to_status(404) {
    ApiResponseStatus::ClientError(code) => inspect(code, content="404")
    _ => fail("Expected ClientError")
  }
}

///|
test "status_code_to_status returns ServerError for 5xx" {
  match status_code_to_status(500) {
    ApiResponseStatus::ServerError(code) => inspect(code, content="500")
    _ => fail("Expected ServerError")
  }
  match status_code_to_status(503) {
    ApiResponseStatus::ServerError(code) => inspect(code, content="503")
    _ => fail("Expected ServerError")
  }
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

// =============================================================================
// OpenAI Response Parsing Tests
// =============================================================================

///|
test "parse_openai_response handles text response" {
  let response_json : Json = {
    "choices": Json::array([
      {
        "message": { "role": "assistant", "content": "Hello!" },
        "finish_reason": "stop",
      },
    ]),
  }
  let result = parse_openai_response(response_json)
  match result {
    @types.ModelResponse::Text(content) => inspect(content, content="Hello!")
    _ => fail("Expected Text response")
  }
}

///|
test "parse_openai_response handles tool_calls response" {
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
  let result = parse_openai_response(response_json)
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
test "parse_openai_response handles error response" {
  let response_json : Json = { "error": { "message": "Rate limit exceeded" } }
  let result = parse_openai_response(response_json)
  match result {
    @types.ModelResponse::ModelError(msg) =>
      inspect(msg, content="Rate limit exceeded")
    _ => fail("Expected ModelError response")
  }
}

///|
test "parse_openai_response handles empty choices" {
  let response_json : Json = { "choices": Json::array([]) }
  let result = parse_openai_response(response_json)
  match result {
    @types.ModelResponse::ModelError(msg) =>
      inspect(msg, content="No choices in response")
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
// Anthropic Request Building Tests
// =============================================================================

///|
test "AnthropicProvider::build_request creates valid request" {
  let provider = AnthropicProvider::from_api_key("test_key")
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are helpful"),
    @types.ModelMessage::User(content="Hi", name=None),
  ]
  let options = @types.ModelOptions::default()
  let request = provider.build_request(messages, [], options)
  match request {
    {
      "model": String(model),
      "messages": Array(msgs),
      "system": String(sys),
      ..
    } => {
      assert_true(model.length() > 0)
      inspect(msgs.length(), content="1")
      inspect(sys, content="You are helpful")
    }
    _ => fail("Invalid request format")
  }
}

///|
test "AnthropicProvider::build_request includes tools" {
  let provider = AnthropicProvider::from_api_key("test_key")
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Search for cats", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(name="search", description="Search the web", parameters={
      "type": "object",
    }),
  ]
  let options = @types.ModelOptions::default()
  let request = provider.build_request(messages, tools, options)
  match request {
    { "tools": Array(tool_arr), .. } => inspect(tool_arr.length(), content="1")
    _ => fail("Expected tools in request")
  }
}

///|
test "AnthropicProvider::build_request includes temperature" {
  let provider = AnthropicProvider::from_api_key("test_key")
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hi", name=None),
  ]
  let options : @types.ModelOptions = {
    model_name: "claude-3-opus-20240229",
    temperature: Some(0.7),
    max_tokens: Some(1000),
    stop_sequences: None,
  }
  let request = provider.build_request(messages, [], options)
  match request {
    { "temperature": Number(temp, ..), "max_tokens": Number(max, ..), .. } => {
      assert_true(temp > 0.6 && temp < 0.8)
      assert_true(max > 999.0 && max < 1001.0)
    }
    _ => fail("Expected temperature and max_tokens in request")
  }
}

// =============================================================================
// OpenAI Request Building Tests
// =============================================================================

///|
test "OpenAIProvider::build_request creates valid request" {
  let provider = OpenAIProvider::from_api_key("test_key")
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are helpful"),
    @types.ModelMessage::User(content="Hello", name=None),
  ]
  let options = @types.ModelOptions::default()
  let request = provider.build_request(messages, [], options)
  match request {
    { "model": String(model), "messages": Array(msgs), .. } => {
      assert_true(model.length() > 0)
      inspect(msgs.length(), content="2")
    }
    _ => fail("Invalid request format")
  }
}

///|
test "OpenAIProvider::build_request includes tools" {
  let provider = OpenAIProvider::from_api_key("test_key")
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Calculate 2+2", name=None),
  ]
  let tools : Array[@types.ToolDefinition] = [
    @types.ToolDefinition::new(
      name="calculator",
      description="Perform calculations",
      parameters={ "type": "object" },
    ),
  ]
  let options = @types.ModelOptions::default()
  let request = provider.build_request(messages, tools, options)
  match request {
    { "tools": Array(tool_arr), .. } => inspect(tool_arr.length(), content="1")
    _ => fail("Expected tools in request")
  }
}

// =============================================================================
// Fallback Orchestrator Tests
// =============================================================================

///|
test "FallbackConfig::default has reasonable values" {
  let config = FallbackConfig::default()
  inspect(config.enabled, content="true")
  inspect(config.max_retries, content="3")
  assert_true(config.cooldown_ms > 0L)
}

///|
test "ProviderState::new creates available state" {
  let state = ProviderState::new()
  inspect(state.available, content="true")
  inspect(state.error_count, content="0")
  inspect(state.last_error_at, content="0")
}

///|
test "FallbackOrchestrator::is_provider_available returns true for new provider" {
  let provider = MockProvider::new("test_provider")
  let orchestrator = FallbackOrchestrator::new(
    providers=[provider],
    config=FallbackConfig::default(),
  )
  let available = orchestrator.is_provider_available("test_provider", 0L)
  inspect(available, content="true")
}

///|
test "FallbackOrchestrator::record_error marks provider unavailable after max retries" {
  let provider = MockProvider::new("test")
  let config : FallbackConfig = {
    enabled: true,
    cooldown_ms: 1000L,
    max_retries: 2,
  }
  let orchestrator = FallbackOrchestrator::new(providers=[provider], config~)
  orchestrator.record_error("test", 1000L)
  inspect(orchestrator.is_provider_available("test", 1000L), content="true")
  orchestrator.record_error("test", 2000L)
  inspect(orchestrator.is_provider_available("test", 2000L), content="false")
}

///|
test "FallbackOrchestrator::record_success resets state" {
  let provider = MockProvider::new("test")
  let orchestrator = FallbackOrchestrator::new(
    providers=[provider],
    config=FallbackConfig::default(),
  )
  orchestrator.record_error("test", 1000L)
  orchestrator.record_success("test")
  let state = orchestrator.states.get("test")
  match state {
    Some(s) => {
      inspect(s.available, content="true")
      inspect(s.error_count, content="0")
    }
    None => fail("Expected state to exist")
  }
}

///|
test "FallbackOrchestrator::reset_all resets all providers" {
  let provider1 = MockProvider::new("p1")
  let provider2 = MockProvider::new("p2")
  let orchestrator = FallbackOrchestrator::new(
    providers=[provider1, provider2],
    config=FallbackConfig::default(),
  )
  orchestrator.record_error("p1", 1000L)
  orchestrator.record_error("p2", 1000L)
  orchestrator.reset_all()
  let state1 = orchestrator.states.get("p1")
  let state2 = orchestrator.states.get("p2")
  match (state1, state2) {
    (Some(s1), Some(s2)) => {
      inspect(s1.error_count, content="0")
      inspect(s2.error_count, content="0")
    }
    _ => fail("Expected states to exist")
  }
}

///|
test "FallbackOrchestrator cooldown allows recovery" {
  let provider = MockProvider::new("test")
  let config : FallbackConfig = {
    enabled: true,
    cooldown_ms: 1000L,
    max_retries: 1,
  }
  let orchestrator = FallbackOrchestrator::new(providers=[provider], config~)
  orchestrator.record_error("test", 1000L)
  inspect(orchestrator.is_provider_available("test", 1000L), content="false")
  inspect(orchestrator.is_provider_available("test", 2001L), content="true")
}

// =============================================================================
// Helper function for assertions
// =============================================================================

///|
fn assert_true(condition : Bool) -> Unit raise {
  if not(condition) {
    fail("Assertion failed: expected true")
  }
}

// =============================================================================
// Mock Provider for Testing
// =============================================================================

///|
struct MockProvider {
  provider_name : String
  is_available_flag : Bool
}

///|
fn MockProvider::new(name : String) -> MockProvider {
  { provider_name: name, is_available_flag: true }
}

///|
impl @interfaces.ModelProvider for MockProvider with name(self) {
  self.provider_name
}

///|
impl @interfaces.ModelProvider for MockProvider with is_available(self) {
  self.is_available_flag
}

///|
impl @interfaces.ModelProvider for MockProvider with invoke(
  _self,
  messages~,
  tools~,
  options~,
) {
  ignore(messages)
  ignore(tools)
  ignore(options)
  @types.ModelResponse::Text("Mock response")
}
