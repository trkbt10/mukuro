///|
/// API Types Tests
test "parse_path_segments basic" {
  let ctx = ApiRequestContext::new(
    meth="GET",
    path="/api/v1/plugins",
    headers={},
    body="",
  )
  assert_eq(ctx.segments.length(), 1)
  assert_eq(ctx.segments[0], "plugins")
}

///|
test "parse_path_segments with id" {
  let ctx = ApiRequestContext::new(
    meth="GET",
    path="/api/v1/plugins/my-plugin",
    headers={},
    body="",
  )
  assert_eq(ctx.segments.length(), 2)
  assert_eq(ctx.segments[0], "plugins")
  assert_eq(ctx.segments[1], "my-plugin")
}

///|
test "parse_path_segments with action" {
  let ctx = ApiRequestContext::new(
    meth="PUT",
    path="/api/v1/plugins/my-plugin/enable",
    headers={},
    body="",
  )
  assert_eq(ctx.segments.length(), 3)
  assert_eq(ctx.segments[0], "plugins")
  assert_eq(ctx.segments[1], "my-plugin")
  assert_eq(ctx.segments[2], "enable")
}

///|
test "parse_path_segments with query" {
  let ctx = ApiRequestContext::new(
    meth="GET",
    path="/api/v1/plugins?page=1&per_page=10",
    headers={},
    body="",
  )
  assert_eq(ctx.segments.length(), 1)
  assert_eq(ctx.segments[0], "plugins")
  assert_eq(ctx.query.get("page"), Some("1"))
  assert_eq(ctx.query.get("per_page"), Some("10"))
}

///|
test "role is set from parameter not header" {
  let headers : Map[String, String] = {}
  headers["x-mukuro-role"] = "admin"
  let ctx = ApiRequestContext::new(
    meth="GET",
    path="/api/v1/settings",
    headers~,
    body="",
    role=ApiRole::Viewer,
  )
  // Role should come from the parameter, not the header
  assert_eq(ctx.role.to_string(), "viewer")
}

///|
test "role header is ignored for security" {
  let headers : Map[String, String] = {}
  headers["X-Mukuro-Role"] = "admin"
  let ctx = ApiRequestContext::new(
    meth="GET",
    path="/api/v1/settings",
    headers~,
    body="",
    role=ApiRole::Anonymous,
  )
  // Client header "admin" must be ignored, server-set role "anonymous" used
  assert_eq(ctx.role.to_string(), "anonymous")
}

///|
test "default role is Admin" {
  let ctx = ApiRequestContext::new(
    meth="GET",
    path="/api/v1/settings",
    headers={},
    body="",
  )
  assert_eq(ctx.role.to_string(), "admin")
}

///|
test "parse_client_id" {
  let headers : Map[String, String] = {}
  headers["x-mukuro-client-id"] = "test-client"
  let ctx = ApiRequestContext::new(
    meth="GET",
    path="/api/v1/settings",
    headers~,
    body="",
  )
  assert_eq(ctx.client_id, "test-client")
}

///|
test "json_response creates correct format" {
  let resp = json_response(200, { "test": "value" })
  assert_eq(resp.status, 200)
  assert_true(resp.headers.get("content-type") == Some("application/json"))
  assert_true(resp.body.contains("test"))
}

///|
test "error_response creates correct format" {
  let resp = error_response(400, "bad_request", "Test error")
  assert_eq(resp.status, 400)
  assert_true(resp.body.contains("bad_request"))
  assert_true(resp.body.contains("Test error"))
}

///|
test "url_decode - basic percent encoding" {
  assert_eq(url_decode("web_chat%3Aabc"), "web_chat:abc")
}

///|
test "url_decode - plus as space" {
  assert_eq(url_decode("hello+world"), "hello world")
}

///|
test "url_decode - no encoding" {
  assert_eq(url_decode("plain-text"), "plain-text")
}

///|
test "url_decode - multiple encoded chars" {
  assert_eq(url_decode("%2Fpath%2Fto%2Ffile"), "/path/to/file")
}

///|
test "url_decode - incomplete percent sequence" {
  assert_eq(url_decode("abc%2"), "abc%2")
  assert_eq(url_decode("abc%"), "abc%")
}
