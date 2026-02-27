///|
/// Tests for HelloWorldPlugin

///|
test "HelloWorldConfig default values" {
  let config = HelloWorldConfig::default()
  assert_eq(config.greeting_prefix, "Hello")
  assert_eq(config.uppercase, false)
}

///|
test "HelloWorldPlugin new with custom config" {
  let config : HelloWorldConfig = { greeting_prefix: "Hi", uppercase: true }
  let plugin = HelloWorldPlugin::new(name="test-plugin", config~)
  assert_eq(plugin.name, "test-plugin")
  assert_eq(plugin.config.greeting_prefix, "Hi")
  assert_eq(plugin.config.uppercase, true)
  assert_eq(plugin.get_greeting_count(), 0)
}

///|
test "HelloWorldPlugin with_defaults" {
  let plugin = HelloWorldPlugin::with_defaults(name="default-plugin")
  assert_eq(plugin.name, "default-plugin")
  assert_eq(plugin.config.greeting_prefix, "Hello")
  assert_eq(plugin.config.uppercase, false)
}

///|
test "HelloWorldPlugin manifest" {
  let plugin = HelloWorldPlugin::with_defaults(name="Test Plugin")
  let manifest = plugin.manifest()
  assert_eq(manifest.id, "hello-world")
  assert_eq(manifest.name, "Test Plugin")
  assert_eq(manifest.version, "1.0.0")
  assert_eq(manifest.capabilities.length(), 4)
}

///|
test "HelloWorldPlugin greet method returns success" {
  let plugin = HelloWorldPlugin::with_defaults(name="Greeter")
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="greet",
    params=Some({ "name": "World" }),
    id=Some(1),
  )
  let response = plugin.handle_request(request)
  assert_true(response.result is Some(_))
  assert_true(response.error is None)
  assert_eq(plugin.get_greeting_count(), 1)
}

///|
test "HelloWorldPlugin greet increments count" {
  let plugin = HelloWorldPlugin::with_defaults(name="Counter")
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="greet",
    params=Some({ "name": "A" }),
    id=Some(1),
  )
  let _ = plugin.handle_request(request)
  let _ = plugin.handle_request(request)
  let _ = plugin.handle_request(request)
  assert_eq(plugin.get_greeting_count(), 3)
}

///|
test "HelloWorldPlugin greet empty name error" {
  let plugin = HelloWorldPlugin::with_defaults(name="Greeter")
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="greet",
    params=Some({ "name": "" }),
    id=Some(1),
  )
  let response = plugin.handle_request(request)
  assert_true(response.error is Some(_))
  assert_true(response.result is None)
}

///|
test "HelloWorldPlugin echo method returns success" {
  let plugin = HelloWorldPlugin::with_defaults(name="Echo")
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="echo",
    params=Some({ "message": "test message" }),
    id=Some(2),
  )
  let response = plugin.handle_request(request)
  assert_true(response.result is Some(_))
  assert_true(response.error is None)
}

///|
test "HelloWorldPlugin echo missing param error" {
  let plugin = HelloWorldPlugin::with_defaults(name="Echo")
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="echo",
    params=Some({}),
    id=Some(2),
  )
  let response = plugin.handle_request(request)
  assert_true(response.error is Some(_))
}

///|
test "HelloWorldPlugin reverse method returns success" {
  let plugin = HelloWorldPlugin::with_defaults(name="Reverser")
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="reverse",
    params=Some({ "text": "abc" }),
    id=Some(3),
  )
  let response = plugin.handle_request(request)
  assert_true(response.result is Some(_))
  assert_true(response.error is None)
}

///|
test "HelloWorldPlugin status method returns success" {
  let plugin = HelloWorldPlugin::with_defaults(name="StatusPlugin")
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="status",
    params=None,
    id=Some(4),
  )
  let response = plugin.handle_request(request)
  assert_true(response.result is Some(_))
  assert_true(response.error is None)
}

///|
test "HelloWorldPlugin unknown method returns error" {
  let plugin = HelloWorldPlugin::with_defaults(name="Plugin")
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="unknown",
    params=None,
    id=Some(5),
  )
  let response = plugin.handle_request(request)
  assert_true(response.error is Some(_))
  match response.error {
    Some(err) => assert_eq(err.code, -32601) // Method not found
    None => fail("Expected error")
  }
}
