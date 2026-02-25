///|
/// Webhook server for receiving messages from plugins
/// This provides the HTTP endpoint that plugins POST to
pub struct WebhookServer {
  /// Plugin host
  host : PluginHostImpl
  /// Server port
  port : Int
  /// Registered routes (path -> plugin_id)
  routes : Map[String, String]
  /// Is server running
  mut is_running : Bool
}

///|
/// Create a new webhook server
pub fn WebhookServer::new(
  host : PluginHostImpl,
  port~ : Int,
) -> WebhookServer {
  { host, port, routes: {}, is_running: false }
}

///|
/// Register a webhook route for a plugin
pub fn WebhookServer::register_route(
  self : WebhookServer,
  path : String,
  plugin_id : String,
) -> Unit {
  self.routes[path] = plugin_id
}

///|
/// Get plugin ID for a path
pub fn WebhookServer::get_plugin_for_path(
  self : WebhookServer,
  path : String,
) -> String? {
  self.routes.get(path)
}

///|
/// Handle an incoming webhook request
/// Returns JSON-RPC response as JSON string
pub fn WebhookServer::handle_request(
  self : WebhookServer,
  path : String,
  body : String,
) -> String {
  // Find plugin for this path
  let plugin_id = match self.get_plugin_for_path(path) {
    Some(id) => id
    None => {
      // Try default webhook path
      if path.starts_with("/webhook/") {
        path.substring(start=9)
      } else {
        // Return error response
        let response = @interfaces.JsonRpcResponse::error(
          code=404,
          message="Plugin not found for path: \{path}",
          id=None,
        )
        return response.to_json().stringify()
      }
    }
  }
  // Parse JSON-RPC request
  let json = @json.parse(body) catch {
    _ => {
      let response = @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_parse_error(),
        message="Invalid JSON",
        id=None,
      )
      return response.to_json().stringify()
    }
  }
  let request = match @interfaces.JsonRpcRequest::from_json(json) {
    Some(req) => req
    None => {
      let response = @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_request(),
        message="Invalid JSON-RPC request",
        id=None,
      )
      return response.to_json().stringify()
    }
  }
  // Handle the request
  let response = self.host.handle_webhook(plugin_id, request)
  response.to_json().stringify()
}

///|
/// Handle a simple message POST (non-JSON-RPC format)
/// Converts to JSON-RPC internally
pub fn WebhookServer::handle_simple_message(
  self : WebhookServer,
  plugin_id : String,
  body : String,
) -> String {
  // Parse body as JSON
  let json = @json.parse(body) catch {
    _ => {
      let response = @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_parse_error(),
        message="Invalid JSON",
        id=None,
      )
      return response.to_json().stringify()
    }
  }
  // Create JSON-RPC request
  let request = @interfaces.JsonRpcRequest::new(
    rpc_method="message_received",
    params=Some(json),
    id=Some(1),
  )
  // Handle the request
  let response = self.host.handle_webhook(plugin_id, request)
  response.to_json().stringify()
}

///|
/// Get list of registered routes
pub fn WebhookServer::list_routes(self : WebhookServer) -> Array[String] {
  let routes : Array[String] = []
  for path, _ in self.routes {
    routes.push(path)
  }
  routes
}

///|
/// Check if server is running
pub fn WebhookServer::running(self : WebhookServer) -> Bool {
  self.is_running
}

///|
/// Set server running state
pub fn WebhookServer::set_running(self : WebhookServer, running : Bool) -> Unit {
  self.is_running = running
}
