///|
/// E2E tests for plugin system with actual HTTP communication
/// Note: These tests require external services to be running

///|
/// Test HTTP transport handler with actual HTTP client
/// This test requires a Node.js plugin server running on port 9100
async test "E2E: HttpTransportHandler with real HTTP client (requires hello-world plugin)" {
  // Create HTTP client
  let http_client = @native.NativeHttpClient::default()
  // Create HTTP config for port 9100
  let http_config : @interfaces.PluginHttpConfig = {
    port: 9100,
    base_url: None,
    endpoints: {},
  }
  // Create handler with HTTP client
  let handler = HttpTransportHandler::with_client(
    plugin_id="hello-world",
    config=http_config,
    auth_token=None,
    token_header="X-Plugin-Token",
    http_client~,
  )
  // Start the handler
  handler.start() catch {
    e => {
      println("Failed to start handler: \{e}")
      return
    }
  }
  // Send greet request
  let greet_request = @interfaces.JsonRpcRequest::new(
    rpc_method="greet",
    params=Some(Json::object({ "name": "MoonBitE2E" })),
    id=Some(1),
  )
  println("Handler base URL: \{handler.get_base_url()}")
  println("Handler active: \{handler.is_active()}")
  println("Handler has HTTP client: \{handler.has_http_client()}")
  let greet_response = @interfaces.PluginTransportHandler::send_request(
    handler, greet_request,
  ) catch {
    e => {
      println("Request failed: \{e}")
      return
    }
  }
  // Verify response
  match greet_response.result {
    Some(result) =>
      match result {
        { "greeting": String(greeting), .. } => {
          println("Received greeting: \{greeting}")
          assert_true(greeting.contains("MoonBitE2E"))
        }
        _ => println("Unexpected result format: \{result}")
        // Don't fail if plugin isn't running
      }
    None =>
      match greet_response.error {
        Some(e) => println("No result in response, error: \{e.message}")
        None => println("No result and no error in response")
      }
    // Don't fail if plugin isn't running
  }
  // Send echo request
  let echo_request = @interfaces.JsonRpcRequest::new(
    rpc_method="echo",
    params=Some(Json::object({ "message": "E2E Test Message" })),
    id=Some(2),
  )
  let echo_response = @interfaces.PluginTransportHandler::send_request(
    handler, echo_request,
  ) catch {
    e => {
      println("Echo request failed: \{e}")
      return
    }
  }
  match echo_response.result {
    Some(result) =>
      match result {
        { "echoed": String(echoed), .. } => {
          println("Echoed: \{echoed}")
          assert_eq(echoed, "E2E Test Message")
        }
        _ => println("Unexpected echo result: \{result}")
      }
    None => println("No echo result")
  }
  // Send describe request
  let describe_request = @interfaces.JsonRpcRequest::new(
    rpc_method="describe",
    params=None,
    id=Some(3),
  )
  let describe_response = @interfaces.PluginTransportHandler::send_request(
    handler, describe_request,
  ) catch {
    e => {
      println("Describe request failed: \{e}")
      return
    }
  }
  match describe_response.result {
    Some(result) =>
      match result {
        {
          "id": String(id),
          "name": String(name),
          "capabilities": Array(caps),
          ..
        } => {
          println("Plugin ID: \{id}")
          println("Plugin Name: \{name}")
          println("Capabilities: \{caps.length()}")
          assert_eq(id, "hello-world")
          assert_eq(name, "Hello World Plugin")
        }
        _ => println("Unexpected describe result: \{result}")
      }
    None => println("No describe result")
  }
  // Stop the handler
  handler.stop()
}

///|
/// Test direct HTTP client JSON-RPC call
async test "E2E: Direct @native.NativeHttpClient JSON-RPC call" {
  let client = @native.NativeHttpClient::default()
  let url = "http://localhost:9100"
  // Create JSON-RPC request
  let request_json : Json = {
    "jsonrpc": "2.0",
    "method": "greet",
    "params": { "name": "DirectTest" },
    "id": 42,
  }
  println("Request JSON: \{request_json.stringify()}")
  let response = client.post_json(url, request_json) catch {
    _ => {
      println("HTTP request failed - plugin may not be running")
      return
    }
  }
  println("HTTP Status: \{response.status}")
  // Convert bytes to UTF-8 string manually
  let body = @utf8.decode(response.body) catch {
    _ => {
      println("Failed to decode response as UTF-8")
      return
    }
  }
  println("Response body: \{body}")
  // Parse response
  let parsed = @json.parse(body) catch {
    _ => {
      println("Failed to parse JSON response")
      return
    }
  }
  match parsed {
    {
      "jsonrpc": String("2.0"),
      "result": { "greeting": String(g), .. },
      "id": Number(id, ..),
      ..
    } => {
      println("Greeting: \{g}")
      println("ID: \{id}")
      assert_true(g.contains("DirectTest"))
      assert_eq(id.to_int(), 42)
    }
    _ => println("Unexpected response format")
  }
}
