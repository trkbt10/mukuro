///|
test "PluginRegistry: register and list plugins" {
  let registry = PluginRegistry::new(plugin_dir=".mukuro/plugins")
  let manifest : @interfaces.PluginManifest = {
    id: "test-plugin",
    name: "Test Plugin",
    version: "1.0.0",
    plugin_type: @interfaces.PluginType::Channel,
    transport: @interfaces.PluginTransport::Http,
    http: None,
    entry: None,
    capabilities: ["send", "receive"],
    config: None,
  }
  registry.register(manifest)
  let plugins = registry.list()
  assert_eq!(plugins.length(), 1)
  assert_eq!(plugins[0].id, "test-plugin")
}

///|
test "PluginRegistry: get status" {
  let registry = PluginRegistry::new(plugin_dir=".mukuro/plugins")
  let manifest : @interfaces.PluginManifest = {
    id: "test-plugin",
    name: "Test Plugin",
    version: "1.0.0",
    plugin_type: @interfaces.PluginType::Channel,
    transport: @interfaces.PluginTransport::Http,
    http: None,
    entry: None,
    capabilities: [],
    config: None,
  }
  registry.register(manifest)
  let status = registry.get_status("test-plugin") catch { _ => panic() }
  assert_true!(
    match status {
      @interfaces.PluginStatus::Stopped => true
      _ => false
    },
  )
}

///|
test "parse_manifest: basic parsing" {
  let json : Json = {
    "id": "email",
    "name": "Email Plugin",
    "version": "1.0.0",
    "type": "channel",
    "transport": "http",
    "capabilities": ["send", "receive"],
  }
  let manifest = parse_manifest(json)
  assert_true!(manifest is Some(_))
  match manifest {
    Some(m) => {
      assert_eq!(m.id, "email")
      assert_eq!(m.name, "Email Plugin")
      assert_eq!(m.capabilities.length(), 2)
    }
    None => panic()
  }
}

///|
test "parse_manifest: with http config" {
  let json : Json = {
    "id": "webhook",
    "name": "Webhook Plugin",
    "type": "channel",
    "transport": "http",
    "http": {
      "port": 9100,
      "endpoints": {
        "send": "POST /send",
        "status": "GET /status",
      },
    },
  }
  let manifest = parse_manifest(json)
  assert_true!(manifest is Some(_))
  match manifest {
    Some(m) => {
      assert_true!(m.http is Some(_))
      match m.http {
        Some(http) => {
          assert_eq!(http.port, 9100)
          assert_true!(http.endpoints.contains("send"))
        }
        None => panic()
      }
    }
    None => panic()
  }
}

///|
test "JsonRpcRequest: to_json and from_json" {
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="test_method",
    params=Some(Json::object({ "key": "value" })),
    id=Some(42),
  )
  let json = request.to_json()
  let parsed = @interfaces.JsonRpcRequest::from_json(json)
  assert_true!(parsed is Some(_))
  match parsed {
    Some(r) => {
      assert_eq!(r.rpc_method, "test_method")
      assert_eq!(r.id, Some(42))
    }
    None => panic()
  }
}

///|
test "PluginHostImpl: handle webhook message_received" {
  let host = PluginHostImpl::new(plugin_dir=".mukuro/plugins")
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="message_received",
    params=Some(
      Json::object({
        "channel": "test",
        "chat_id": "123",
        "sender_id": "user1",
        "content": "Hello!",
      }),
    ),
    id=Some(1),
  )
  let response = host.handle_webhook("test-plugin", request)
  assert_true!(response.error is None)
  // Check message was queued
  let msg = host.pop_message()
  assert_true!(msg is Some(_))
  match msg {
    Some(envelope) => {
      assert_eq!(envelope.content, "Hello!")
      assert_eq!(envelope.sender_id, "user1")
    }
    None => panic()
  }
}

///|
test "WebhookServer: handle request" {
  let host = PluginHostImpl::new(plugin_dir=".mukuro/plugins")
  let server = WebhookServer::new(host, port=9000)
  server.register_route("/webhook/test", "test-plugin")
  let body =
    #|{"jsonrpc": "2.0", "method": "message_received", "params": {"content": "test"}, "id": 1}
  let response = server.handle_request("/webhook/test", body)
  // Response should be valid JSON
  let json = @json.parse(response) catch { _ => panic() }
  match json {
    { "jsonrpc": String(ver), .. } => assert_eq!(ver, "2.0")
    _ => panic()
  }
}
