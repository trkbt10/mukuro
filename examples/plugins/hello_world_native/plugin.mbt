///|
/// Hello World Plugin
/// A minimal example plugin demonstrating the plugin system.
/// Provides: greet, echo, reverse, and status methods.

///|
/// Plugin configuration
pub(all) struct HelloWorldConfig {
  /// Default greeting prefix
  greeting_prefix : String
  /// Whether to uppercase output
  uppercase : Bool
}

///|
/// Create default config
pub fn HelloWorldConfig::default() -> HelloWorldConfig {
  { greeting_prefix: "Hello", uppercase: false }
}

///|
/// Hello World Plugin
pub struct HelloWorldPlugin {
  /// Plugin name
  name : String
  /// Configuration
  config : HelloWorldConfig
  /// Number of greetings issued
  mut greeting_count : Int
}

///|
/// Create a new HelloWorldPlugin
pub fn HelloWorldPlugin::new(
  name~ : String,
  config~ : HelloWorldConfig,
) -> HelloWorldPlugin {
  { name, config, greeting_count: 0 }
}

///|
/// Create with default config
pub fn HelloWorldPlugin::with_defaults(name~ : String) -> HelloWorldPlugin {
  HelloWorldPlugin::new(name~, config=HelloWorldConfig::default())
}

///|
/// Get greeting count
pub fn HelloWorldPlugin::get_greeting_count(self : HelloWorldPlugin) -> Int {
  self.greeting_count
}

///|
/// Generate plugin manifest
pub fn HelloWorldPlugin::manifest(
  self : HelloWorldPlugin,
) -> @interfaces.PluginManifest {
  {
    id: "hello-world",
    name: self.name,
    version: "1.0.0",
    plugin_type: @interfaces.PluginType::Tool,
    transport: @interfaces.PluginTransport::Stdio,
    http: None,
    entry: None,
    capabilities: ["greet", "echo", "reverse", "status"],
    config: None,
  }
}

///|
/// Handle incoming JSON-RPC requests
pub fn HelloWorldPlugin::handle_request(
  self : HelloWorldPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "greet" => self.handle_greet(request)
    "echo" => self.handle_echo(request)
    "reverse" => self.handle_reverse(request)
    "status" => self.handle_status(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
/// Handle greet method
fn HelloWorldPlugin::handle_greet(
  self : HelloWorldPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let name = match @interfaces.rpc_require_string(request, "name") {
    Ok(n) => n
    Err(response) => return response
  }
  if name.is_empty() {
    return @interfaces.rpc_invalid_params("Name cannot be empty", request.id)
  }
  self.greeting_count = self.greeting_count + 1
  let message = "\{self.config.greeting_prefix}, \{name}!"
  let final_message = if self.config.uppercase {
    message.to_upper()
  } else {
    message
  }
  @interfaces.JsonRpcResponse::success(
    result={
      "message": Json::string(final_message),
      "count": Json::number(self.greeting_count.to_double()),
    },
    id=request.id,
  )
}

///|
/// Handle echo method
fn HelloWorldPlugin::handle_echo(
  self : HelloWorldPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let message = match @interfaces.rpc_require_string(request, "message") {
    Ok(m) => m
    Err(response) => return response
  }
  let final_message = if self.config.uppercase {
    message.to_upper()
  } else {
    message
  }
  @interfaces.JsonRpcResponse::success(
    result={ "echoed": Json::string(final_message) },
    id=request.id,
  )
}

///|
/// Handle reverse method
fn HelloWorldPlugin::handle_reverse(
  self : HelloWorldPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let text = match @interfaces.rpc_require_string(request, "text") {
    Ok(t) => t
    Err(response) => return response
  }
  let chars = text.to_array()
  let reversed_chars : Array[Char] = []
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    reversed_chars.push(chars[i])
  }
  let mut reversed = ""
  for c in reversed_chars {
    reversed = reversed + c.to_string()
  }
  let final_text = if self.config.uppercase {
    reversed.to_upper()
  } else {
    reversed
  }
  @interfaces.JsonRpcResponse::success(
    result={ "reversed": Json::string(final_text) },
    id=request.id,
  )
}

///|
/// Handle status method
fn HelloWorldPlugin::handle_status(
  self : HelloWorldPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  @interfaces.JsonRpcResponse::success(
    result={
      "name": Json::string(self.name),
      "version": Json::string("1.0.0"),
      "greeting_count": Json::number(self.greeting_count.to_double()),
      "uppercase": Json::boolean(self.config.uppercase),
    },
    id=request.id,
  )
}
