///|
/// Plugin transport method
pub(all) enum PluginTransport {
  /// HTTP/webhook transport
  Http
  /// stdin/stdout transport (for child process plugins)
  Stdio
  /// WebSocket transport (for real-time plugins)
  WebSocket
}

///|
/// Plugin type
pub(all) enum PluginType {
  /// Channel plugin (Discord, Slack, Email, etc.)
  Channel
  /// Tool plugin (custom agent tools)
  Tool
  /// Storage plugin (memory, database, etc.)
  Storage
  /// Custom plugin type
  Custom(String)
}

///|
/// HTTP endpoint configuration
pub(all) struct PluginHttpEndpoint {
  /// HTTP method (GET, POST, etc.)
  http_method : String
  /// Path (e.g., "/send", "/status")
  path : String
}

///|
/// HTTP transport configuration
pub(all) struct PluginHttpConfig {
  /// Port for HTTP server
  port : Int
  /// Base URL (for outgoing requests to plugin)
  base_url : String?
  /// Endpoints
  endpoints : Map[String, PluginHttpEndpoint]
}

///|
/// Plugin manifest
/// Describes a plugin's metadata and configuration
pub(all) struct PluginManifest {
  /// Unique plugin identifier
  id : String
  /// Human-readable name
  name : String
  /// Plugin version
  version : String
  /// Plugin type
  plugin_type : PluginType
  /// Transport method
  transport : PluginTransport
  /// HTTP configuration (when transport is Http)
  http : PluginHttpConfig?
  /// Entry command to start the plugin
  entry : String?
  /// Plugin capabilities
  capabilities : Array[String]
  /// Plugin-specific configuration
  config : Json?
}

///|
/// Default manifest
pub fn PluginManifest::default(id~ : String, name~ : String) -> PluginManifest {
  {
    id,
    name,
    version: "1.0.0",
    plugin_type: PluginType::Channel,
    transport: PluginTransport::Http,
    http: None,
    entry: None,
    capabilities: [],
    config: None,
  }
}

///|
/// JSON-RPC 2.0 Request
pub(all) struct JsonRpcRequest {
  /// JSON-RPC version (always "2.0")
  jsonrpc : String
  /// Method name
  rpc_method : String
  /// Parameters
  params : Json?
  /// Request ID (null for notifications)
  id : Int?
}

///|
/// JSON-RPC 2.0 Response
pub(all) struct JsonRpcResponse {
  /// JSON-RPC version
  jsonrpc : String
  /// Result (on success)
  result : Json?
  /// Error (on failure)
  error : JsonRpcError?
  /// Request ID
  id : Int?
}

///|
/// JSON-RPC 2.0 Error
pub(all) struct JsonRpcError {
  /// Error code
  code : Int
  /// Error message
  message : String
  /// Additional data
  data : Json?
}

///|
/// Standard JSON-RPC error codes
pub fn jsonrpc_error_parse_error() -> Int {
  -32700
}

pub fn jsonrpc_error_invalid_request() -> Int {
  -32600
}

pub fn jsonrpc_error_method_not_found() -> Int {
  -32601
}

pub fn jsonrpc_error_invalid_params() -> Int {
  -32602
}

pub fn jsonrpc_error_internal_error() -> Int {
  -32603
}

///|
/// Create a JSON-RPC request
pub fn JsonRpcRequest::new(
  rpc_method~ : String,
  params~ : Json?,
  id~ : Int?,
) -> JsonRpcRequest {
  { jsonrpc: "2.0", rpc_method, params, id }
}

///|
/// Create a JSON-RPC success response
pub fn JsonRpcResponse::success(result~ : Json, id~ : Int?) -> JsonRpcResponse {
  { jsonrpc: "2.0", result: Some(result), error: None, id }
}

///|
/// Create a JSON-RPC error response
pub fn JsonRpcResponse::error(
  code~ : Int,
  message~ : String,
  id~ : Int?,
) -> JsonRpcResponse {
  {
    jsonrpc: "2.0",
    result: None,
    error: Some({ code, message, data: None }),
    id,
  }
}

///|
/// Convert JsonRpcRequest to JSON
pub fn JsonRpcRequest::to_json(self : JsonRpcRequest) -> Json {
  let obj : Map[String, Json] = {
    "jsonrpc": Json::string(self.jsonrpc),
    "method": Json::string(self.rpc_method),
  }
  match self.params {
    Some(p) => obj["params"] = p
    None => ()
  }
  match self.id {
    Some(i) => obj["id"] = Json::number(i.to_double())
    None => ()
  }
  Json::object(obj)
}

///|
/// Convert JsonRpcResponse to JSON
pub fn JsonRpcResponse::to_json(self : JsonRpcResponse) -> Json {
  let obj : Map[String, Json] = { "jsonrpc": Json::string(self.jsonrpc) }
  match self.result {
    Some(r) => obj["result"] = r
    None => ()
  }
  match self.error {
    Some(e) =>
      obj["error"] = {
        "code": Json::number(e.code.to_double()),
        "message": Json::string(e.message),
      }
    None => ()
  }
  match self.id {
    Some(i) => obj["id"] = Json::number(i.to_double())
    None => ()
  }
  Json::object(obj)
}

///|
/// Parse JsonRpcRequest from JSON
pub fn JsonRpcRequest::from_json(json : Json) -> JsonRpcRequest? {
  match json {
    { "jsonrpc": String(ver), "method": String(rpc_method), .. } =>
      if ver == "2.0" {
        let params = match json {
          { "params": p, .. } => Some(p)
          _ => None
        }
        let id = match json {
          { "id": Number(i, ..), .. } => Some(i.to_int())
          _ => None
        }
        Some({ jsonrpc: ver, rpc_method, params, id })
      } else {
        None
      }
    _ => None
  }
}

///|
/// Plugin status
pub(all) enum PluginStatus {
  /// Plugin is not running
  Stopped
  /// Plugin is starting
  Starting
  /// Plugin is running
  Running
  /// Plugin encountered an error
  Error(String)
}

///|
/// Plugin instance
pub(all) struct PluginInstance {
  /// Plugin manifest
  manifest : PluginManifest
  /// Current status
  mut status : PluginStatus
  /// Process ID (for stdio/child process plugins)
  mut pid : Int?
}

///|
/// Plugin host error
pub(all) suberror PluginError {
  /// Plugin not found
  NotFound(String)
  /// Failed to start plugin
  StartFailed(String)
  /// Communication error
  CommunicationError(String)
  /// Invalid manifest
  InvalidManifest(String)
  /// Method not supported
  MethodNotSupported(String)
}

///|
/// Plugin host trait
/// Manages plugin lifecycle and communication
pub(open) trait PluginHost {
  /// Load plugins from directory
  load_plugins(Self, path~ : String) -> Unit raise

  /// Start a plugin by ID
  start_plugin(Self, id~ : String) -> Unit raise

  /// Stop a plugin by ID
  stop_plugin(Self, id~ : String) -> Unit raise

  /// Get plugin status
  get_status(Self, id~ : String) -> PluginStatus raise

  /// List all plugins
  list_plugins(Self) -> Array[PluginManifest]

  /// Send a JSON-RPC request to a plugin
  send_request(
    Self,
    plugin_id~ : String,
    request~ : JsonRpcRequest,
  ) -> JsonRpcResponse raise
}

///|
/// Plugin message handler trait
/// Implemented by plugins to handle incoming messages
pub(open) trait PluginMessageHandler {
  /// Handle an incoming JSON-RPC request
  handle_request(Self, JsonRpcRequest) -> JsonRpcResponse
}

///|
/// Channel plugin methods (JSON-RPC method names)
pub fn plugin_method_connect() -> String {
  "connect"
}

pub fn plugin_method_disconnect() -> String {
  "disconnect"
}

pub fn plugin_method_send() -> String {
  "send"
}

pub fn plugin_method_receive() -> String {
  "receive"
}

pub fn plugin_method_status() -> String {
  "status"
}

pub fn plugin_method_message_received() -> String {
  "message_received"
}
