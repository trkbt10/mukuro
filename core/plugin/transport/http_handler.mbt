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
  /// Shared message queue for incoming messages
  message_queue : MessageQueue
  /// HTTP client for making requests (optional, for actual HTTP calls)
  mut http_client : &@interfaces.HttpClient?
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
    http_client=None,
  )
}

///|
/// Create a new HTTP transport handler with an HTTP client
pub fn HttpTransportHandler::with_client(
  plugin_id~ : String,
  config~ : @interfaces.PluginHttpConfig,
  auth_token~ : String?,
  token_header~ : String,
  http_client~ : &@interfaces.HttpClient,
) -> HttpTransportHandler {
  HttpTransportHandler::with_tls(
    plugin_id~,
    config~,
    auth_token~,
    token_header~,
    tls_config=None,
    http_client=Some(http_client),
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
  http_client~ : &@interfaces.HttpClient?,
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
    message_queue: MessageQueue::new(),
    http_client,
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
/// Set HTTP client for making requests
pub fn HttpTransportHandler::set_http_client(
  self : HttpTransportHandler,
  client : &@interfaces.HttpClient,
) -> Unit {
  self.http_client = Some(client)
}

///|
/// Check if HTTP client is available
pub fn HttpTransportHandler::has_http_client(
  self : HttpTransportHandler,
) -> Bool {
  self.http_client is Some(_)
}

///|
/// Get the base URL
pub fn HttpTransportHandler::get_base_url(self : HttpTransportHandler) -> String {
  self.base_url
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
pub impl @interfaces.PluginTransportHandler for HttpTransportHandler with send_request(
  self,
  request,
) {
  guard self.is_active() else { raise @interfaces.TransportError::NotStarted }
  // Get URL for the method - always use base_url for JSON-RPC
  let url = self.base_url
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
  // If we have an HTTP client, make the actual request
  match self.http_client {
    Some(client) => {
      let headers = self.build_headers()
      let body_json = actual_request.to_json()
      let body_str = body_json.stringify()
      let body_bytes = Bytes::from_iter(
        body_str.iter().map(fn(c) { c.to_int().land(0xFF).to_byte() }),
      )
      let response = client.post(url~, body=body_bytes, headers~) catch {
        e =>
          raise @interfaces.TransportError::SendFailed(
            "HTTP request failed: \{e}",
          )
      }
      // Parse the response body using UTF-8 decoding
      let response_body = @utf8.decode(response.body) catch {
        _ =>
          raise @interfaces.TransportError::SendFailed(
            "Invalid UTF-8 in response body",
          )
      }
      match parse_jsonrpc_response(response_body) {
        Some(jsonrpc_response) => jsonrpc_response
        None =>
          raise @interfaces.TransportError::SendFailed(
            "Invalid JSON-RPC response: \{response_body}",
          )
      }
    }
    None =>
      // No HTTP client available - return placeholder
      @interfaces.JsonRpcResponse::success(
        result=Json::object({ "pending": true, "url": url }),
        id=actual_request.id,
      )
  }
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
  self.message_queue.pop()
}

///|
/// Register message callback
pub impl @interfaces.PluginTransportHandler for HttpTransportHandler with on_message(
  self,
  callback,
) {
  self.message_queue.set_callback(callback)
}

///|
/// Queue an incoming message (called by webhook handler)
pub fn HttpTransportHandler::queue_incoming(
  self : HttpTransportHandler,
  request : @interfaces.JsonRpcRequest,
) -> Unit {
  self.message_queue.push(request)
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
