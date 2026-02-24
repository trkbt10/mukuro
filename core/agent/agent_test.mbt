///|
/// Tests for agent state and loop context
test "AgentState::default is Idle" {
  let state : @agent.AgentState = @agent.AgentState::Idle
  inspect(state, content="Idle")
}

///|
test "AgentState::Show for all variants" {
  inspect(@agent.AgentState::Idle, content="Idle")
  inspect(@agent.AgentState::WaitingForModel, content="WaitingForModel")
  inspect(@agent.AgentState::SendingResponse, content="SendingResponse")
  inspect(
    @agent.AgentState::ExecutingTool(tool_name="test_tool", call_id="call_1"),
    content="ExecutingTool(test_tool, call_1)",
  )
  inspect(@agent.AgentState::Error("test error"), content="Error(test error)")
  inspect(@agent.AgentState::Completed, content="Completed")
}

///|
test "AgentLoopContext::new creates valid context" {
  let ctx = @agent.AgentLoopContext::new()
  inspect(ctx.state, content="Idle")
  inspect(ctx.iteration, content="0")
  inspect(ctx.messages.length(), content="0")
  inspect(ctx.tool_call_history.length(), content="0")
}

///|
test "AgentLoopContext::set_state updates state" {
  let ctx = @agent.AgentLoopContext::new()
  ctx.set_state(@agent.AgentState::WaitingForModel)
  inspect(ctx.state, content="WaitingForModel")
  ctx.set_state(
    @agent.AgentState::ExecutingTool(tool_name="my_tool", call_id="call_1"),
  )
  inspect(ctx.state, content="ExecutingTool(my_tool, call_1)")
}

///|
test "AgentLoopContext::increment_iteration" {
  let ctx = @agent.AgentLoopContext::new()
  inspect(ctx.iteration, content="0")
  ctx.increment_iteration()
  inspect(ctx.iteration, content="1")
  ctx.increment_iteration()
  ctx.increment_iteration()
  inspect(ctx.iteration, content="3")
}

///|
test "AgentLoopContext::add_message" {
  let ctx = @agent.AgentLoopContext::new()
  let msg1 = @types.ModelMessage::User(content="Hello", name=None)
  ctx.add_message(msg1)
  inspect(ctx.messages.length(), content="1")
  let msg2 = @types.ModelMessage::Assistant(content="Hi there", tool_calls=None)
  ctx.add_message(msg2)
  inspect(ctx.messages.length(), content="2")
}

///|
test "AgentLoopContext::record_tool_call" {
  let ctx = @agent.AgentLoopContext::new()
  let call = @types.ToolCallRequest::new(
    id="call_1",
    name="test_tool",
    arguments=Json::null(),
  )
  ctx.record_tool_call(call)
  inspect(ctx.tool_call_history.length(), content="1")
}

///|
test "AgentLoopContext::is_max_iterations" {
  let ctx = @agent.AgentLoopContext::new()

  // Initially at 0, max 5
  inspect(ctx.is_max_iterations(5), content="false")

  // Increment to 5
  for _ in 0..<5 {
    ctx.increment_iteration()
  }
  inspect(ctx.is_max_iterations(5), content="true")

  // Still under max 10
  inspect(ctx.is_max_iterations(10), content="false")
}

///|
test "AgentLoopContext::is_error" {
  let ctx = @agent.AgentLoopContext::new()

  // Initially Idle - not an error
  inspect(ctx.is_error(), content="false")

  // WaitingForModel - not an error
  ctx.set_state(@agent.AgentState::WaitingForModel)
  inspect(ctx.is_error(), content="false")

  // Error state
  ctx.set_state(@agent.AgentState::Error("something went wrong"))
  inspect(ctx.is_error(), content="true")
}

///|
test "AgentLoopContext::is_completed" {
  let ctx = @agent.AgentLoopContext::new()

  // Initially Idle - not completed
  inspect(ctx.is_completed(), content="false")

  // WaitingForModel - not completed
  ctx.set_state(@agent.AgentState::WaitingForModel)
  inspect(ctx.is_completed(), content="false")

  // Completed state
  ctx.set_state(@agent.AgentState::Completed)
  inspect(ctx.is_completed(), content="true")
}

// =============================================================================
// Retry Configuration Tests
// =============================================================================

///|
test "RetryConfig::default has reasonable values" {
  let config = @agent.RetryConfig::default()
  inspect(config.max_retries, content="3")
  inspect(config.initial_delay_ms, content="1000")
  inspect(config.max_delay_ms, content="60000")
  inspect(config.retry_on_rate_limit, content="true")
  assert_true(config.backoff_multiplier > 1.0)
}

///|
test "AgentLoopOptions::default includes retry config" {
  let options = @agent.AgentLoopOptions::default()
  inspect(options.retry_config.max_retries, content="3")
  inspect(options.retry_config.retry_on_rate_limit, content="true")
}

///|
test "calculate_backoff_delay computes correct values" {
  // attempt=0: initial_delay
  let delay0 = @agent.calculate_backoff_delay(0, 1000, 60000, 2.0)
  inspect(delay0, content="1000")

  // attempt=1: 1000 * 2 = 2000
  let delay1 = @agent.calculate_backoff_delay(1, 1000, 60000, 2.0)
  inspect(delay1, content="2000")

  // attempt=2: 1000 * 2 * 2 = 4000
  let delay2 = @agent.calculate_backoff_delay(2, 1000, 60000, 2.0)
  inspect(delay2, content="4000")

  // attempt=3: 1000 * 2 * 2 * 2 = 8000
  let delay3 = @agent.calculate_backoff_delay(3, 1000, 60000, 2.0)
  inspect(delay3, content="8000")
}

///|
test "calculate_backoff_delay respects max_delay_ms" {
  // With max_delay_ms=5000, should cap at 5000
  let delay = @agent.calculate_backoff_delay(10, 1000, 5000, 2.0)
  inspect(delay, content="5000")
}

///|
test "calculate_backoff_delay handles multiplier 1.5" {
  // attempt=1: 1000 * 1.5 = 1500
  let delay1 = @agent.calculate_backoff_delay(1, 1000, 60000, 1.5)
  inspect(delay1, content="1500")

  // attempt=2: 1000 * 1.5 * 1.5 = 2250
  let delay2 = @agent.calculate_backoff_delay(2, 1000, 60000, 1.5)
  inspect(delay2, content="2250")
}

///|
test "RateLimitExceeded error contains retry info" {
  let err : @agent.AgentLoopError = @agent.AgentLoopError::RateLimitExceeded(
    retry_count=3,
    last_retry_after=60,
  )
  match err {
    @agent.AgentLoopError::RateLimitExceeded(retry_count~, last_retry_after~) => {
      inspect(retry_count, content="3")
      inspect(last_retry_after, content="60")
    }
    _ => fail("Expected RateLimitExceeded")
  }
}

///|
test "RetryConfig with different settings" {
  let config : @agent.RetryConfig = {
    max_retries: 5,
    initial_delay_ms: 500,
    max_delay_ms: 30000,
    backoff_multiplier: 1.5,
    retry_on_rate_limit: false,
    retryable_status_codes: [429, 503],
  }
  inspect(config.max_retries, content="5")
  inspect(config.initial_delay_ms, content="500")
  inspect(config.retry_on_rate_limit, content="false")
  inspect(config.retryable_status_codes.length(), content="2")
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
