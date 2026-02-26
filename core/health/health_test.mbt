///|
/// Health Check Tests

///|
/// テスト用モッククロック
struct MockClock {
  current_time : Int64
}

///|
fn MockClock::new(time : Int64) -> MockClock {
  { current_time: time }
}

///|
pub impl @interfaces.Clock for MockClock with now_ms(self) {
  self.current_time
}

///|
pub impl @interfaces.Clock for MockClock with now_seconds(self) {
  self.current_time / 1000L
}

///|
test "HealthStatus::is_healthy returns true for Healthy" {
  let status = @interfaces.HealthStatus::Healthy
  inspect(status.is_healthy(), content="true")
  inspect(status.is_unhealthy(), content="false")
}

///|
test "HealthStatus::is_unhealthy returns true for Unhealthy" {
  let status = @interfaces.HealthStatus::Unhealthy("test error")
  inspect(status.is_healthy(), content="false")
  inspect(status.is_unhealthy(), content="true")
}

///|
test "HealthStatus::to_string formats correctly" {
  let healthy = @interfaces.HealthStatus::Healthy
  let degraded = @interfaces.HealthStatus::Degraded("slow response")
  let unhealthy = @interfaces.HealthStatus::Unhealthy("connection failed")
  inspect(healthy.to_string(), content="healthy")
  inspect(degraded.to_string(), content="degraded: slow response")
  inspect(unhealthy.to_string(), content="unhealthy: connection failed")
}

///|
test "HealthCheck::healthy creates healthy check" {
  let check = @interfaces.HealthCheck::healthy(
    name="test",
    latency_ms=Some(10L),
    last_check=1000L,
  )
  inspect(check.name, content="test")
  inspect(check.status.is_healthy(), content="true")
  inspect(check.latency_ms, content="Some(10)")
}

///|
test "HealthCheck::unhealthy creates unhealthy check" {
  let check = @interfaces.HealthCheck::unhealthy(
    name="db",
    message="connection refused",
    latency_ms=None,
    last_check=2000L,
  )
  inspect(check.name, content="db")
  inspect(check.status.is_unhealthy(), content="true")
}

///|
test "SystemHealth::new calculates overall healthy status" {
  let checks : Array[@interfaces.HealthCheck] = [
    @interfaces.HealthCheck::healthy(
      name="api",
      latency_ms=Some(5L),
      last_check=1000L,
    ),
    @interfaces.HealthCheck::healthy(
      name="db",
      latency_ms=Some(10L),
      last_check=1000L,
    ),
  ]
  let health = @interfaces.SystemHealth::new(
    checks~,
    uptime_ms=60000L,
    version="1.0.0",
    checked_at=1000L,
  )
  inspect(health.overall.is_healthy(), content="true")
}

///|
test "SystemHealth::new calculates overall unhealthy status" {
  let checks : Array[@interfaces.HealthCheck] = [
    @interfaces.HealthCheck::healthy(
      name="api",
      latency_ms=Some(5L),
      last_check=1000L,
    ),
    @interfaces.HealthCheck::unhealthy(
      name="db",
      message="down",
      latency_ms=None,
      last_check=1000L,
    ),
  ]
  let health = @interfaces.SystemHealth::new(
    checks~,
    uptime_ms=60000L,
    version="1.0.0",
    checked_at=1000L,
  )
  inspect(health.overall.is_unhealthy(), content="true")
}

///|
async test "AlwaysHealthyChecker returns healthy status" {
  let checker = AlwaysHealthyChecker::new(name="liveness")
  inspect(checker.name(), content="liveness")
  let check = checker.check()
  inspect(check.status.is_healthy(), content="true")
}

///|
test "HealthAggregatorImpl registers and lists checkers" {
  let clock = MockClock::new(1000L)
  let aggregator = HealthAggregatorImpl::with_defaults(clock~)
  let checker1 = AlwaysHealthyChecker::new(name="check1")
  let checker2 = AlwaysHealthyChecker::new(name="check2")
  aggregator.register(checker=checker1)
  aggregator.register(checker=checker2)
  let names = aggregator.list_checkers()
  inspect(names.length(), content="2")
}

///|
async test "HealthAggregatorImpl::check_all returns system health" {
  let clock = MockClock::new(1000L)
  let aggregator = HealthAggregatorImpl::with_defaults(clock~)
  let checker = AlwaysHealthyChecker::new(name="test")
  aggregator.register(checker~)
  let health = aggregator.check_all()
  inspect(health.checks.length(), content="1")
  inspect(health.overall.is_healthy(), content="true")
  inspect(health.version, content="0.1.0")
}

///|
test "HealthAggregatorImpl::unregister removes checker" {
  let clock = MockClock::new(1000L)
  let aggregator = HealthAggregatorImpl::with_defaults(clock~)
  let checker = AlwaysHealthyChecker::new(name="removable")
  aggregator.register(checker~)
  inspect(aggregator.list_checkers().length(), content="1")
  aggregator.unregister(name="removable")
  inspect(aggregator.list_checkers().length(), content="0")
}

// get_check was removed from the HealthAggregator trait during async migration

///|
async test "CallbackHealthChecker uses provided function" {
  let checker = CallbackHealthChecker::new(name="custom", check_fn=fn() {
    @interfaces.HealthCheck::degraded(
      name="custom",
      message="high latency",
      latency_ms=Some(500L),
      last_check=0L,
    )
  })
  let check = checker.check()
  inspect(check.name, content="custom")
  match check.status {
    @interfaces.HealthStatus::Degraded(msg) =>
      inspect(msg, content="high latency")
    _ => fail("Expected Degraded status")
  }
}

///|
test "HealthEndpointConfig::default has correct values" {
  let config = @interfaces.HealthEndpointConfig::default()
  inspect(config.path, content="/health")
  inspect(config.require_auth, content="false")
  inspect(config.include_details, content="true")
  inspect(config.cache_seconds, content="5")
}

///|
test "HealthEndpointConfig::liveness has minimal config" {
  let config = @interfaces.HealthEndpointConfig::liveness()
  inspect(config.path, content="/health/live")
  inspect(config.include_details, content="false")
}

///|
test "HealthEndpointConfig::readiness has full config" {
  let config = @interfaces.HealthEndpointConfig::readiness()
  inspect(config.path, content="/health/ready")
  inspect(config.include_details, content="true")
}

///|
async test "MemoryHealthChecker::default has reasonable thresholds" {
  let checker = MemoryHealthChecker::default()
  inspect(checker.name(), content="memory")
  // スタブなので常に正常を返す
  let check = checker.check()
  inspect(check.status.is_healthy(), content="true")
}
