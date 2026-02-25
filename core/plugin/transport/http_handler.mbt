///|
/// HTTP Transport Handler
/// Implements PluginTransportHandler for HTTP-based plugin communication

///|
/// HTTP transport handler for plugins
pub struct HttpTransportHandler {
  /// Plugin ID
  plugin_id : String
  /// Base URL for the plugin HTTP server
  base_url : String
  /// HTTP configuration
  config : @interfaces.PluginHttpConfig
  /// TLS configuration
  tls_config : @interfaces.PluginTlsConfig?
  /// Transport state
  mut state : @interfaces.TransportState
  /// Pending requests (id -> timestamp)
  pending_requests : Map[Int, @interfaces.PendingRequest]
  /// Request ID counter
  mut request_id : Int
  /// Auth token to include in requests
  auth_token : String?
  /// Token header name
  token_header : String
  /// Message callback
  mut on_message_callback : ((@interfaces.JsonRpcRequest) -> Unit)?
  /// Incoming message queue
  incoming_queue : Array[@interfaces.JsonRpcRequest]
}

///|
/// Create a new HTTP transport handler
pub fn HttpTransportHandler::new(
  plugin_id~ : String,
  config~ : @interfaces.PluginHttpConfig,
  auth_token~ : String?,
  token_header~ : String,
) -> HttpTransportHandler {
  HttpTransportHandler::with_tls(
    plugin_id~,
    config~,
    auth_token~,
    token_header~,
    tls_config=None,
  )
}

///|
/// Create a new HTTP transport handler with TLS configuration
pub fn HttpTransportHandler::with_tls(
  plugin_id~ : String,
  config~ : @interfaces.PluginHttpConfig,
  auth_token~ : String?,
  token_header~ : String,
  tls_config~ : @interfaces.PluginTlsConfig?,
) -> HttpTransportHandler {
  let base_url = match config.base_url {
    Some(url) => url
    None => {
      // Determine protocol based on TLS config
      let protocol = match tls_config {
        Some(tls) if tls.enabled => "https"
        _ => "http"
      }
      "\{protocol}://localhost:\{config.port}"
    }
  }
  {
    plugin_id,
    base_url,
    config,
    tls_config,
    state: @interfaces.TransportState::Disconnected,
    pending_requests: {},
    request_id: 0,
    auth_token,
    token_header,
    on_message_callback: None,
    incoming_queue: [],
  }
}

///|
/// Get next request ID
fn HttpTransportHandler::next_request_id(self : HttpTransportHandler) -> Int {
  self.request_id = self.request_id + 1
  self.request_id
}

///|
/// Build request URL for an endpoint
pub fn HttpTransportHandler::build_url(
  self : HttpTransportHandler,
  endpoint_name : String,
) -> String? {
  match self.config.endpoints.get(endpoint_name) {
    Some(endpoint) => Some("\{self.base_url}\{endpoint.path}")
    None =>
      // Default to base_url + method name
      Some("\{self.base_url}/\{endpoint_name}")
  }
}

///|
/// Build HTTP headers for request
pub fn HttpTransportHandler::build_headers(
  self : HttpTransportHandler,
) -> Map[String, String] {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  match self.auth_token {
    Some(token) => headers[self.token_header] = "Bearer \{token}"
    None => ()
  }
  headers
}

///|
/// Check if TLS is enabled
pub fn HttpTransportHandler::is_tls_enabled(
  self : HttpTransportHandler,
) -> Bool {
  match self.tls_config {
    Some(tls) => tls.enabled
    None => false
  }
}

///|
/// Get TLS configuration
pub fn HttpTransportHandler::get_tls_config(
  self : HttpTransportHandler,
) -> @interfaces.PluginTlsConfig? {
  self.tls_config
}

///|
/// Check if base URL uses HTTPS
pub fn HttpTransportHandler::is_https(self : HttpTransportHandler) -> Bool {
  self.base_url.has_prefix("https://")
}

///|
/// Start the transport (for HTTP this just marks as connected)
pub fn HttpTransportHandler::start(self : HttpTransportHandler) -> Unit raise {
  match self.state {
    @interfaces.TransportState::Connected
    | @interfaces.TransportState::Connecting =>
      raise @interfaces.TransportError::AlreadyStarted
    _ => self.state = @interfaces.TransportState::Connected
  }
}

///|
/// Stop the transport
pub fn HttpTransportHandler::stop(self : HttpTransportHandler) -> Unit raise {
  self.state = @interfaces.TransportState::Stopped
  self.pending_requests.clear()
}

///|
/// Check if transport is active
pub fn HttpTransportHandler::is_active(self : HttpTransportHandler) -> Bool {
  match self.state {
    @interfaces.TransportState::Connected => true
    _ => false
  }
}

///|
/// Implementation of PluginTransportHandler trait
pub impl @interfaces.PluginTransportHandler for HttpTransportHandler with start(
  self,
) {
  HttpTransportHandler::start(self)
}

///|
pub impl @interfaces.PluginTransportHandler for HttpTransportHandler with stop(
  self,
) {
  HttpTransportHandler::stop(self)
}

///|
pub impl @interfaces.PluginTransportHandler for HttpTransportHandler with is_active(
  self,
) {
  HttpTransportHandler::is_active(self)
}

///|
/// Send a JSON-RPC request (synchronous HTTP POST)
/// Note: This requires an HTTP client implementation
pub impl @interfaces.PluginTransportHandler for HttpTransportHandler with send_request(
  self,
  request,
) {
  guard self.is_active() else { raise @interfaces.TransportError::NotStarted }
  // Get URL for the method
  let url = match self.build_url(request.rpc_method) {
    Some(u) => u
    None =>
      raise @interfaces.TransportError::SendFailed(
        "No URL for method: \{request.rpc_method}",
      )
  }
  // Build request with ID if not present
  let actual_request = match request.id {
    Some(_) => request
    None =>
      @interfaces.JsonRpcRequest::new(
        rpc_method=request.rpc_method,
        params=request.params,
        id=Some(self.next_request_id()),
      )
  }
  // For now, return a placeholder response since we need to integrate with
  // actual HTTP client (either sync or async)
  // In Phase 7, this will be properly wired up with the HTTP client
  @interfaces.JsonRpcResponse::success(
    result=Json::object({ "pending": true, "url": url }),
    id=actual_request.id,
  )
}

///|
/// Send a notification (no response expected)
pub impl @interfaces.PluginTransportHandler for HttpTransportHandler with send_notification(
  self,
  request,
) {
  guard self.is_active() else { raise @interfaces.TransportError::NotStarted }
  // Just prepare the request - actual sending happens in Phase 7
  let _ = self.build_url(request.rpc_method)
}

///|
/// Try to receive incoming message (non-blocking)
pub impl @interfaces.PluginTransportHandler for HttpTransportHandler with try_receive(
  self,
) {
  if self.incoming_queue.length() > 0 {
    Some(self.incoming_queue.remove(0))
  } else {
    None
  }
}

///|
/// Register message callback
pub impl @interfaces.PluginTransportHandler for HttpTransportHandler with on_message(
  self,
  callback,
) {
  self.on_message_callback = Some(callback)
}

///|
/// Queue an incoming message (called by webhook handler)
pub fn HttpTransportHandler::queue_incoming(
  self : HttpTransportHandler,
  request : @interfaces.JsonRpcRequest,
) -> Unit {
  self.incoming_queue.push(request)
  match self.on_message_callback {
    Some(callback) => callback(request)
    None => ()
  }
}

///|
/// Create a JSON-RPC request for plugin method
pub fn HttpTransportHandler::create_request(
  self : HttpTransportHandler,
  rpc_method~ : String,
  params~ : Json?,
) -> @interfaces.JsonRpcRequest {
  @interfaces.JsonRpcRequest::new(
    rpc_method~,
    params~,
    id=Some(self.next_request_id()),
  )
}

///|
/// Parse JSON-RPC response from HTTP response body
pub fn parse_jsonrpc_response(body : String) -> @interfaces.JsonRpcResponse? {
  let json = @json.parse(body) catch { _ => return None }
  match json {
    { "jsonrpc": String(ver), .. } if ver == "2.0" => {
      let result = match json {
        { "result": r, .. } => Some(r)
        _ => None
      }
      let error : @interfaces.JsonRpcError? = match json {
        { "error": Object(e), .. } => {
          let code = match e.get("code") {
            Some(Number(n, ..)) => n.to_int()
            _ => -32603
          }
          let message = match e.get("message") {
            Some(String(m)) => m
            _ => "Unknown error"
          }
          let data = e.get("data")
          Some({ code, message, data })
        }
        _ => None
      }
      let id = match json {
        { "id": Number(i, ..), .. } => Some(i.to_int())
        _ => None
      }
      Some({ jsonrpc: ver, result, error, id })
    }
    _ => None
  }
}
