///|
/// Plugin tool executor - executes plugin capabilities as tools

///|
/// Plugin execution error
pub(all) suberror PluginExecutorError {
  InvalidArguments(String)
  ExecutionFailed(String)
  PluginNotFound(String)
}

///|
/// Plugin tool executor that invokes plugin capabilities via JSON-RPC
pub struct PluginToolExecutor {
  /// The plugin host
  plugin_host : PluginHostImpl
  /// Plugin ID
  plugin_id : String
  /// Capability/method name
  method_name : String
}

///|
/// Create a new plugin tool executor
pub fn PluginToolExecutor::new(
  plugin_host~ : PluginHostImpl,
  plugin_id~ : String,
  method_name~ : String,
) -> PluginToolExecutor {
  { plugin_host, plugin_id, method_name }
}

///|
/// Execute the plugin tool
pub fn PluginToolExecutor::execute(
  self : PluginToolExecutor,
  tool_name~ : String,
  arguments~ : Json,
  context~ : @types.ToolContext,
) -> @types.ToolResult raise PluginExecutorError {
  // Validate arguments against schema if available
  match self.plugin_host.extended_manifests.get(self.plugin_id) {
    Some(ext_manifest) =>
      match ext_manifest.capability_schemas.get(self.method_name) {
        Some(schema) => {
          let result = SchemaValidator::new().validate(
            schema.parameters,
            arguments,
          )
          match result {
            ValidationResult::Invalid(errors) => {
              let error_msgs : Array[String] = []
              for err in errors {
                error_msgs.push("\{err.path}: \{err.message}")
              }
              raise PluginExecutorError::InvalidArguments(error_msgs.join(", "))
            }
            ValidationResult::Valid => ()
          }
        }
        None => ()
      }
    None => ()
  }
  // Create JSON-RPC request
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method=self.method_name,
    params=Some(arguments),
    id=Some(gen_request_id()),
  )
  // Send request to plugin
  let response = @interfaces.PluginHost::send_request(
    self.plugin_host,
    plugin_id=self.plugin_id,
    request~,
  ) catch {
    e => raise PluginExecutorError::ExecutionFailed("Plugin call failed: \{e}")
  }
  // Handle response
  match response.error {
    Some(err) =>
      raise PluginExecutorError::ExecutionFailed(
        "Plugin error [\{err.code}]: \{err.message}",
      )
    None => ()
  }
  // Convert result to ToolResult
  let output = match response.result {
    Some(result) =>
      match result {
        String(s) => s
        _ => result.stringify()
      }
    None => ""
  }
  // Use context.session for metadata (suppress unused warnings)
  ignore(context)
  ignore(tool_name)
  @types.ToolResult::Success(content=output)
}

///|
/// Request ID counter
let request_counter : Ref[Int] = { val: 0 }

///|
/// Generate unique request ID
fn gen_request_id() -> Int {
  request_counter.val = request_counter.val + 1
  request_counter.val
}

///|
/// Implementation of ToolExecutor trait
pub impl @interfaces.ToolExecutor for PluginToolExecutor with execute(
  self,
  tool_name~,
  arguments~,
  context~,
) {
  PluginToolExecutor::execute(self, tool_name~, arguments~, context~) catch {
    PluginExecutorError::InvalidArguments(msg) =>
      raise @interfaces.ToolError::InvalidArguments(msg)
    PluginExecutorError::ExecutionFailed(msg) =>
      raise @interfaces.ToolError::ExecutionFailed(msg)
    PluginExecutorError::PluginNotFound(msg) =>
      raise @interfaces.ToolError::NotFound(msg)
  }
}

///|
/// Plugin system initializer
pub struct PluginSystemInitializer {
  /// Plugin host
  plugin_host : PluginHostImpl
  /// Tool registry
  tool_registry : PluginToolRegistry
  /// Plugin directory
  plugin_dir : String
}

///|
/// Create a new plugin system initializer
pub fn PluginSystemInitializer::new(
  plugin_dir~ : String,
) -> PluginSystemInitializer {
  let plugin_host = PluginHostImpl::new(plugin_dir~)
  let tool_registry = PluginToolRegistry::new()
  { plugin_host, tool_registry, plugin_dir }
}

///|
/// Initialize the plugin system
pub fn PluginSystemInitializer::initialize(
  self : PluginSystemInitializer,
) -> Unit raise {
  // 1. Load plugins from directory
  @interfaces.PluginHost::load_plugins(self.plugin_host, path=self.plugin_dir)
  // 2. Generate tools from plugin schemas
  for manifest in @interfaces.PluginHost::list_plugins(self.plugin_host) {
    match self.plugin_host.extended_manifests.get(manifest.id) {
      Some(ext_manifest) => {
        let tools = generate_tools_from_extended_manifest(ext_manifest)
        self.tool_registry.register_plugin_tools(manifest.id, tools)
      }
      None => ()
    }
  }
  // 3. Auto-start enabled plugins
  self.plugin_host.auto_start_plugins()
}

///|
/// Get the plugin host
pub fn PluginSystemInitializer::get_host(
  self : PluginSystemInitializer,
) -> PluginHostImpl {
  self.plugin_host
}

///|
/// Get the tool registry
pub fn PluginSystemInitializer::get_tool_registry(
  self : PluginSystemInitializer,
) -> PluginToolRegistry {
  self.tool_registry
}

///|
/// Register plugin tools with a ToolRegistry
pub fn[R : @interfaces.ToolRegistry] PluginSystemInitializer::register_with_registry(
  self : PluginSystemInitializer,
  registry : R,
) -> Unit {
  for tool in self.tool_registry.get_all_tools() {
    // Parse plugin_id and method from tool name
    match parse_plugin_tool_name(tool.name) {
      Some((plugin_id, method_name)) => {
        let executor = PluginToolExecutor::new(
          plugin_host=self.plugin_host,
          plugin_id~,
          method_name~,
        )
        registry.register(tool, executor)
      }
      None => ()
    }
  }
}

///|
/// Create tool executor for a plugin capability
pub fn create_plugin_tool_executor(
  plugin_host : PluginHostImpl,
  tool_name : String,
) -> PluginToolExecutor? {
  match parse_plugin_tool_name(tool_name) {
    Some((plugin_id, method_name)) =>
      Some(PluginToolExecutor::new(plugin_host~, plugin_id~, method_name~))
    None => None
  }
}
