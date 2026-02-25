///|
/// Native WebSocket Transport Handler
/// Implements PluginTransportHandler trait for sync contexts
///
/// IMPORTANT: The sync trait methods use @async.with_event_loop which
/// only works correctly when called from async fn main context.
/// For testing, use async tests with NativeWebSocketClient directly.

///|
/// Convert WebSocketClientError to string description
fn ws_error_message(err : WebSocketClientError) -> String {
  match err {
    WebSocketClientError::ConnectionFailed(msg) => "Connection failed: \{msg}"
    WebSocketClientError::SendFailed(msg) => "Send failed: \{msg}"
    WebSocketClientError::ReceiveFailed(msg) => "Receive failed: \{msg}"
    WebSocketClientError::Closed => "Connection closed"
    WebSocketClientError::Timeout => "Timeout"
  }
}

///|
/// Native WebSocket transport handler for plugins
pub struct NativeWebSocketTransportHandler {
  /// Plugin ID
  plugin_id : String
  /// WebSocket configuration
  config : @interfaces.PluginWebSocketConfig
  /// WebSocket client
  client : NativeWebSocketClient
  /// Connection state
  mut state : @plugin_transport.WebSocketState
  /// Request ID counter
  mut request_id : Int
  /// Message queue for incoming messages
  message_queue : @plugin_transport.MessageQueue
  /// Reconnect attempt counter
  mut reconnect_attempts : Int
}

///|
/// Create a new native WebSocket transport handler
pub fn NativeWebSocketTransportHandler::new(
  plugin_id~ : String,
  config~ : @interfaces.PluginWebSocketConfig,
) -> NativeWebSocketTransportHandler {
  let client = NativeWebSocketClient::new(url=config.url, headers=config.headers)
  {
    plugin_id,
    config,
    client,
    state: @plugin_transport.WebSocketState::Disconnected,
    request_id: 0,
    message_queue: @plugin_transport.MessageQueue::new(),
    reconnect_attempts: 0,
  }
}

///|
/// Get next request ID
fn NativeWebSocketTransportHandler::next_request_id(
  self : NativeWebSocketTransportHandler,
) -> Int {
  self.request_id = self.request_id + 1
  self.request_id
}

///|
/// Async start - use this directly in async contexts
pub async fn NativeWebSocketTransportHandler::start_async(
  self : NativeWebSocketTransportHandler,
) -> Unit raise @interfaces.TransportError {
  match self.state {
    @plugin_transport.WebSocketState::Connected |
    @plugin_transport.WebSocketState::Connecting =>
      raise @interfaces.TransportError::AlreadyStarted
    _ => {
      self.state = @plugin_transport.WebSocketState::Connecting
      self.client.connect() catch {
        e => {
          self.state = @plugin_transport.WebSocketState::Error("Connection failed")
          raise @interfaces.TransportError::ConnectionFailed(ws_error_message(e))
        }
      }
      self.state = @plugin_transport.WebSocketState::Connected
      self.reconnect_attempts = 0
    }
  }
}

///|
/// Async stop - use this directly in async contexts
pub async fn NativeWebSocketTransportHandler::stop_async(
  self : NativeWebSocketTransportHandler,
) -> Unit {
  match self.state {
    @plugin_transport.WebSocketState::Connected |
    @plugin_transport.WebSocketState::Connecting => {
      self.client.close()
      self.state = @plugin_transport.WebSocketState::Closed
    }
    _ => self.state = @plugin_transport.WebSocketState::Closed
  }
}

///|
/// Check if transport is active
pub fn NativeWebSocketTransportHandler::is_active(
  self : NativeWebSocketTransportHandler,
) -> Bool {
  match self.state {
    @plugin_transport.WebSocketState::Connected => self.client.is_connected()
    _ => false
  }
}

///|
/// Async send request - use this directly in async contexts
pub async fn NativeWebSocketTransportHandler::send_request_async(
  self : NativeWebSocketTransportHandler,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse raise @interfaces.TransportError {
  if not(self.is_active()) {
    raise @interfaces.TransportError::NotStarted
  }
  let actual_request = match request.id {
    Some(_) => request
    None =>
      @interfaces.JsonRpcRequest::new(
        rpc_method=request.rpc_method,
        params=request.params,
        id=Some(self.next_request_id()),
      )
  }
  self.client.send_jsonrpc_request(actual_request) catch {
    e => raise @interfaces.TransportError::SendFailed(ws_error_message(e))
  }
}

///|
/// Async send notification - use this directly in async contexts
pub async fn NativeWebSocketTransportHandler::send_notification_async(
  self : NativeWebSocketTransportHandler,
  request : @interfaces.JsonRpcRequest,
) -> Unit raise @interfaces.TransportError {
  if not(self.is_active()) {
    raise @interfaces.TransportError::NotStarted
  }
  let request_json = request.to_json().stringify()
  self.client.send_text(request_json) catch {
    e => raise @interfaces.TransportError::SendFailed(ws_error_message(e))
  }
}

///|
/// Try to receive incoming message (non-blocking)
pub fn NativeWebSocketTransportHandler::try_receive(
  self : NativeWebSocketTransportHandler,
) -> @interfaces.JsonRpcRequest? {
  self.message_queue.pop()
}

///|
/// Register message callback
pub fn NativeWebSocketTransportHandler::on_message(
  self : NativeWebSocketTransportHandler,
  callback : (@interfaces.JsonRpcRequest) -> Unit,
) -> Unit {
  self.message_queue.set_callback(callback)
}

// ============================================================================
// PluginTransportHandler trait implementation (sync wrapper)
// NOTE: These use @async.with_event_loop and only work in async fn main context
// ============================================================================

///|
/// Sync start - wraps async with event loop
/// Only use from async fn main context
pub fn NativeWebSocketTransportHandler::start(
  self : NativeWebSocketTransportHandler,
) -> Unit raise @interfaces.TransportError {
  let handler = self
  @async.with_event_loop((_group) => { handler.start_async() }) catch {
    @interfaces.TransportError::ConnectionFailed(msg) =>
      raise @interfaces.TransportError::ConnectionFailed(msg)
    @interfaces.TransportError::AlreadyStarted =>
      raise @interfaces.TransportError::AlreadyStarted
    _ => raise @interfaces.TransportError::ConnectionFailed("Unknown error")
  }
}

///|
/// Sync stop - wraps async with event loop
pub fn NativeWebSocketTransportHandler::stop(
  self : NativeWebSocketTransportHandler,
) -> Unit raise @interfaces.TransportError {
  let handler = self
  @async.with_event_loop((_group) => { handler.stop_async() }) catch {
    _ => ()
  }
}

///|
/// Sync send request - wraps async with event loop
pub fn NativeWebSocketTransportHandler::send_request(
  self : NativeWebSocketTransportHandler,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse raise @interfaces.TransportError {
  let handler = self
  let mut result : @interfaces.JsonRpcResponse? = None
  @async.with_event_loop((_group) => {
    let response = handler.send_request_async(request)
    result = Some(response)
  }) catch {
    @interfaces.TransportError::SendFailed(msg) =>
      raise @interfaces.TransportError::SendFailed(msg)
    @interfaces.TransportError::NotStarted =>
      raise @interfaces.TransportError::NotStarted
    _ => raise @interfaces.TransportError::SendFailed("Unknown error")
  }
  match result {
    Some(r) => r
    None => raise @interfaces.TransportError::SendFailed("No response")
  }
}

///|
/// Sync send notification - wraps async with event loop
pub fn NativeWebSocketTransportHandler::send_notification(
  self : NativeWebSocketTransportHandler,
  request : @interfaces.JsonRpcRequest,
) -> Unit raise @interfaces.TransportError {
  let handler = self
  @async.with_event_loop((_group) => { handler.send_notification_async(request) }) catch {
    _ => ()
  }
}

///|
/// Implementation of PluginTransportHandler trait
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with start(
  self,
) {
  NativeWebSocketTransportHandler::start(self)
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with stop(
  self,
) {
  NativeWebSocketTransportHandler::stop(self)
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with is_active(
  self,
) {
  NativeWebSocketTransportHandler::is_active(self)
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with send_request(
  self,
  request,
) {
  NativeWebSocketTransportHandler::send_request(self, request)
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with send_notification(
  self,
  request,
) {
  NativeWebSocketTransportHandler::send_notification(self, request)
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with try_receive(
  self,
) {
  NativeWebSocketTransportHandler::try_receive(self)
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with on_message(
  self,
  callback,
) {
  NativeWebSocketTransportHandler::on_message(self, callback)
}
