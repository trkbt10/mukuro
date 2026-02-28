///|
/// API Router Tests

///|
fn make_ctx(
  meth : String,
  path : String,
  role : String,
  body : String,
) -> ApiRequestContext {
  ApiRequestContext::new(
    meth~,
    path~,
    headers={},
    body~,
    role=ApiRole::from_string(role),
  )
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
  let context_handlers : ContextApiHandlers = {
    list: RouteHandler(dummy_handler),
    get: RouteHandler(dummy_handler),
    update: RouteHandler(dummy_handler),
    delete: RouteHandler(dummy_handler),
  }
  let settings_handlers : SettingsApiHandlers = {
    get_all: RouteHandler(dummy_handler),
    update_all: RouteHandler(dummy_handler),
    get_retry: RouteHandler(dummy_handler),
    update_retry: RouteHandler(dummy_handler),
    get_agent: RouteHandler(dummy_handler),
    update_agent: RouteHandler(dummy_handler),
    get_model_inference: RouteHandler(dummy_handler),
    update_model_inference: RouteHandler(dummy_handler),
    list_providers: RouteHandler(dummy_handler),
    update_provider: RouteHandler(dummy_handler),
    list_provider_models: RouteHandler(dummy_handler),
  }
  {
    plugin_handlers: Some(plugin_handlers),
    context_handlers: Some(context_handlers),
    settings_handlers: Some(settings_handlers),
    config_handlers: None,
    provider_handlers: None,
    chat_handlers: None,
    history_handlers: None,
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
// Context Routes
// =============================================================================

///|
test "router routes GET /api/v1/context" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/context", "viewer", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes GET /api/v1/context/{name}" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("GET", "/api/v1/context/soul", "viewer", "")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes PUT /api/v1/context/{name}" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("PUT", "/api/v1/context/soul", "operator", "{}")
  let resp = router.route(ctx)
  assert_eq(resp.status, 200)
}

///|
test "router routes DELETE /api/v1/context/{name}" {
  let router = make_router_with_handlers()
  let ctx = make_ctx("DELETE", "/api/v1/context/soul", "admin", "")
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
