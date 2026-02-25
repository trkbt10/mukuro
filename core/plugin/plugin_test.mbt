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
  assert_eq(plugins.length(), 1)
  assert_eq(plugins[0].id, "test-plugin")
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
  assert_true(
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
  assert_true(manifest is Some(_))
  match manifest {
    Some(m) => {
      assert_eq(m.id, "email")
      assert_eq(m.name, "Email Plugin")
      assert_eq(m.capabilities.length(), 2)
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
      "endpoints": { "send": "POST /send", "status": "GET /status" },
    },
  }
  let manifest = parse_manifest(json)
  assert_true(manifest is Some(_))
  match manifest {
    Some(m) => {
      assert_true(m.http is Some(_))
      match m.http {
        Some(http) => {
          assert_eq(http.port, 9100)
          assert_true(http.endpoints.contains("send"))
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
  assert_true(parsed is Some(_))
  match parsed {
    Some(r) => {
      assert_eq(r.rpc_method, "test_method")
      assert_eq(r.id, Some(42))
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
  assert_true(response.error is None)
  // Check message was queued
  let msg = host.pop_message()
  assert_true(msg is Some(_))
  match msg {
    Some(envelope) => {
      assert_eq(envelope.content, "Hello!")
      assert_eq(envelope.sender_id, "user1")
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
    { "jsonrpc": String(ver), .. } => assert_eq(ver, "2.0")
    _ => panic()
  }
}

///|
test "SchemaValidator: validate string type" {
  let validator = SchemaValidator::new()
  let schema : Json = { "type": "string" }
  let result = validator.validate(schema, Json::string("hello"))
  assert_true(
    match result {
      ValidationResult::Valid => true
      _ => false
    },
  )
  // Invalid type
  let result2 = validator.validate(schema, Json::number(42))
  assert_true(
    match result2 {
      ValidationResult::Invalid(_) => true
      _ => false
    },
  )
}

///|
test "SchemaValidator: validate object with required properties" {
  let validator = SchemaValidator::new()
  let schema : Json = {
    "type": "object",
    "properties": { "name": { "type": "string" }, "age": { "type": "number" } },
    "required": ["name"],
  }
  // Valid object
  let result = validator.validate(schema, { "name": "John", "age": 30 })
  assert_true(
    match result {
      ValidationResult::Valid => true
      _ => false
    },
  )
  // Missing required property
  let result2 = validator.validate(schema, { "age": 30 })
  assert_true(
    match result2 {
      ValidationResult::Invalid(errors) => errors.length() > 0
      _ => false
    },
  )
}

///|
test "SchemaValidator: validate array items" {
  let validator = SchemaValidator::new()
  let schema : Json = { "type": "array", "items": { "type": "string" } }
  // Valid array
  let result = validator.validate(schema, Json::array(["a", "b", "c"]))
  assert_true(
    match result {
      ValidationResult::Valid => true
      _ => false
    },
  )
  // Invalid item type
  let result2 = validator.validate(schema, Json::array(["a", 123, "c"]))
  assert_true(
    match result2 {
      ValidationResult::Invalid(errors) => errors.length() > 0
      _ => false
    },
  )
}

///|
test "SchemaValidator: validate number constraints" {
  let validator = SchemaValidator::new()
  let schema : Json = { "type": "number", "minimum": 0, "maximum": 100 }
  // Valid number
  let result = validator.validate(schema, Json::number(50))
  assert_true(
    match result {
      ValidationResult::Valid => true
      _ => false
    },
  )
  // Below minimum
  let result2 = validator.validate(schema, Json::number(-5))
  assert_true(
    match result2 {
      ValidationResult::Invalid(_) => true
      _ => false
    },
  )
  // Above maximum
  let result3 = validator.validate(schema, Json::number(150))
  assert_true(
    match result3 {
      ValidationResult::Invalid(_) => true
      _ => false
    },
  )
}

///|
test "SchemaValidator: validate string enum" {
  let validator = SchemaValidator::new()
  let schema : Json = { "type": "string", "enum": ["red", "green", "blue"] }
  // Valid enum value
  let result = validator.validate(schema, Json::string("green"))
  assert_true(
    match result {
      ValidationResult::Valid => true
      _ => false
    },
  )
  // Invalid enum value
  let result2 = validator.validate(schema, Json::string("yellow"))
  assert_true(
    match result2 {
      ValidationResult::Invalid(_) => true
      _ => false
    },
  )
}

///|
test "capability_to_tool_definition: basic conversion" {
  let schema : @interfaces.CapabilitySchema = {
    description: "Greet a user",
    parameters: {
      "type": "object",
      "properties": { "name": { "type": "string", "description": "User name" } },
      "required": ["name"],
    },
    returns: None,
    examples: [],
  }
  let tool = capability_to_tool_definition("my-plugin", "greet", schema)
  assert_eq(tool.name, "my-plugin.greet")
  assert_eq(tool.description, "Greet a user")
  assert_eq(tool.metadata.get("plugin_id"), Some("my-plugin"))
  assert_eq(tool.metadata.get("capability"), Some("greet"))
}

///|
test "PluginToolRegistry: register and find tools" {
  let registry = PluginToolRegistry::new()
  let tool : @types.ToolDefinition = {
    name: "test.greet",
    description: "Test greeting",
    parameters: { "type": "object" },
    schema: None,
    metadata: { "plugin_id": "test" },
  }
  registry.register_plugin_tools("test", [tool])
  // Find tool
  let found = registry.find_tool("test.greet")
  assert_true(found is Some(_))
  match found {
    Some(t) => assert_eq(t.description, "Test greeting")
    None => panic()
  }
  // Get all tools
  let all_tools = registry.get_all_tools()
  assert_eq(all_tools.length(), 1)
}

///|
test "parse_plugin_tool_name: valid name" {
  let result = parse_plugin_tool_name("my-plugin.greet")
  assert_true(result is Some(_))
  match result {
    Some((plugin_id, capability)) => {
      assert_eq(plugin_id, "my-plugin")
      assert_eq(capability, "greet")
    }
    None => panic()
  }
}

///|
test "parse_plugin_tool_name: name with dots in capability" {
  let result = parse_plugin_tool_name("plugin.category.action")
  assert_true(result is Some(_))
  match result {
    Some((plugin_id, capability)) => {
      assert_eq(plugin_id, "plugin")
      assert_eq(capability, "category.action")
    }
    None => panic()
  }
}

///|
test "parse_plugin_tool_name: invalid name" {
  let result = parse_plugin_tool_name("no-dots")
  assert_true(result is None)
}

///|
test "PluginToolExecutor: create executor" {
  let host = PluginHostImpl::new(plugin_dir=".mukuro/plugins")
  let executor = PluginToolExecutor::new(
    plugin_host=host,
    plugin_id="test-plugin",
    method_name="greet",
  )
  assert_eq(executor.plugin_id, "test-plugin")
  assert_eq(executor.method_name, "greet")
}

///|
test "create_plugin_tool_executor: from tool name" {
  let host = PluginHostImpl::new(plugin_dir=".mukuro/plugins")
  let executor = create_plugin_tool_executor(host, "my-plugin.hello")
  assert_true(executor is Some(_))
  match executor {
    Some(exec) => {
      assert_eq(exec.plugin_id, "my-plugin")
      assert_eq(exec.method_name, "hello")
    }
    None => panic()
  }
}

///|
test "create_plugin_tool_executor: invalid tool name" {
  let host = PluginHostImpl::new(plugin_dir=".mukuro/plugins")
  let executor = create_plugin_tool_executor(host, "invalid-no-dots")
  assert_true(executor is None)
}

///|
test "PluginSystemInitializer: create initializer" {
  let initializer = PluginSystemInitializer::new(plugin_dir=".mukuro/plugins")
  let host = initializer.get_host()
  let registry = initializer.get_tool_registry()
  assert_eq(host.get_plugin_dir(), ".mukuro/plugins")
  assert_eq(registry.get_all_tools().length(), 0)
}

///|
test "HttpTransportHandler: TLS configuration" {
  let http_config : @interfaces.PluginHttpConfig = {
    port: 8443,
    base_url: None,
    endpoints: {},
  }
  let tls_config : @interfaces.PluginTlsConfig = {
    enabled: true,
    verify_host: true,
    ca_cert_path: Some("/path/to/ca.pem"),
    client_cert_path: None,
    client_key_path: None,
  }
  let handler = @transport.HttpTransportHandler::with_tls(
    plugin_id="test-plugin",
    config=http_config,
    auth_token=None,
    token_header="X-Plugin-Token",
    tls_config=Some(tls_config),
  )
  assert_true(handler.is_tls_enabled())
  assert_true(handler.is_https())
  assert_true(handler.get_tls_config() is Some(_))
}

///|
test "HttpTransportHandler: non-TLS configuration" {
  let http_config : @interfaces.PluginHttpConfig = {
    port: 8080,
    base_url: None,
    endpoints: {},
  }
  let handler = @transport.HttpTransportHandler::new(
    plugin_id="test-plugin",
    config=http_config,
    auth_token=None,
    token_header="X-Plugin-Token",
  )
  assert_false(handler.is_tls_enabled())
  assert_false(handler.is_https())
  assert_true(handler.get_tls_config() is None)
}

///|
test "TransportFactory: create_handler_with_tls" {
  let factory = @transport.TransportFactory::new()
  let manifest : @interfaces.PluginManifest = {
    id: "test-plugin",
    name: "Test Plugin",
    version: "1.0.0",
    plugin_type: @interfaces.PluginType::Channel,
    transport: @interfaces.PluginTransport::Http,
    http: Some({ port: 8443, base_url: None, endpoints: {} }),
    entry: None,
    capabilities: [],
    config: None,
  }
  let tls_config : @interfaces.PluginTlsConfig = {
    enabled: true,
    verify_host: true,
    ca_cert_path: None,
    client_cert_path: None,
    client_key_path: None,
  }
  let handler = factory.create_handler_with_tls(
    manifest,
    Some("secret-token"),
    "Authorization",
    Some(tls_config),
  ) catch {
    _ => panic()
  }
  assert_true(@interfaces.PluginTransportHandler::is_active(handler) == false)
}
