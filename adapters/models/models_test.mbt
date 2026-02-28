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

///|
test "AnthropicProvider::with_thinking includes thinking config" {
  let thinking_config : @types.ThinkingConfig = {
    enabled: true,
    level: @types.ThinkingLevel::Medium,
    budget_tokens: Some(10000),
  }
  let provider = AnthropicProvider::new({
    api_key: "test_key",
    base_url: "https://api.anthropic.com",
    api_version: "2023-06-01",
    timeout_ms: 60000,
    thinking: Some(thinking_config),
  })
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Think about this", name=None),
  ]
  let options = @types.ModelOptions::default()
  let request = provider.build_request(messages, [], options)
  match request {
    { "thinking": Object(thinking_obj), .. } => {
      match thinking_obj.get("type") {
        Some(String(t)) => inspect(t, content="enabled")
        _ => fail("Expected thinking type")
      }
      match thinking_obj.get("budget_tokens") {
        Some(Number(budget, ..)) =>
          assert_true(budget > 9999.0 && budget < 10001.0)
        _ => fail("Expected budget_tokens")
      }
    }
    _ => fail("Expected thinking in request")
  }
}

///|
test "AnthropicProvider::build_request without thinking has no thinking field" {
  let provider = AnthropicProvider::from_api_key("test_key")
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content="Hi", name=None),
  ]
  let options = @types.ModelOptions::default()
  let request = provider.build_request(messages, [], options)
  match request {
    Object(obj) =>
      match obj.get("thinking") {
        Some(_) => fail("Expected no thinking field")
        None => ()
      }
    _ => fail("Expected object")
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
