///|
/// Tests for HelloWorldPlugin

///|
/// Helper to create a test request
fn make_request(
  rpc_method : String,
  params : Json?,
  id : Int,
) -> @interfaces.JsonRpcRequest {
  @interfaces.JsonRpcRequest::new(rpc_method~, params~, id=Some(id))
}

///|
/// Helper to get string from response result
fn get_result_string(
  response : @interfaces.JsonRpcResponse,
  key : String,
) -> String? {
  match response.result {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// Helper to get int from response result
fn get_result_int(response : @interfaces.JsonRpcResponse, key : String) -> Int? {
  match response.result {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

///|
test "greet returns greeting message" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let request = make_request("greet", Some({ "name": "World" }), 1)
  let response = plugin.handle_request(request)
  // Should succeed
  assert_true(response.error is None)
  assert_eq(response.id, Some(1))
  // Check message
  let message = get_result_string(response, "message")
  assert_eq(message, Some("Hello, World!"))
  // Check count
  let count = get_result_int(response, "count")
  assert_eq(count, Some(1))
}

///|
test "greet increments count" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  // First greeting
  let req1 = make_request("greet", Some({ "name": "Alice" }), 1)
  let _ = plugin.handle_request(req1)
  // Second greeting
  let req2 = make_request("greet", Some({ "name": "Bob" }), 2)
  let response = plugin.handle_request(req2)
  let count = get_result_int(response, "count")
  assert_eq(count, Some(2))
  assert_eq(plugin.get_greeting_count(), 2)
}

///|
test "greet with missing name returns error" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let request = make_request("greet", Some({}), 1)
  let response = plugin.handle_request(request)
  // Should fail with invalid params
  assert_true(response.error is Some(_))
  match response.error {
    Some(err) => assert_eq(err.code, @interfaces.jsonrpc_error_invalid_params())
    None => fail("Expected error")
  }
}

///|
test "greet with empty name returns error" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let request = make_request("greet", Some({ "name": "" }), 1)
  let response = plugin.handle_request(request)
  // Should fail with invalid params
  assert_true(response.error is Some(_))
  match response.error {
    Some(err) => {
      assert_eq(err.code, @interfaces.jsonrpc_error_invalid_params())
      assert_true(err.message.contains("empty"))
    }
    None => fail("Expected error")
  }
}

///|
test "echo returns same message" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let request = make_request("echo", Some({ "message": "Hello!" }), 1)
  let response = plugin.handle_request(request)
  assert_true(response.error is None)
  let echoed = get_result_string(response, "echoed")
  assert_eq(echoed, Some("Hello!"))
}

///|
test "echo with missing message returns error" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let request = make_request("echo", Some({}), 1)
  let response = plugin.handle_request(request)
  assert_true(response.error is Some(_))
}

///|
test "reverse returns reversed string" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let request = make_request("reverse", Some({ "text": "hello" }), 1)
  let response = plugin.handle_request(request)
  assert_true(response.error is None)
  let reversed = get_result_string(response, "reversed")
  assert_eq(reversed, Some("olleh"))
}

///|
test "reverse handles empty string" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let request = make_request("reverse", Some({ "text": "" }), 1)
  let response = plugin.handle_request(request)
  assert_true(response.error is None)
  let reversed = get_result_string(response, "reversed")
  assert_eq(reversed, Some(""))
}

///|
test "reverse with missing text returns error" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let request = make_request("reverse", Some({}), 1)
  let response = plugin.handle_request(request)
  assert_true(response.error is Some(_))
}

///|
test "status returns plugin info" {
  let plugin = HelloWorldPlugin::with_defaults(name="My Plugin")
  let request = make_request("status", None, 1)
  let response = plugin.handle_request(request)
  assert_true(response.error is None)
  // Check fields
  let name = get_result_string(response, "name")
  assert_eq(name, Some("My Plugin"))
  let version = get_result_string(response, "version")
  assert_eq(version, Some("1.0.0"))
  let count = get_result_int(response, "greeting_count")
  assert_eq(count, Some(0))
}

///|
test "unknown method returns method not found" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let request = make_request("unknown_method", None, 1)
  let response = plugin.handle_request(request)
  assert_true(response.error is Some(_))
  match response.error {
    Some(err) => {
      assert_eq(err.code, @interfaces.jsonrpc_error_method_not_found())
      assert_true(err.message.contains("unknown_method"))
    }
    None => fail("Expected error")
  }
}

///|
test "uppercase config affects output" {
  let config : HelloWorldConfig = { greeting_prefix: "Hi", uppercase: true }
  let plugin = HelloWorldPlugin::new(name="Uppercase Plugin", config~)
  // Test greet
  let greet_req = make_request("greet", Some({ "name": "test" }), 1)
  let greet_resp = plugin.handle_request(greet_req)
  let message = get_result_string(greet_resp, "message")
  assert_eq(message, Some("HI, TEST!"))
  // Test echo
  let echo_req = make_request("echo", Some({ "message": "hello" }), 2)
  let echo_resp = plugin.handle_request(echo_req)
  let echoed = get_result_string(echo_resp, "echoed")
  assert_eq(echoed, Some("HELLO"))
  // Test reverse
  let rev_req = make_request("reverse", Some({ "text": "abc" }), 3)
  let rev_resp = plugin.handle_request(rev_req)
  let reversed = get_result_string(rev_resp, "reversed")
  assert_eq(reversed, Some("CBA"))
}

///|
test "manifest returns correct info" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let manifest = plugin.manifest()
  assert_eq(manifest.id, "hello-world")
  assert_eq(manifest.name, "Test Plugin")
  assert_eq(manifest.version, "1.0.0")
  // Check plugin type is Tool
  match manifest.plugin_type {
    @interfaces.PluginType::Tool => ()
    _ => fail("Expected PluginType::Tool")
  }
  // Check transport is Stdio
  match manifest.transport {
    @interfaces.PluginTransport::Stdio => ()
    _ => fail("Expected PluginTransport::Stdio")
  }
  assert_eq(manifest.capabilities.length(), 4)
  assert_true(manifest.capabilities.contains("greet"))
  assert_true(manifest.capabilities.contains("echo"))
  assert_true(manifest.capabilities.contains("reverse"))
  assert_true(manifest.capabilities.contains("status"))
}

///|
test "custom greeting prefix" {
  let config : HelloWorldConfig = {
    greeting_prefix: "Welcome",
    uppercase: false,
  }
  let plugin = HelloWorldPlugin::new(name="Custom Plugin", config~)
  let request = make_request("greet", Some({ "name": "User" }), 1)
  let response = plugin.handle_request(request)
  let message = get_result_string(response, "message")
  assert_eq(message, Some("Welcome, User!"))
}
