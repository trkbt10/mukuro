///|
/// Async Agent Loop Tests

///|
test "RetryConfig default values" {
  let config = @agent.RetryConfig::default()
  inspect(config.max_retries, content="3")
  inspect(config.initial_delay_ms, content="1000")
  inspect(config.max_delay_ms, content="60000")
  inspect(config.backoff_multiplier, content="2")
  inspect(config.retry_on_rate_limit, content="true")
}

///|
test "RetryConfig custom values" {
  let config : @agent.RetryConfig = {
    max_retries: 5,
    initial_delay_ms: 500,
    max_delay_ms: 30000,
    backoff_multiplier: 1.5,
    retry_on_rate_limit: false,
    retryable_status_codes: [429, 500],
  }
  inspect(config.max_retries, content="5")
  inspect(config.initial_delay_ms, content="500")
  inspect(config.max_delay_ms, content="30000")
  inspect(config.backoff_multiplier, content="1.5")
  inspect(config.retry_on_rate_limit, content="false")
  inspect(config.retryable_status_codes.length(), content="2")
}

///|
test "calculate_backoff_delay basic" {
  let delay0 = @agent.calculate_backoff_delay(0, 1000, 60000, 2.0)
  let delay1 = @agent.calculate_backoff_delay(1, 1000, 60000, 2.0)
  let delay2 = @agent.calculate_backoff_delay(2, 1000, 60000, 2.0)
  inspect(delay0, content="1000")
  inspect(delay1, content="2000")
  inspect(delay2, content="4000")
}

///|
test "calculate_backoff_delay respects max" {
  let delay = @agent.calculate_backoff_delay(10, 1000, 60000, 2.0)
  inspect(delay, content="60000")
}

///|
test "AgentLoopOptions default values" {
  let options = @agent.AgentLoopOptions::default()
  inspect(options.max_iterations, content="10")
  inspect(options.timeout_ms, content="120000")
}

///|
test "AgentLoopError variants" {
  let error1 : @agent.AgentLoopError = @agent.AgentLoopError::MaxIterationsReached(
    10,
  )
  let error2 : @agent.AgentLoopError = @agent.AgentLoopError::ModelCallFailed(
    "test error",
  )
  let error3 : @agent.AgentLoopError = @agent.AgentLoopError::SessionError(
    "session error",
  )
  ignore(error1)
  ignore(error2)
  ignore(error3)
}
