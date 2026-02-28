///|
/// Plugin Handlers Tests

///|
fn make_ctx(
  meth : String,
  path : String,
  body : String,
) -> @api.ApiRequestContext {
  @api.ApiRequestContext::new(
    meth~,
    path~,
    headers={},
    body~,
    role=@api.ApiRole::Admin,
  )
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
  let plugin : @interfaces.PluginState = {
    ..make_test_plugin_state("test"),
    enabled: false,
  }
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
  let plugin : @interfaces.PluginState = {
    ..make_test_plugin_state("test"),
    enabled: true,
  }
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

// =============================================================================
// Plugin Actions (RPC) Tests
// =============================================================================

///|
test "register_action and list_actions" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  state.register_action("test", "hello", fn(_params) {
    @api.json_response(200, { "msg": "hello" })
  })
  state.register_action("test", "bye", fn(_params) {
    @api.json_response(200, { "msg": "bye" })
  })
  let actions = state.list_actions("test")
  assert_eq(actions.length(), 2)
  assert_true(actions.contains("hello"))
  assert_true(actions.contains("bye"))
}

///|
test "list_actions returns empty for plugin with no actions" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  let actions = state.list_actions("test")
  assert_eq(actions.length(), 0)
}

///|
test "invoke_action calls registered handler" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  state.register_action("test", "greet", fn(params) {
    let name = match params {
      { "name": String(n), .. } => n
      _ => "world"
    }
    @api.json_response(200, { "greeting": "hello \{name}" })
  })
  match state.invoke_action("test", "greet", { "name": "Alice" }) {
    Some(resp) => {
      assert_eq(resp.status, 200)
      assert_true(resp.body.contains("Alice"))
    }
    None => fail("Expected action result")
  }
}

///|
test "invoke_action returns None for unknown action" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  assert_true(state.invoke_action("test", "missing", {}) is None)
}

///|
test "invoke_action returns None for unknown plugin" {
  let state = PluginManagerState::new()
  assert_true(state.invoke_action("unknown", "action", {}) is None)
}

///|
test "handle_list_actions returns action names" {
  let state = PluginManagerState::new()
  state.set_plugin("myplugin", make_test_plugin_state("myplugin"))
  state.register_action("myplugin", "do_stuff", fn(_params) {
    @api.json_response(200, { "ok": true })
  })
  let ctx = make_ctx("GET", "/api/v1/plugins/myplugin/actions", "")
  let resp = handle_list_actions(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("do_stuff"))
  assert_true(resp.body.contains("myplugin"))
}

///|
test "handle_list_actions returns 404 for unknown plugin" {
  let state = PluginManagerState::new()
  let ctx = make_ctx("GET", "/api/v1/plugins/unknown/actions", "")
  let resp = handle_list_actions(state, ctx)
  assert_eq(resp.status, 404)
}

///|
test "handle_invoke_action calls action and returns result" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  state.register_action("test", "echo", fn(params) {
    @api.json_response(200, { "echo": params })
  })
  let ctx = make_ctx(
    "POST",
    "/api/v1/plugins/test/actions/echo",
    "{\"msg\":\"hi\"}",
  )
  let resp = handle_invoke_action(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("hi"))
}

///|
test "handle_invoke_action returns 404 for unknown plugin" {
  let state = PluginManagerState::new()
  let ctx = make_ctx(
    "POST",
    "/api/v1/plugins/unknown/actions/test",
    "{}",
  )
  let resp = handle_invoke_action(state, ctx)
  assert_eq(resp.status, 404)
}

///|
test "handle_invoke_action returns 404 for unknown action" {
  let state = PluginManagerState::new()
  state.set_plugin("test", make_test_plugin_state("test"))
  let ctx = make_ctx(
    "POST",
    "/api/v1/plugins/test/actions/missing",
    "{}",
  )
  let resp = handle_invoke_action(state, ctx)
  assert_eq(resp.status, 404)
  assert_true(resp.body.contains("action_not_found"))
}

///|
test "handle_invoke_action returns 400 for disabled plugin" {
  let state = PluginManagerState::new()
  let plugin : @interfaces.PluginState = {
    ..make_test_plugin_state("test"),
    enabled: false,
  }
  state.set_plugin("test", plugin)
  state.register_action("test", "echo", fn(_params) {
    @api.json_response(200, { "ok": true })
  })
  let ctx = make_ctx(
    "POST",
    "/api/v1/plugins/test/actions/echo",
    "{}",
  )
  let resp = handle_invoke_action(state, ctx)
  assert_eq(resp.status, 400)
  assert_true(resp.body.contains("plugin_disabled"))
}
