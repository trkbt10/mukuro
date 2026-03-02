///|
/// Tool Handlers Tests

///|
fn make_ctx(
  meth : String,
  path : String,
  body : String,
) -> @api.ApiRequestContext {
  @api.ApiRequestContext::new(meth~, path~, headers={}, body~)
}

///|
fn make_tool_state() -> @interfaces.ToolState {
  @interfaces.ToolState::builtin(
    id="test",
    name="test_tool",
    description="Test tool",
    parameters=Json::object({}),
  )
}

///|
fn make_disabled_tool_state() -> @interfaces.ToolState {
  {
    ..make_tool_state(),
    enabled: false,
    status: @interfaces.ToolStatus::Disabled,
  }
}

// =============================================================================
// Tool List Tests
// =============================================================================

///|
test "list tools returns empty array when no tools" {
  let state = ToolManagerState::new()
  let ctx = make_ctx("GET", "/api/v1/tools", "")
  let resp = handle_list(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("data"))
  assert_true(resp.body.contains("stats"))
}

///|
test "list tools returns registered tools" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_tool_state())
  let ctx = make_ctx("GET", "/api/v1/tools", "")
  let resp = handle_list(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("test_tool"))
}

// =============================================================================
// Tool Get Tests
// =============================================================================

///|
test "get tool returns 400 when id missing" {
  let state = ToolManagerState::new()
  let ctx = make_ctx("GET", "/api/v1/tools", "")
  let resp = handle_get(state, ctx)
  assert_eq(resp.status, 400)
  assert_true(resp.body.contains("bad_request"))
}

///|
test "get tool returns 404 when not found" {
  let state = ToolManagerState::new()
  let ctx = make_ctx("GET", "/api/v1/tools/unknown", "")
  let resp = handle_get(state, ctx)
  assert_eq(resp.status, 404)
  assert_true(resp.body.contains("not_found"))
}

///|
test "get tool returns tool details" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_tool_state())
  let ctx = make_ctx("GET", "/api/v1/tools/test", "")
  let resp = handle_get(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("test_tool"))
}

// =============================================================================
// Tool Enable/Disable Tests
// =============================================================================

///|
test "enable tool updates enabled status" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_disabled_tool_state())
  let ctx = make_ctx("PUT", "/api/v1/tools/test/enable", "")
  let resp = handle_enable(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("enabled"))
  match state.get_tool("test") {
    Some(t) => assert_true(t.enabled)
    None => panic()
  }
}

///|
test "disable tool updates enabled status" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_tool_state())
  let ctx = make_ctx("PUT", "/api/v1/tools/test/disable", "")
  let resp = handle_disable(state, ctx)
  assert_eq(resp.status, 200)
  match state.get_tool("test") {
    Some(t) => assert_false(t.enabled)
    None => panic()
  }
}

// =============================================================================
// Tool Remove Tests
// =============================================================================

///|
test "remove tool returns 403 for builtin tool" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_tool_state())
  let ctx = make_ctx("DELETE", "/api/v1/tools/test", "")
  let resp = handle_remove(state, ctx)
  assert_eq(resp.status, 403)
  assert_true(resp.body.contains("forbidden"))
}

///|
test "remove tool succeeds for user-defined tool" {
  let state = ToolManagerState::new()
  let tool = @interfaces.ToolState::user_defined(
    id="user",
    name="user_tool",
    description="User tool",
    parameters=Json::object({}),
  )
  state.set_tool("user", tool)
  let ctx = make_ctx("DELETE", "/api/v1/tools/user", "")
  let resp = handle_remove(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("removed"))
  assert_true(state.get_tool("user") is None)
}

// =============================================================================
// Tool Actions Tests
// =============================================================================

///|
test "list actions returns empty for tool with no actions" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_tool_state())
  let ctx = make_ctx("GET", "/api/v1/tools/test/actions", "")
  let resp = handle_list_actions(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("actions"))
  assert_true(resp.body.contains("[]"))
}

///|
test "list actions returns registered actions" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_tool_state())
  state.register_action(
    "test",
    "echo",
    ToolActionHandler(fn(_params) { @api.json_response(200, { "echo": true }) }),
  )
  let ctx = make_ctx("GET", "/api/v1/tools/test/actions", "")
  let resp = handle_list_actions(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("echo"))
}

///|
test "invoke action returns 404 for unknown action" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_tool_state())
  let ctx = make_ctx("POST", "/api/v1/tools/test/actions/unknown", "{}")
  let resp = handle_invoke_action(state, ctx)
  assert_eq(resp.status, 404)
  assert_true(resp.body.contains("action_not_found"))
}

///|
test "invoke action executes handler" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_tool_state())
  state.register_action(
    "test",
    "greet",
    ToolActionHandler(fn(params) {
      let name = match params {
        { "name": String(n), .. } => n
        _ => "World"
      }
      @api.json_response(200, { "greeting": "Hello, \{name}!" })
    }),
  )
  let ctx = make_ctx(
    "POST", "/api/v1/tools/test/actions/greet", "{\"name\":\"Alice\"}",
  )
  let resp = handle_invoke_action(state, ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("Hello, Alice!"))
}

///|
test "invoke action returns 400 for disabled tool" {
  let state = ToolManagerState::new()
  state.set_tool("test", make_disabled_tool_state())
  state.register_action(
    "test",
    "echo",
    ToolActionHandler(fn(_params) { @api.json_response(200, { "ok": true }) }),
  )
  let ctx = make_ctx("POST", "/api/v1/tools/test/actions/echo", "{}")
  let resp = handle_invoke_action(state, ctx)
  assert_eq(resp.status, 400)
  assert_true(resp.body.contains("tool_disabled"))
}
