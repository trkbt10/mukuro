///|
/// Unit tests for HttpTransportHandler

///|
test "HttpTransportHandler: constructor with default config" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  assert_eq(handler.get_base_url(), "http://localhost:8080")
  assert_false(handler.is_active())
  assert_false(handler.has_http_client())
  assert_false(handler.is_tls_enabled())
}

///|
test "HttpTransportHandler: constructor with custom base_url" {
  let config : @interfaces.PluginHttpConfig = {
    port: 9100,
    base_url: Some("http://myhost:9100"),
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  assert_eq(handler.get_base_url(), "http://myhost:9100")
}

///|
test "HttpTransportHandler: TLS enabled sets HTTPS" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8443,
    base_url: None,
    endpoints: {},
  }
  let tls_config : @interfaces.PluginTlsConfig = {
    enabled: true,
    verify_host: true,
    ca_cert_path: None,
    client_cert_path: None,
    client_key_path: None,
  }
  let handler = HttpTransportHandler::with_tls(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
    tls_config=Some(tls_config),
    http_client=None,
  )
  assert_true(handler.is_tls_enabled())
  assert_true(handler.is_https())
  assert_eq(handler.get_base_url(), "https://localhost:8443")
}

///|
test "HttpTransportHandler: TLS disabled uses HTTP" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let tls_config : @interfaces.PluginTlsConfig = {
    enabled: false,
    verify_host: false,
    ca_cert_path: None,
    client_cert_path: None,
    client_key_path: None,
  }
  let handler = HttpTransportHandler::with_tls(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
    tls_config=Some(tls_config),
    http_client=None,
  )
  assert_false(handler.is_tls_enabled())
  assert_false(handler.is_https())
  assert_eq(handler.get_base_url(), "http://localhost:8080")
}

///|
test "HttpTransportHandler: start/stop lifecycle" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  // Initially not active
  assert_false(handler.is_active())
  // Start
  handler.start() catch {
    _ => panic()
  }
  assert_true(handler.is_active())
  // Stop
  handler.stop() catch {
    _ => panic()
  }
  assert_false(handler.is_active())
}

///|
test "HttpTransportHandler: double start raises error" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  handler.start() catch {
    _ => panic()
  }
  // Second start should raise AlreadyStarted
  handler.start() catch {
    @interfaces.TransportError::AlreadyStarted => return
    _ => panic()
  }
  panic()
}

///|
test "HttpTransportHandler: send_request without starting raises error" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="test",
    params=None,
    id=Some(1),
  )
  let _ = @interfaces.PluginTransportHandler::send_request(handler, request) catch {
    @interfaces.TransportError::NotStarted => return
    _ => panic()
  }
  panic()
}

///|
test "HttpTransportHandler: build_url with endpoints" {
  let config : @interfaces.PluginHttpConfig = {
    port: 9100,
    base_url: None,
    endpoints: {
      "greet": { path: "/api/greet", http_method: "POST" },
      "echo": { path: "/api/echo", http_method: "POST" },
    },
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  // Configured endpoint
  assert_eq(handler.build_url("greet"), Some("http://localhost:9100/api/greet"))
  assert_eq(handler.build_url("echo"), Some("http://localhost:9100/api/echo"))
  // Fallback for unknown endpoint
  assert_eq(handler.build_url("unknown"), Some("http://localhost:9100/unknown"))
}

///|
test "HttpTransportHandler: build_headers with auth token" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=Some("secret-token"),
    token_header="Authorization",
  )
  let headers = handler.build_headers()
  assert_eq(headers.get("Content-Type"), Some("application/json"))
  assert_eq(headers.get("Authorization"), Some("Bearer secret-token"))
}

///|
test "HttpTransportHandler: build_headers without auth token" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="Authorization",
  )
  let headers = handler.build_headers()
  assert_eq(headers.get("Content-Type"), Some("application/json"))
  assert_true(headers.get("Authorization") is None)
}

///|
test "HttpTransportHandler: create_request generates incremental IDs" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  let req1 = handler.create_request(rpc_method="method1", params=None)
  let req2 = handler.create_request(rpc_method="method2", params=None)
  let req3 = handler.create_request(rpc_method="method3", params=None)
  assert_eq(req1.id, Some(1))
  assert_eq(req2.id, Some(2))
  assert_eq(req3.id, Some(3))
}

///|
test "HttpTransportHandler: queue_incoming and try_receive" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  // Initially empty
  assert_true(@interfaces.PluginTransportHandler::try_receive(handler) is None)
  // Queue some messages
  let msg1 = @interfaces.JsonRpcRequest::new(
    rpc_method="event1",
    params=None,
    id=None,
  )
  let msg2 = @interfaces.JsonRpcRequest::new(
    rpc_method="event2",
    params=None,
    id=None,
  )
  handler.queue_incoming(msg1)
  handler.queue_incoming(msg2)
  // Receive in order
  let received1 = @interfaces.PluginTransportHandler::try_receive(handler)
  match received1 {
    Some(r) => assert_eq(r.rpc_method, "event1")
    None => panic()
  }
  let received2 = @interfaces.PluginTransportHandler::try_receive(handler)
  match received2 {
    Some(r) => assert_eq(r.rpc_method, "event2")
    None => panic()
  }
  // Queue should be empty now
  assert_true(@interfaces.PluginTransportHandler::try_receive(handler) is None)
}

///|
test "HttpTransportHandler: on_message callback" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  let mut received_method = ""
  @interfaces.PluginTransportHandler::on_message(handler, fn(req) {
    received_method = req.rpc_method
  })
  // Queue a message
  let msg = @interfaces.JsonRpcRequest::new(
    rpc_method="test_event",
    params=None,
    id=None,
  )
  handler.queue_incoming(msg)
  // Callback should have been called
  assert_eq(received_method, "test_event")
}

///|
test "HttpTransportHandler: no HTTP client returns placeholder" {
  let config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = HttpTransportHandler::new(
    plugin_id="test-plugin",
    config~,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  handler.start() catch {
    _ => panic()
  }
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="test",
    params=None,
    id=Some(1),
  )
  let response = @interfaces.PluginTransportHandler::send_request(
    handler, request,
  ) catch {
    _ => panic()
  }
  // Should return placeholder since no HTTP client
  match response.result {
    Some(result) =>
      match result {
        { "pending": True, .. } => ()
        _ => panic()
      }
    None => panic()
  }
}

///|
test "parse_jsonrpc_response: valid success response" {
  let body =
    #|{"jsonrpc":"2.0","result":{"greeting":"Hello"},"id":42}
  let response = parse_jsonrpc_response(body)
  assert_true(response is Some(_))
  match response {
    Some(r) => {
      assert_eq(r.jsonrpc, "2.0")
      assert_eq(r.id, Some(42))
      assert_true(r.error is None)
      match r.result {
        Some({ "greeting": String(g), .. }) => assert_eq(g, "Hello")
        _ => panic()
      }
    }
    None => panic()
  }
}

///|
test "parse_jsonrpc_response: valid error response" {
  let body =
    #|{"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid Request"},"id":1}
  let response = parse_jsonrpc_response(body)
  assert_true(response is Some(_))
  match response {
    Some(r) => {
      assert_eq(r.jsonrpc, "2.0")
      assert_eq(r.id, Some(1))
      assert_true(r.result is None)
      match r.error {
        Some(e) => {
          assert_eq(e.code, -32600)
          assert_eq(e.message, "Invalid Request")
        }
        None => panic()
      }
    }
    None => panic()
  }
}

///|
test "parse_jsonrpc_response: invalid JSON" {
  let body = "not json"
  let response = parse_jsonrpc_response(body)
  assert_true(response is None)
}

///|
test "parse_jsonrpc_response: wrong version" {
  let body =
    #|{"jsonrpc":"1.0","result":"test","id":1}
  let response = parse_jsonrpc_response(body)
  assert_true(response is None)
}
