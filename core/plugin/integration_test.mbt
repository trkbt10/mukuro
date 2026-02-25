///|
/// Integration tests for the plugin system

///|
test "plugin loader: scan and load manifest" {
  // Create mock filesystem
  let manifests : Map[String, String] = {}
  let manifest_content =
    #|{
    #|  "id": "test-plugin",
    #|  "name": "Test Plugin",
    #|  "version": "1.0.0",
    #|  "type": "tool",
    #|  "transport": "http",
    #|  "http": { "port": 9100, "endpoints": {} },
    #|  "capabilities": ["greet"],
    #|  "capabilitySchemas": {
    #|    "greet": {
    #|      "description": "Greet a user",
    #|      "parameters": {
    #|        "type": "object",
    #|        "properties": {
    #|          "name": { "type": "string" }
    #|        },
    #|        "required": ["name"]
    #|      }
    #|    }
    #|  }
    #|}
  manifests[".mukuro/plugins/test-plugin/manifest.json"] = manifest_content
  fn read_file(path : String) -> String raise {
    match manifests.get(path) {
      Some(content) => content
      None => raise @interfaces.PluginError::NotFound(path)
    }
  }
  // Load manifest
  let loaded = load_plugin_manifest(
    ".mukuro/plugins/test-plugin",
    "manifest.json",
    read_file,
  ) catch {
    e => {
      println("Error: \{e}")
      panic()
    }
  }
  assert_eq(loaded.manifest.id, "test-plugin")
  assert_eq(loaded.manifest.name, "Test Plugin")
  assert_eq(loaded.manifest.capabilities.length(), 1)
  // Parse extended manifest from raw JSON
  let ext = parse_extended_manifest(loaded.raw_manifest)
  match ext {
    Some(e) => {
      assert_eq(e.capability_schemas.length(), 1)
      assert_true(e.capability_schemas.contains("greet"))
    }
    None => panic()
  }
}

///|
test "plugin loader: generate tools from manifest" {
  let schema : @interfaces.CapabilitySchema = {
    description: "Greet a user by name",
    parameters: {
      "type": "object",
      "properties": { "name": { "type": "string", "description": "User name" } },
      "required": ["name"],
    },
    returns: Some({ "type": "object", "properties": { "greeting": { "type": "string" } } }),
    examples: [],
  }
  let tool = capability_to_tool_definition("hello-world", "greet", schema)
  assert_eq(tool.name, "hello-world.greet")
  assert_eq(tool.description, "Greet a user by name")
  assert_true(tool.schema is Some(_))
  assert_eq(tool.metadata.get("plugin_id"), Some("hello-world"))
  assert_eq(tool.metadata.get("capability"), Some("greet"))
}

///|
test "schema validator: validate greet parameters" {
  let validator = SchemaValidator::new()
  let schema : Json = {
    "type": "object",
    "properties": { "name": { "type": "string" } },
    "required": ["name"],
  }
  // Valid input
  let valid_result = validator.validate(schema, { "name": "Alice" })
  assert_true(
    match valid_result {
      ValidationResult::Valid => true
      _ => false
    },
  )
  // Missing required field
  let invalid_result = validator.validate(schema, {})
  assert_true(
    match invalid_result {
      ValidationResult::Invalid(errors) => {
        assert_true(errors.length() > 0)
        true
      }
      _ => false
    },
  )
  // Wrong type
  let wrong_type = validator.validate(schema, { "name": 123 })
  assert_true(
    match wrong_type {
      ValidationResult::Invalid(_) => true
      _ => false
    },
  )
}

///|
test "plugin host: register and list plugins" {
  let host = PluginHostImpl::new(plugin_dir=".mukuro/plugins")
  let manifest : @interfaces.PluginManifest = {
    id: "test-plugin",
    name: "Test Plugin",
    version: "1.0.0",
    plugin_type: @interfaces.PluginType::Tool,
    transport: @interfaces.PluginTransport::Http,
    http: Some({ port: 9100, base_url: None, endpoints: {} }),
    entry: None,
    capabilities: ["greet", "echo"],
    config: None,
  }
  host.register_plugin(manifest)
  let plugins = @interfaces.PluginHost::list_plugins(host)
  assert_eq(plugins.length(), 1)
  assert_eq(plugins[0].id, "test-plugin")
  assert_eq(plugins[0].capabilities.length(), 2)
}

///|
test "plugin tool registry: full workflow" {
  let registry = PluginToolRegistry::new()
  // Create tool definitions
  let greet_tool : @types.ToolDefinition = {
    name: "hello-world.greet",
    description: "Greet a user",
    parameters: { "type": "object", "properties": { "name": { "type": "string" } } },
    schema: None,
    metadata: { "plugin_id": "hello-world", "capability": "greet" },
  }
  let echo_tool : @types.ToolDefinition = {
    name: "hello-world.echo",
    description: "Echo a message",
    parameters: { "type": "object", "properties": { "message": { "type": "string" } } },
    schema: None,
    metadata: { "plugin_id": "hello-world", "capability": "echo" },
  }
  // Register tools
  registry.register_plugin_tools("hello-world", [greet_tool, echo_tool])
  // Find tools
  assert_true(registry.find_tool("hello-world.greet") is Some(_))
  assert_true(registry.find_tool("hello-world.echo") is Some(_))
  assert_true(registry.find_tool("unknown.tool") is None)
  // List all tools
  let all_tools = registry.get_all_tools()
  assert_eq(all_tools.length(), 2)
  // Get plugin tools
  let plugin_tools = registry.get_plugin_tools("hello-world")
  assert_eq(plugin_tools.length(), 2)
  // Unregister
  registry.unregister_plugin_tools("hello-world")
  assert_eq(registry.get_all_tools().length(), 0)
}

///|
test "dynamic plugin manager: enable/disable workflow" {
  let host = PluginHostImpl::new(plugin_dir=".mukuro/plugins")
  let manifests : Map[String, String] = {}
  let manifest_json =
    #|{"id": "my-plugin", "name": "My Plugin", "version": "1.0.0", "type": "tool", "transport": "http", "http": {"port": 9200, "endpoints": {}}, "capabilities": []}
  manifests[".mukuro/plugins/my-plugin/manifest.json"] = manifest_json
  let list_fn : (String) -> Array[String] raise = fn(_path) { ["my-plugin"] }
  fn read_fn(path : String) -> String raise {
    match manifests.get(path) {
      Some(c) => c
      None => raise @interfaces.PluginManagerError::FilesystemError("Not found")
    }
  }
  let exists_fn : (String) -> Bool = fn(path) { manifests.contains(path) }
  let manager = DynamicPluginManagerImpl::with_fs(
    host~,
    plugin_dir=".mukuro/plugins",
    list_dir=list_fn,
    read_file=read_fn,
    file_exists=exists_fn,
  )
  // Load plugin
  manager.load_plugin(".mukuro/plugins/my-plugin/manifest.json") catch {
    _ => panic()
  }
  // Get state
  let state = manager.get_state("my-plugin") catch { _ => panic() }
  assert_true(state.enabled)
  // Disable
  manager.disable("my-plugin") catch { _ => panic() }
  let state2 = manager.get_state("my-plugin") catch { _ => panic() }
  assert_false(state2.enabled)
  // Enable
  manager.enable("my-plugin") catch { _ => panic() }
  let state3 = manager.get_state("my-plugin") catch { _ => panic() }
  assert_true(state3.enabled)
}

///|
test "transport factory: create handlers for all types" {
  let factory = @transport.TransportFactory::new()
  // HTTP transport
  let http_manifest : @interfaces.PluginManifest = {
    id: "http-plugin",
    name: "HTTP Plugin",
    version: "1.0.0",
    plugin_type: @interfaces.PluginType::Tool,
    transport: @interfaces.PluginTransport::Http,
    http: Some({ port: 9100, base_url: None, endpoints: {} }),
    entry: None,
    capabilities: [],
    config: None,
  }
  let http_handler = factory.create_handler(http_manifest) catch { _ => panic() }
  assert_false(@interfaces.PluginTransportHandler::is_active(http_handler))
  // Stdio transport
  let stdio_manifest : @interfaces.PluginManifest = {
    id: "stdio-plugin",
    name: "Stdio Plugin",
    version: "1.0.0",
    plugin_type: @interfaces.PluginType::Tool,
    transport: @interfaces.PluginTransport::Stdio,
    http: None,
    entry: Some("node index.js"),
    capabilities: [],
    config: None,
  }
  let stdio_handler = factory.create_handler(stdio_manifest) catch { _ => panic() }
  assert_false(@interfaces.PluginTransportHandler::is_active(stdio_handler))
  // WebSocket transport
  let ws_manifest : @interfaces.PluginManifest = {
    id: "ws-plugin",
    name: "WebSocket Plugin",
    version: "1.0.0",
    plugin_type: @interfaces.PluginType::Tool,
    transport: @interfaces.PluginTransport::WebSocket,
    http: Some({ port: 9300, base_url: None, endpoints: {} }),
    entry: None,
    capabilities: [],
    config: None,
  }
  let ws_handler = factory.create_handler(ws_manifest) catch { _ => panic() }
  assert_false(@interfaces.PluginTransportHandler::is_active(ws_handler))
}
