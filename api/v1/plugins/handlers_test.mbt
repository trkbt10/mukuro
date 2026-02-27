///|
/// Plugin Handlers Tests

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
fn make_test_plugin_state(id : String) -> @interfaces.PluginState {
  @interfaces.PluginState::default(id~)
}

// =============================================================================
// PluginManagerState Tests
// =============================================================================

///|
test "PluginManagerState new creates empty state" {
  let state = PluginManagerState::new()
  assert_true(state.get_plugin("test") is None)
}

///|
test "PluginManagerState set_plugin and get_plugin" {
  let state = PluginManagerState::new()
  let plugin = make_test_plugin_state("test-plugin")
  state.set_plugin("test-plugin", plugin)
  assert_true(state.get_plugin("test-plugin") is Some(_))
}

///|
test "PluginManagerState remove_plugin" {
  let state = PluginManagerState::new()
  let plugin = make_test_plugin_state("test-plugin")
  state.set_plugin("test-plugin", plugin)
  state.remove_plugin("test-plugin")
  assert_true(state.get_plugin("test-plugin") is None)
}

///|
test "PluginManagerState get_settings returns None for unknown plugin" {
  let state = PluginManagerState::new()
  assert_true(state.get_settings("unknown") is None)
}

///|
test "PluginManagerState set_settings and get_settings" {
  let state = PluginManagerState::new()
  let settings : Map[String, Json] = {}
  settings["key"] = "value"
  state.set_settings("test-plugin", settings)
  match state.get_settings("test-plugin") {
    Some(s) => assert_true(s.contains("key"))
    None => fail("Expected settings to exist")
  }
}

// =============================================================================
// GET /plugins Tests
// =============================================================================

///|
test "handle_list returns empty array when no plugins" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/plugins", "")
  let resp = (handlers.list.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("data"))
}

///|
test "handle_list returns plugins" {
  let state = PluginManagerState::new()
  state.set_plugin("plugin-a", make_test_plugin_state("plugin-a"))
  state.set_plugin("plugin-b", make_test_plugin_state("plugin-b"))
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/plugins", "")
  let resp = (handlers.list.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("plugin-a"))
  assert_true(resp.body.contains("plugin-b"))
}

// =============================================================================
// GET /plugins/{id} Tests
// =============================================================================

///|
test "handle_get returns 404 for unknown plugin" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/plugins/unknown", "")
  let resp = (handlers.get.0)(ctx)
  assert_eq(resp.status, 404)
}

///|
test "handle_get returns plugin details" {
  let state = PluginManagerState::new()
  state.set_plugin("my-plugin", make_test_plugin_state("my-plugin"))
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/plugins/my-plugin", "")
  let resp = (handlers.get.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("my-plugin"))
}

// =============================================================================
// POST /plugins Tests
// =============================================================================

///|
test "handle_add creates new plugin" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let body = "{\"manifest_path\": \"/path/to/plugin/manifest.json\"}"
  let ctx = make_ctx("POST", "/api/v1/plugins", body)
  let resp = (handlers.add.0)(ctx)
  assert_eq(resp.status, 201)
  assert_true(resp.body.contains("manifest"))
}

///|
test "handle_add returns 409 for duplicate plugin" {
  let state = PluginManagerState::new()
  state.set_plugin("manifest", make_test_plugin_state("manifest"))
  let handlers = create_plugin_handlers(state)
  let body = "{\"manifest_path\": \"/path/to/manifest.json\"}"
  let ctx = make_ctx("POST", "/api/v1/plugins", body)
  let resp = (handlers.add.0)(ctx)
  assert_eq(resp.status, 409)
}

///|
test "handle_add returns 400 for invalid JSON" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("POST", "/api/v1/plugins", "invalid")
  let resp = (handlers.add.0)(ctx)
  assert_eq(resp.status, 400)
}

// =============================================================================
// DELETE /plugins/{id} Tests
// =============================================================================

///|
test "handle_remove deletes plugin" {
  let state = PluginManagerState::new()
  state.set_plugin("to-delete", make_test_plugin_state("to-delete"))
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("DELETE", "/api/v1/plugins/to-delete", "")
  let resp = (handlers.remove.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(state.get_plugin("to-delete") is None)
}

///|
test "handle_remove returns 404 for unknown plugin" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("DELETE", "/api/v1/plugins/unknown", "")
  let resp = (handlers.remove.0)(ctx)
  assert_eq(resp.status, 404)
}

// =============================================================================
// PUT /plugins/{id}/enable Tests
// =============================================================================

///|
test "handle_enable enables plugin" {
  let state = PluginManagerState::new()
  let plugin : @interfaces.PluginState = { ..make_test_plugin_state("test"), enabled: false }
  state.set_plugin("test", plugin)
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/plugins/test/enable", "")
  let resp = (handlers.enable.0)(ctx)
  assert_eq(resp.status, 200)
  match state.get_plugin("test") {
    Some(p) => assert_true(p.enabled)
    None => fail("Plugin should exist")
  }
}

///|
test "handle_enable returns 404 for unknown plugin" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/plugins/unknown/enable", "")
  let resp = (handlers.enable.0)(ctx)
  assert_eq(resp.status, 404)
}

// =============================================================================
// PUT /plugins/{id}/disable Tests
// =============================================================================

///|
test "handle_disable disables plugin" {
  let state = PluginManagerState::new()
  let plugin : @interfaces.PluginState = { ..make_test_plugin_state("test"), enabled: true }
  state.set_plugin("test", plugin)
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/plugins/test/disable", "")
  let resp = (handlers.disable.0)(ctx)
  assert_eq(resp.status, 200)
  match state.get_plugin("test") {
    Some(p) => assert_false(p.enabled)
    None => fail("Plugin should exist")
  }
}

///|
test "handle_disable returns 404 for unknown plugin" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/plugins/unknown/disable", "")
  let resp = (handlers.disable.0)(ctx)
  assert_eq(resp.status, 404)
}

// =============================================================================
// POST /plugins/{id}/reload Tests
// =============================================================================

///|
test "handle_reload reloads plugin" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("POST", "/api/v1/plugins/test/reload", "")
  let resp = (handlers.reload.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("reloaded"))
}

///|
test "handle_reload returns 404 for unknown plugin" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("POST", "/api/v1/plugins/unknown/reload", "")
  let resp = (handlers.reload.0)(ctx)
  assert_eq(resp.status, 404)
}

// =============================================================================
// POST /plugins/upload Tests
// =============================================================================

///|
test "handle_upload returns 501 not implemented" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("POST", "/api/v1/plugins/upload", "")
  let resp = (handlers.upload.0)(ctx)
  assert_eq(resp.status, 501)
}

// =============================================================================
// GET /plugins/{id}/settings Tests
// =============================================================================

///|
test "handle_get_settings returns empty settings" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/plugins/test/settings", "")
  let resp = (handlers.get_settings.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("settings"))
}

///|
test "handle_get_settings returns 404 for unknown plugin" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("GET", "/api/v1/plugins/unknown/settings", "")
  let resp = (handlers.get_settings.0)(ctx)
  assert_eq(resp.status, 404)
}

// =============================================================================
// PUT /plugins/{id}/settings Tests
// =============================================================================

///|
test "handle_update_settings updates settings" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  let handlers = create_plugin_handlers(state)
  let body = "{\"option\": \"value\"}"
  let ctx = make_ctx("PUT", "/api/v1/plugins/test/settings", body)
  let resp = (handlers.update_settings.0)(ctx)
  assert_eq(resp.status, 200)
  match state.get_settings("test") {
    Some(s) => assert_true(s.contains("option"))
    None => fail("Settings should exist")
  }
}

///|
test "handle_update_settings returns 404 for unknown plugin" {
  let state = PluginManagerState::new()
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/plugins/unknown/settings", "{}")
  let resp = (handlers.update_settings.0)(ctx)
  assert_eq(resp.status, 404)
}

///|
test "handle_update_settings returns 400 for invalid JSON" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  let handlers = create_plugin_handlers(state)
  let ctx = make_ctx("PUT", "/api/v1/plugins/test/settings", "invalid")
  let resp = (handlers.update_settings.0)(ctx)
  assert_eq(resp.status, 400)
}
