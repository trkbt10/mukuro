///|
async fn test_gateway() -> @control.Gateway {
  let gateway = create_global_gateway("test")
  gateway.start(config=@interfaces.GatewayConfig::default()) catch {
    _ => ()
  }
  gateway
}

///|
async fn test_gateway_with_auth_token(token : String) -> @control.Gateway {
  let gateway = create_global_gateway("test")
  let base_cfg = @interfaces.GatewayConfig::default()
  let cfg : @interfaces.GatewayConfig = { ..base_cfg, auth_token: token }
  gateway.start(config=cfg) catch {
    _ => ()
  }
  gateway
}

///|
async test "control api status returns running state" {
  let gateway = test_gateway()
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/status",
    {},
    "",
  )
  assert_eq(response.status, 200)
  assert_true(response.body.contains("\"state\":\"running\""))
}

///|
async test "control api dispatch validates payload" {
  let gateway = test_gateway()
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch",
    {},
    "{\"channel\":\"test\"}",
  )
  assert_eq(response.status, 400)
  assert_true(response.body.contains("bad_request"))
}

///|
async test "control api dispatch accepts valid payload without auth token config" {
  let gateway = test_gateway()
  set_forced_response_for_test(Some("ok"))
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch",
    {},
    "{\"channel\":\"test\",\"chat_id\":\"chat-1\",\"sender_id\":\"u-1\",\"content\":\"hello\"}",
  )
  set_forced_response_for_test(None)
  assert_eq(response.status, 200)
  assert_true(response.body.contains("\"ok\":true"))
}

///|
async test "control api dispatch outbound validates payload" {
  let gateway = test_gateway()
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch/outbound",
    {},
    "{\"channel\":\"test\"}",
  )
  assert_eq(response.status, 400)
  assert_true(response.body.contains("bad_request"))
}

///|
async test "control api dispatch outbound accepts valid payload" {
  let gateway = test_gateway()
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch/outbound",
    {},
    "{\"channel\":\"test\",\"chat_id\":\"chat-1\",\"content\":\"hello\"}",
  )
  assert_eq(response.status, 200)
  assert_true(response.body.contains("\"ok\":true"))
}

///|
async test "control api unknown path returns 404" {
  let gateway = test_gateway()
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/nope",
    {},
    "",
  )
  assert_eq(response.status, 404)
}

///|
async test "control api health live returns status" {
  let gateway = test_gateway()
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/health/live",
    {},
    "",
  )
  assert_eq(response.status, 200)
  assert_true(response.body.contains("\"live\":true"))
}

///|
async test "control api health ready returns status" {
  let gateway = test_gateway()
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/health/ready",
    {},
    "",
  )
  assert_eq(response.status, 200)
  assert_true(response.body.contains("\"ready\":true"))
}

///|
async test "control api status requires auth when token configured" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/status",
    {},
    "",
  )
  assert_eq(response.status, 401)
  assert_true(response.body.contains("unauthorized"))
}

///|
async test "control api status accepts bearer auth when token configured" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let headers : Map[String, String] = {}
  headers["authorization"] = "Bearer secret-token"
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/status",
    headers,
    "",
  )
  assert_eq(response.status, 200)
  assert_true(response.body.contains("\"state\":\"running\""))
}

///|
async test "control api health requires auth when token configured" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/health",
    {},
    "",
  )
  assert_eq(response.status, 401)
  assert_true(response.body.contains("unauthorized"))
}

///|
async test "control api health live requires auth when token configured" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/health/live",
    {},
    "",
  )
  assert_eq(response.status, 401)
  assert_true(response.body.contains("unauthorized"))
}

///|
async test "control api health ready accepts bearer auth when token configured" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let headers : Map[String, String] = {}
  headers["authorization"] = "Bearer secret-token"
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/health/ready",
    headers,
    "",
  )
  assert_eq(response.status, 200)
  assert_true(response.body.contains("\"ready\":true"))
}

///|
async test "control api dispatch requires auth when token configured" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch",
    {},
    "{\"channel\":\"test\",\"chat_id\":\"chat-1\",\"sender_id\":\"u-1\",\"content\":\"hello\"}",
  )
  assert_eq(response.status, 401)
  assert_true(response.body.contains("unauthorized"))
}

///|
async test "control api dispatch accepts bearer auth when token configured" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let headers : Map[String, String] = {}
  headers["authorization"] = "Bearer secret-token"
  set_forced_response_for_test(Some("ok"))
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch",
    headers,
    "{\"channel\":\"test\",\"chat_id\":\"chat-1\",\"sender_id\":\"u-1\",\"content\":\"hello\"}",
  )
  set_forced_response_for_test(None)
  assert_eq(response.status, 200)
  assert_true(response.body.contains("\"ok\":true"))
}

///|
async test "control api dispatch outbound requires auth when token configured" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch/outbound",
    {},
    "{\"channel\":\"test\",\"chat_id\":\"chat-1\",\"content\":\"hello\"}",
  )
  assert_eq(response.status, 401)
  assert_true(response.body.contains("unauthorized"))
}

///|
async test "control api dispatch outbound accepts bearer auth when token configured" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let headers : Map[String, String] = {}
  headers["authorization"] = "Bearer secret-token"
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch/outbound",
    headers,
    "{\"channel\":\"test\",\"chat_id\":\"chat-1\",\"content\":\"hello\"}",
  )
  assert_eq(response.status, 200)
  assert_true(response.body.contains("\"ok\":true"))
}

///|
async test "control api viewer role can read status" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let headers : Map[String, String] = {}
  headers["authorization"] = "Bearer secret-token"
  headers["x-mukuro-role"] = "viewer"
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/status",
    headers,
    "",
  )
  assert_eq(response.status, 200)
}

///|
/// Role header is ignored — all authenticated requests are treated as admin
/// to prevent role spoofing via client headers.
async test "control api ignores viewer role header for dispatch" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let headers : Map[String, String] = {}
  headers["authorization"] = "Bearer secret-token"
  headers["x-mukuro-role"] = "viewer"
  set_forced_response_for_test(Some("ok"))
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch",
    headers,
    "{\"channel\":\"test\",\"chat_id\":\"chat-1\",\"sender_id\":\"u-1\",\"content\":\"hello\"}",
  )
  set_forced_response_for_test(None)
  // Viewer header is ignored — authenticated request succeeds
  assert_eq(response.status, 200)
}

///|
async test "control api ignores viewer role header for dispatch outbound" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let headers : Map[String, String] = {}
  headers["authorization"] = "Bearer secret-token"
  headers["x-mukuro-role"] = "viewer"
  set_forced_response_for_test(Some("ok"))
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch/outbound",
    headers,
    "{\"channel\":\"test\",\"chat_id\":\"chat-1\",\"content\":\"hello\"}",
  )
  set_forced_response_for_test(None)
  // Viewer header is ignored — authenticated request succeeds
  assert_eq(response.status, 200)
}

///|
async test "control api operator role can dispatch" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let headers : Map[String, String] = {}
  headers["authorization"] = "Bearer secret-token"
  headers["x-mukuro-role"] = "operator"
  set_forced_response_for_test(Some("ok"))
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Post,
    "/dispatch",
    headers,
    "{\"channel\":\"test\",\"chat_id\":\"chat-1\",\"sender_id\":\"u-1\",\"content\":\"hello\"}",
  )
  set_forced_response_for_test(None)
  assert_eq(response.status, 200)
}

///|
/// Unknown role header is ignored — all authenticated requests succeed
async test "control api ignores unknown role header" {
  let gateway = test_gateway_with_auth_token("secret-token")
  let headers : Map[String, String] = {}
  headers["authorization"] = "Bearer secret-token"
  headers["x-mukuro-role"] = "guest"
  let response = handle_control_api_request(
    gateway,
    @xhttp.RequestMethod::Get,
    "/status",
    headers,
    "",
  )
  // Guest header is ignored — authenticated request succeeds
  assert_eq(response.status, 200)
}
