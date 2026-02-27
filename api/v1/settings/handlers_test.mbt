///|
/// Settings Handlers Tests

///|
fn make_ctx(
  meth : String,
  path : String,
  body : String,
) -> @api.ApiRequestContext {
  let headers : Map[String, String] = {}
  headers["x-mukuro-role"] = "admin"
  @api.ApiRequestContext::new(meth~, path~, headers~, body~)
}

///|
fn make_test_config() -> @types.MukuroConfig {
  {
    agent: @types.AgentConfig::default(),
    providers: [],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
}

// =============================================================================
// SettingsState Tests
// =============================================================================

///|
test "SettingsState new creates empty state" {
  let state = SettingsState::new()
  assert_true(state.get_config() is None)
}

///|
test "SettingsState init sets config" {
  let state = SettingsState::new()
  let config = make_test_config()
  state.init(config, "/tmp/config.json")
  assert_true(state.get_config() is Some(_))
}

///|
test "SettingsState update_config updates config" {
  let state = SettingsState::new()
  let config1 = make_test_config()
  state.init(config1, "/tmp/config.json")
  let config2 = make_test_config()
  state.update_config(config2)
  assert_true(state.get_config() is Some(_))
}

// =============================================================================
// GET /settings Tests
// =============================================================================

///|
test "handle_get_all returns 503 when not initialized" {
  let state = SettingsState::new()
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/settings", "")
  let resp = (handlers.get_all.0)(ctx)
  assert_eq(resp.status, 503)
}

///|
test "handle_get_all returns 200 when initialized" {
  let state = SettingsState::new()
  state.init(make_test_config(), "/tmp/config.json")
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/settings", "")
  let resp = (handlers.get_all.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("data"))
}

// =============================================================================
// GET /settings/retry Tests
// =============================================================================

///|
test "handle_get_retry returns retry config" {
  let state = SettingsState::new()
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/settings/retry", "")
  let resp = (handlers.get_retry.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("max_retries"))
}

// =============================================================================
// PUT /settings/retry Tests
// =============================================================================

///|
test "handle_update_retry updates max_retries" {
  let state = SettingsState::new()
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/settings/retry", "{\"max_retries\": 5}")
  let resp = (handlers.update_retry.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.retry_config.max_retries, 5)
}

///|
test "handle_update_retry updates multiple fields" {
  let state = SettingsState::new()
  let handlers = create_settings_handlers(state)
  let body = "{\"max_retries\": 3, \"initial_backoff_ms\": 500, \"max_backoff_ms\": 5000}"
  let ctx = make_ctx("PUT", "/api/v1/settings/retry", body)
  let resp = (handlers.update_retry.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.retry_config.max_retries, 3)
  assert_eq(state.retry_config.initial_backoff_ms, 500)
  assert_eq(state.retry_config.max_backoff_ms, 5000)
}

///|
test "handle_update_retry returns error for invalid JSON" {
  let state = SettingsState::new()
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/settings/retry", "invalid")
  let resp = (handlers.update_retry.0)(ctx)
  assert_eq(resp.status, 400)
}

// =============================================================================
// GET /settings/agent Tests
// =============================================================================

///|
test "handle_get_agent returns 503 when not initialized" {
  let state = SettingsState::new()
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/settings/agent", "")
  let resp = (handlers.get_agent.0)(ctx)
  assert_eq(resp.status, 503)
}

///|
test "handle_get_agent returns agent config when initialized" {
  let state = SettingsState::new()
  state.init(make_test_config(), "/tmp/config.json")
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/settings/agent", "")
  let resp = (handlers.get_agent.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("max_iterations"))
}

// =============================================================================
// GET /settings/model Tests
// =============================================================================

///|
test "handle_get_model returns 503 when not initialized" {
  let state = SettingsState::new()
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/settings/model", "")
  let resp = (handlers.get_model.0)(ctx)
  assert_eq(resp.status, 503)
}

///|
test "handle_get_model returns model config when initialized" {
  let state = SettingsState::new()
  state.init(make_test_config(), "/tmp/config.json")
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/settings/model", "")
  let resp = (handlers.get_model.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("model_name"))
}

// =============================================================================
// GET /settings/providers Tests
// =============================================================================

///|
test "handle_list_providers returns 503 when not initialized" {
  let state = SettingsState::new()
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/settings/providers", "")
  let resp = (handlers.list_providers.0)(ctx)
  assert_eq(resp.status, 503)
}

///|
test "handle_list_providers returns providers when initialized" {
  let state = SettingsState::new()
  state.init(make_test_config(), "/tmp/config.json")
  let handlers = create_settings_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/settings/providers", "")
  let resp = (handlers.list_providers.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("data"))
}
