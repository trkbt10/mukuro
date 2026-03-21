///|
/// E2E tests for Stdio transport
/// These tests require Node.js to be installed

///|
test "StdioTransportAdapter: greet method" {
  let config : @interfaces.PluginStdioConfig = {
    command: "node",
    args: ["test-plugins/stdio_test/plugin.js"],
    cwd: None,
    env: {},
    framing: @interfaces.StdioFraming::NewlineDelimited,
    startup_timeout_ms: 5000,
    restart_policy: @interfaces.RestartPolicy::Never,
  }
  let adapter = StdioTransportAdapter::new(plugin_id="stdio-test", config~)
  adapter.start()
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="greet",
    params=Some(Json::object({ "name": "MoonBit" })),
    id=Some(1),
  )
  let response = adapter.send_request(request)
  assert_true(response.error is None)
  match response.result {
    Some(Object(result)) =>
      match result.get("greeting") {
        Some(String(greeting)) => assert_true(greeting.contains("MoonBit"))
        _ => panic()
      }
    _ => panic()
  }
  adapter.stop()
}

///|
test "StdioTransportAdapter: echo method" {
  let config : @interfaces.PluginStdioConfig = {
    command: "node",
    args: ["test-plugins/stdio_test/plugin.js"],
    cwd: None,
    env: {},
    framing: @interfaces.StdioFraming::NewlineDelimited,
    startup_timeout_ms: 5000,
    restart_policy: @interfaces.RestartPolicy::Never,
  }
  let adapter = StdioTransportAdapter::new(plugin_id="stdio-test", config~)
  adapter.start()
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="echo",
    params=Some(Json::object({ "message": "Hello from Stdio!" })),
    id=Some(2),
  )
  let response = adapter.send_request(request)
  assert_true(response.error is None)
  match response.result {
    Some(Object(result)) =>
      match result.get("echoed") {
        Some(String(echoed)) => assert_eq(echoed, "Hello from Stdio!")
        _ => panic()
      }
    _ => panic()
  }
  adapter.stop()
}

///|
test "StdioTransportAdapter: describe method" {
  let config : @interfaces.PluginStdioConfig = {
    command: "node",
    args: ["test-plugins/stdio_test/plugin.js"],
    cwd: None,
    env: {},
    framing: @interfaces.StdioFraming::NewlineDelimited,
    startup_timeout_ms: 5000,
    restart_policy: @interfaces.RestartPolicy::Never,
  }
  let adapter = StdioTransportAdapter::new(plugin_id="stdio-test", config~)
  adapter.start()
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="describe",
    params=None,
    id=Some(3),
  )
  let response = adapter.send_request(request)
  assert_true(response.error is None)
  match response.result {
    Some(Object(result)) =>
      match result.get("id") {
        Some(String(id)) => assert_eq(id, "stdio-test")
        _ => panic()
      }
    _ => panic()
  }
  adapter.stop()
}

///|
test "NativeStdioClient: direct request" {
  let client = NativeStdioClient::new(
    command="node",
    args=["test-plugins/stdio_test/plugin.js"],
    cwd=None,
    env={},
  )
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="greet",
    params=Some(Json::object({ "name": "Direct" })),
    id=Some(100),
  )
  let response = client.send_request(request)
  assert_true(response.error is None)
  match response.result {
    Some(Object(result)) =>
      match result.get("greeting") {
        Some(String(greeting)) => assert_true(greeting.contains("Direct"))
        _ => panic()
      }
    _ => panic()
  }
}
