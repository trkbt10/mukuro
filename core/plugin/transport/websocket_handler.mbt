///|
/// WebSocket Transport Handler
/// Implements PluginTransportHandler for WebSocket-based plugin communication
/// Uses bidirectional WebSocket connections for real-time communication

///|
/// WebSocket connection state
pub(all) enum WebSocketState {
  /// Not connected
  Disconnected
  /// Currently connecting
  Connecting
  /// Connected and active
  Connected
  /// Reconnecting after connection loss
  Reconnecting
  /// Closed (intentionally)
  Closed
  /// Error state
  Error(String)
}

///|
/// WebSocket transport handler for plugins
pub struct WebSocketTransportHandler {
  /// Plugin ID
  plugin_id : String
  /// WebSocket configuration
  config : @interfaces.PluginWebSocketConfig
  /// Connection state
  mut state : WebSocketState
  /// Pending requests (id -> timestamp)
  pending_requests : Map[Int, @interfaces.PendingRequest]
  /// Request ID counter
  mut request_id : Int
  /// Shared message queue for incoming messages
  message_queue : MessageQueue
  /// Reconnect attempt counter
  mut reconnect_attempts : Int
  /// Last activity timestamp
  mut last_activity_time : Int64
  /// Last heartbeat sent timestamp
  mut last_heartbeat_time : Int64
}

///|
/// Create a new WebSocket transport handler
pub fn WebSocketTransportHandler::new(
  plugin_id~ : String,
  config~ : @interfaces.PluginWebSocketConfig,
) -> WebSocketTransportHandler {
  {
    plugin_id,
    config,
    state: WebSocketState::Disconnected,
    pending_requests: {},
    request_id: 0,
    message_queue: MessageQueue::new(),
    reconnect_attempts: 0,
    last_activity_time: 0L,
    last_heartbeat_time: 0L,
  }
}

///|
/// Get next request ID
fn WebSocketTransportHandler::next_request_id(
  self : WebSocketTransportHandler,
) -> Int {
  self.request_id = self.request_id + 1
  self.request_id
}

///|
/// Get WebSocket URL with protocol conversion
pub fn WebSocketTransportHandler::get_url(
  self : WebSocketTransportHandler,
) -> String {
  self.config.url
}

///|
/// Get additional headers for WebSocket connection
pub fn WebSocketTransportHandler::get_headers(
  self : WebSocketTransportHandler,
) -> Map[String, String] {
  let headers : Map[String, String] = {}
  for key, value in self.config.headers {
    headers[key] = value
  }
  headers
}

///|
/// Check if reconnection is enabled
pub fn WebSocketTransportHandler::is_reconnect_enabled(
  self : WebSocketTransportHandler,
) -> Bool {
  self.config.reconnect.enabled
}

///|
/// Check if should attempt reconnect
pub fn WebSocketTransportHandler::should_reconnect(
  self : WebSocketTransportHandler,
) -> Bool {
  self.config.reconnect.enabled &&
  self.reconnect_attempts < self.config.reconnect.max_attempts
}

///|
/// Get reconnect delay in milliseconds (with exponential backoff)
pub fn WebSocketTransportHandler::get_reconnect_delay(
  self : WebSocketTransportHandler,
) -> Int {
  let base = self.config.reconnect.base_delay_ms
  let max = self.config.reconnect.max_delay_ms
  // Exponential backoff: base * 2^attempts
  let multiplier = 1 << self.reconnect_attempts
  let delay = base * multiplier
  if delay > max {
    max
  } else {
    delay
  }
}

///|
/// Reset reconnect counter
pub fn WebSocketTransportHandler::reset_reconnect_counter(
  self : WebSocketTransportHandler,
) -> Unit {
  self.reconnect_attempts = 0
}

///|
/// Increment reconnect counter
pub fn WebSocketTransportHandler::increment_reconnect_counter(
  self : WebSocketTransportHandler,
) -> Unit {
  self.reconnect_attempts = self.reconnect_attempts + 1
}

///|
/// Check if heartbeat is needed
pub fn WebSocketTransportHandler::needs_heartbeat(
  self : WebSocketTransportHandler,
  current_time : Int64,
) -> Bool {
  if self.config.heartbeat_interval_ms == 0 {
    return false
  }
  let interval = self.config.heartbeat_interval_ms.to_int64()
  current_time - self.last_heartbeat_time > interval
}

///|
/// Update last heartbeat time
pub fn WebSocketTransportHandler::update_heartbeat_time(
  self : WebSocketTransportHandler,
  time : Int64,
) -> Unit {
  self.last_heartbeat_time = time
}

///|
/// Update last activity time
pub fn WebSocketTransportHandler::update_activity_time(
  self : WebSocketTransportHandler,
  time : Int64,
) -> Unit {
  self.last_activity_time = time
}

///|
/// Start the transport (establish WebSocket connection)
/// Note: Actual WebSocket connection will be integrated in Phase 7
pub fn WebSocketTransportHandler::start(
  self : WebSocketTransportHandler,
) -> Unit raise {
  match self.state {
    WebSocketState::Connected | WebSocketState::Connecting =>
      raise @interfaces.TransportError::AlreadyStarted
    _ => {
      self.state = WebSocketState::Connecting
      // In Phase 7, this will use @websocket.Conn::connect
      // For now, mark as connected to allow testing
      self.state = WebSocketState::Connected
    }
  }
}

///|
/// Stop the transport (close WebSocket connection)
pub fn WebSocketTransportHandler::stop(
  self : WebSocketTransportHandler,
) -> Unit {
  match self.state {
    WebSocketState::Connected | WebSocketState::Connecting => {
      // In Phase 7, send close frame and close connection
      self.state = WebSocketState::Closed
      self.pending_requests.clear()
    }
    _ => self.state = WebSocketState::Closed
  }
}

///|
/// Check if transport is active
pub fn WebSocketTransportHandler::is_active(
  self : WebSocketTransportHandler,
) -> Bool {
  match self.state {
    WebSocketState::Connected => true
    _ => false
  }
}

///|
/// Implementation of PluginTransportHandler trait (async)
pub impl @interfaces.PluginTransportHandler for WebSocketTransportHandler with start(
  self,
) {
  WebSocketTransportHandler::start(self)
}

///|
pub impl @interfaces.PluginTransportHandler for WebSocketTransportHandler with stop(
  self,
) {
  WebSocketTransportHandler::stop(self)
}

///|
pub impl @interfaces.PluginTransportHandler for WebSocketTransportHandler with is_active(
  self,
) {
  WebSocketTransportHandler::is_active(self)
}

///|
/// Send a JSON-RPC request (async)
/// Note: Actual WebSocket sending will be implemented in Phase 7
pub impl @interfaces.PluginTransportHandler for WebSocketTransportHandler with send_request(
  self,
  request,
) {
  guard self.is_active() else { raise @interfaces.TransportError::NotStarted }
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
  // In Phase 7, send via WebSocket conn.send_text()
  // For now, return a placeholder response
  @interfaces.JsonRpcResponse::success(
    result=Json::object({ "pending": true, "transport": "websocket" }),
    id=actual_request.id,
  )
}

///|
/// Send a notification (no response expected) (async)
pub impl @interfaces.PluginTransportHandler for WebSocketTransportHandler with send_notification(
  self,
  request,
) {
  guard self.is_active() else { raise @interfaces.TransportError::NotStarted }
  // In Phase 7, send via WebSocket
  ignore(request)
}

///|
/// Try to receive incoming message (non-blocking)
pub impl @interfaces.PluginTransportHandler for WebSocketTransportHandler with try_receive(
  self,
) {
  self.message_queue.pop()
}

///|
/// Register message callback
pub impl @interfaces.PluginTransportHandler for WebSocketTransportHandler with on_message(
  self,
  callback,
) {
  self.message_queue.set_callback(callback)
}

///|
/// Queue an incoming message (called when receiving from WebSocket)
pub fn WebSocketTransportHandler::queue_incoming(
  self : WebSocketTransportHandler,
  request : @interfaces.JsonRpcRequest,
) -> Unit {
  self.message_queue.push(request)
}

///|
/// Process received WebSocket message
/// Parses JSON-RPC and either queues as incoming request or matches to pending response
pub fn WebSocketTransportHandler::process_message(
  self : WebSocketTransportHandler,
  message : String,
) -> Unit {
  let trimmed = message.trim()
  if trimmed.length() == 0 {
    return
  }
  let json = @json.parse(trimmed) catch { _ => return }
  // Check if it's a response (has result or error)
  match json {
    { "result": _, .. } | { "error": _, .. } =>
      // It's a response
      match parse_ws_response(json) {
        Some(response) =>
          match response.id {
            Some(id) =>
              // Remove from pending
              self.pending_requests.remove(id)
            // Response handling would be done via callback in async implementation
            None => ()
          }
        None => ()
      }
    { "method": _, .. } =>
      // It's a request
      match @interfaces.JsonRpcRequest::from_json(json) {
        Some(request) => self.queue_incoming(request)
        None => ()
      }
    _ => ()
  }
}

///|
/// Parse JSON as JSON-RPC response
fn parse_ws_response(json : Json) -> @interfaces.JsonRpcResponse? {
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

///|
/// Create heartbeat (ping) request
pub fn WebSocketTransportHandler::create_heartbeat_request(
  self : WebSocketTransportHandler,
) -> @interfaces.JsonRpcRequest {
  @interfaces.JsonRpcRequest::new(
    rpc_method="ping",
    params=Some(
      Json::object({
        "timestamp": Json::number(self.last_heartbeat_time.to_double()),
      }),
    ),
    id=Some(self.next_request_id()),
  )
}

///|
/// Handle connection error
pub fn WebSocketTransportHandler::handle_connection_error(
  self : WebSocketTransportHandler,
  error : String,
) -> Unit {
  self.state = WebSocketState::Error(error)
  if self.should_reconnect() {
    self.state = WebSocketState::Reconnecting
  }
}

///|
/// Handle successful connection
pub fn WebSocketTransportHandler::handle_connected(
  self : WebSocketTransportHandler,
) -> Unit {
  self.state = WebSocketState::Connected
  self.reset_reconnect_counter()
}

///|
/// Handle disconnection
pub fn WebSocketTransportHandler::handle_disconnected(
  self : WebSocketTransportHandler,
) -> Unit {
  if self.should_reconnect() {
    self.state = WebSocketState::Reconnecting
    self.increment_reconnect_counter()
  } else {
    self.state = WebSocketState::Disconnected
  }
}
