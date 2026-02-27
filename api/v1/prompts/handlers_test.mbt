///|
/// Prompt Handlers Tests

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
    agent: { ..@types.AgentConfig::default(), bootstrap: "Test bootstrap" },
    providers: [],
    fallback: @types.FallbackConfig::new(),
    channels: [],
  }
}

// =============================================================================
// PromptState Tests
// =============================================================================

///|
test "PromptState new creates default state" {
  let state = PromptState::new()
  assert_eq(state.bootstrap, "")
  assert_eq(state.system_prompt.content, "")
}

///|
test "PromptState from_config initializes bootstrap" {
  let state = PromptState::new()
  let config = make_test_config()
  state.from_config(config)
  assert_eq(state.bootstrap, "Test bootstrap")
}

// =============================================================================
// GET /prompts/system Tests
// =============================================================================

///|
test "handle_get_system returns system prompt" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/prompts/system", "")
  let resp = (handlers.get_system.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("content"))
  assert_true(resp.body.contains("mode"))
  assert_true(resp.body.contains("when"))
}

// =============================================================================
// PUT /prompts/system Tests
// =============================================================================

///|
test "handle_update_system updates content" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"content\": \"You are a helpful assistant.\"}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/system", body)
  let resp = (handlers.update_system.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.system_prompt.content, "You are a helpful assistant.")
}

///|
test "handle_update_system updates mode to replace" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"mode\": \"replace\"}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/system", body)
  let resp = (handlers.update_system.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.system_prompt.mode.to_string(), "replace")
}

///|
test "handle_update_system updates mode to append" {
  let state = PromptState::new()
  state.system_prompt = { ..state.system_prompt, mode: @types.SystemPromptMode::Replace }
  let handlers = create_prompt_handlers(state)
  let body = "{\"mode\": \"append\"}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/system", body)
  let resp = (handlers.update_system.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.system_prompt.mode.to_string(), "append")
}

///|
test "handle_update_system updates when to always" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"when\": \"always\"}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/system", body)
  let resp = (handlers.update_system.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.system_prompt.when.to_string(), "always")
}

///|
test "handle_update_system updates when to never" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"when\": \"never\"}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/system", body)
  let resp = (handlers.update_system.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.system_prompt.when.to_string(), "never")
}

///|
test "handle_update_system updates multiple fields" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"content\": \"New prompt\", \"mode\": \"replace\", \"when\": \"always\"}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/system", body)
  let resp = (handlers.update_system.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.system_prompt.content, "New prompt")
  assert_eq(state.system_prompt.mode.to_string(), "replace")
  assert_eq(state.system_prompt.when.to_string(), "always")
}

///|
test "handle_update_system returns 400 for invalid JSON" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/prompts/system", "invalid")
  let resp = (handlers.update_system.0)(ctx)
  assert_eq(resp.status, 400)
}

// =============================================================================
// GET /prompts/bootstrap Tests
// =============================================================================

///|
test "handle_get_bootstrap returns bootstrap prompt" {
  let state = PromptState::new()
  state.bootstrap = "Initial bootstrap"
  let handlers = create_prompt_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/prompts/bootstrap", "")
  let resp = (handlers.get_bootstrap.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("Initial bootstrap"))
}

// =============================================================================
// PUT /prompts/bootstrap Tests
// =============================================================================

///|
test "handle_update_bootstrap replaces bootstrap" {
  let state = PromptState::new()
  state.bootstrap = "Old bootstrap"
  let handlers = create_prompt_handlers(state)
  let body = "{\"content\": \"New bootstrap\"}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/bootstrap", body)
  let resp = (handlers.update_bootstrap.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.bootstrap, "New bootstrap")
}

///|
test "handle_update_bootstrap returns 400 for missing content" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"other\": \"field\"}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/bootstrap", body)
  let resp = (handlers.update_bootstrap.0)(ctx)
  assert_eq(resp.status, 400)
}

///|
test "handle_update_bootstrap returns 400 for invalid JSON" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/prompts/bootstrap", "invalid")
  let resp = (handlers.update_bootstrap.0)(ctx)
  assert_eq(resp.status, 400)
}

// =============================================================================
// POST /prompts/bootstrap/append Tests
// =============================================================================

///|
test "handle_append_bootstrap appends to empty bootstrap" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"content\": \"First line\"}"
  let ctx = make_ctx("POST", "/api/v1/prompts/bootstrap/append", body)
  let resp = (handlers.append_bootstrap.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.bootstrap, "First line")
}

///|
test "handle_append_bootstrap appends with newline" {
  let state = PromptState::new()
  state.bootstrap = "First line"
  let handlers = create_prompt_handlers(state)
  let body = "{\"content\": \"Second line\"}"
  let ctx = make_ctx("POST", "/api/v1/prompts/bootstrap/append", body)
  let resp = (handlers.append_bootstrap.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.bootstrap, "First line\nSecond line")
}

///|
test "handle_append_bootstrap returns 400 for missing content" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{}"
  let ctx = make_ctx("POST", "/api/v1/prompts/bootstrap/append", body)
  let resp = (handlers.append_bootstrap.0)(ctx)
  assert_eq(resp.status, 400)
}

// =============================================================================
// GET /prompts/channels/{name} Tests
// =============================================================================

///|
test "handle_get_channel returns default for unknown channel" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/prompts/channels/general", "")
  let resp = (handlers.get_channel.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("general"))
  assert_true(resp.body.contains("enabled"))
}

///|
test "handle_get_channel returns channel prompt" {
  let state = PromptState::new()
  state.channel_prompts["general"] = "Channel specific prompt"
  state.channel_enabled["general"] = true
  let handlers = create_prompt_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/prompts/channels/general", "")
  let resp = (handlers.get_channel.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("Channel specific prompt"))
}

// =============================================================================
// PUT /prompts/channels/{name} Tests
// =============================================================================

///|
test "handle_update_channel updates content" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"content\": \"New channel prompt\"}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/channels/general", body)
  let resp = (handlers.update_channel.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.channel_prompts["general"], "New channel prompt")
}

///|
test "handle_update_channel updates enabled flag" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"enabled\": false}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/channels/general", body)
  let resp = (handlers.update_channel.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.channel_enabled["general"], false)
}

///|
test "handle_update_channel updates both fields" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let body = "{\"content\": \"Updated\", \"enabled\": true}"
  let ctx = make_ctx("PUT", "/api/v1/prompts/channels/general", body)
  let resp = (handlers.update_channel.0)(ctx)
  assert_eq(resp.status, 200)
  assert_eq(state.channel_prompts["general"], "Updated")
  assert_eq(state.channel_enabled["general"], true)
}

///|
test "handle_update_channel returns 400 for invalid JSON" {
  let state = PromptState::new()
  let handlers = create_prompt_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/prompts/channels/general", "invalid")
  let resp = (handlers.update_channel.0)(ctx)
  assert_eq(resp.status, 400)
}
