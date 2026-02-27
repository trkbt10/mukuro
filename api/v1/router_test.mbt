///|
/// API Router Tests

///|
fn make_ctx(
  meth : String,
  path : String,
  role : String,
  body : String,
) -> ApiRequestContext {
  let headers : Map[String, String] = {}
  headers["x-mukuro-role"] = role
  ApiRequestContext::new(meth~, path~, headers~, body~)
}

///|
fn dummy_handler(_ctx : ApiRequestContext) -> ApiResponse {
  json_response(200, { "ok": true })
}

///|
fn make_router_with_handlers() -> ApiRouter {
  let plugin_handlers : PluginApiHandlers = {
    list: RouteHandler(dummy_handler),
    get: RouteHandler(dummy_handler),
    add: RouteHandler(dummy_handler),
    remove: RouteHandler(dummy_handler),
    enable: RouteHandler(dummy_handler),
    disable: RouteHandler(dummy_handler),
    reload: RouteHandler(dummy_handler),
    upload: RouteHandler(dummy_handler),
    get_settings: RouteHandler(dummy_handler),
    update_settings: RouteHandler(dummy_handler),
  }
  let prompt_handlers : PromptApiHandlers = {
    get_system: RouteHandler(dummy_handler),
    update_system: RouteHandler(dummy_handler),
    get_bootstrap: RouteHandler(dummy_handler),
    update_bootstrap: RouteHandler(dummy_handler),
    append_bootstrap: RouteHandler(dummy_handler),
    get_channel: RouteHandler(dummy_handler),
    update_channel: RouteHandler(dummy_handler),
    create_channel: RouteHandler(dummy_handler),
    delete_channel: RouteHandler(dummy_handler),
  }
  let settings_handlers : SettingsApiHandlers = {
    get_all: RouteHandler(dummy_handler),
    update_all: RouteHandler(dummy_handler),
    get_retry: RouteHandler(dummy_handler),
    update_retry: RouteHandler(dummy_handler),
    get_agent: RouteHandler(dummy_handler),
    update_agent: RouteHandler(dummy_handler),
    get_model: RouteHandler(dummy_handler),
    update_model: RouteHandler(dummy_handler),
    get_thinking: RouteHandler(dummy_handler),
    update_thinking: RouteHandler(dummy_handler),
    list_providers: RouteHandler(dummy_handler),
    update_provider: RouteHandler(dummy_handler),
  }
  {
    plugin_handlers: Some(plugin_handlers),
    prompt_handlers: Some(prompt_handlers),
    settings_handlers: Some(settings_handlers),
    config_handlers: None,
    provider_handlers: None,
  }
}

// =============================================================================
// Settings Routes
// =============================================================================

///|
test "router routes GET /api/v1/settings" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/settings", "viewer", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes PUT /api/v1/settings" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PUT", "/api/v1/settings", "admin", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes GET /api/v1/settings/retry" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/settings/retry", "viewer", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes PUT /api/v1/settings/retry" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PUT", "/api/v1/settings/retry", "operator", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

// =============================================================================
// Plugin Routes
// =============================================================================

///|
test "router routes GET /api/v1/plugins" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/plugins", "viewer", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes POST /api/v1/plugins" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("POST", "/api/v1/plugins", "admin", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes GET /api/v1/plugins/{id}" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/plugins/my-plugin", "viewer", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes DELETE /api/v1/plugins/{id}" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("DELETE", "/api/v1/plugins/my-plugin", "admin", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes PUT /api/v1/plugins/{id}/enable" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PUT", "/api/v1/plugins/my-plugin/enable", "operator", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes PUT /api/v1/plugins/{id}/disable" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PUT", "/api/v1/plugins/my-plugin/disable", "operator", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes POST /api/v1/plugins/{id}/reload" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("POST", "/api/v1/plugins/my-plugin/reload", "operator", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

// =============================================================================
// Prompt Routes
// =============================================================================

///|
test "router routes GET /api/v1/prompts/system" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/prompts/system", "viewer", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes PUT /api/v1/prompts/system" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PUT", "/api/v1/prompts/system", "admin", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes GET /api/v1/prompts/bootstrap" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/prompts/bootstrap", "viewer", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes POST /api/v1/prompts/bootstrap/append" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("POST", "/api/v1/prompts/bootstrap/append", "admin", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes GET /api/v1/prompts/channels/{name}" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/prompts/channels/default", "viewer", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes PUT /api/v1/prompts/channels/{name}" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PUT", "/api/v1/prompts/channels/default", "operator", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

// =============================================================================
// Error Cases
// =============================================================================

///|
test "router returns 404 for unknown resource" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/unknown", "admin", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 404)
}

///|
test "router returns 405 for invalid method" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PATCH", "/api/v1/settings", "admin", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 405)
}

///|
test "router returns 501 when handlers not configured" {
  let router = ApiRouter::new()
  let ctx = make_ctx("GET", "/api/v1/plugins", "admin", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 501)
}

// =============================================================================
// Authorization Tests
// =============================================================================

///|
test "router denies viewer write access to settings" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PUT", "/api/v1/settings", "viewer", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 403)
}

///|
test "router denies viewer admin actions on plugins" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("POST", "/api/v1/plugins", "viewer", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 403)
}

///|
test "router denies operator admin actions" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("POST", "/api/v1/plugins", "operator", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 403)
}

///|
test "router allows operator write access" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PUT", "/api/v1/settings/retry", "operator", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router allows admin full access" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("POST", "/api/v1/plugins", "admin", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}
