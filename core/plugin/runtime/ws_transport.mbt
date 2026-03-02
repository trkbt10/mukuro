///|
/// Native WebSocket Transport Handler
/// Implements PluginTransportHandler trait
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
  mut state : WebSocketState
  /// Request ID counter
  mut request_id : Int
  /// Message queue for incoming messages
  message_queue : MessageQueue
  /// Reconnect attempt counter
  mut reconnect_attempts : Int
}

///|
/// Create a new native WebSocket transport handler
pub fn NativeWebSocketTransportHandler::new(
  plugin_id~ : String,
  config~ : @interfaces.PluginWebSocketConfig,
) -> NativeWebSocketTransportHandler {
  let client = NativeWebSocketClient::new(
    url=config.url,
    headers=config.headers,
  )
  {
    plugin_id,
    config,
    client,
    state: WebSocketState::Disconnected,
    request_id: 0,
    message_queue: MessageQueue::new(),
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
fn NativeWebSocketTransportHandler::is_active_impl(
  self : NativeWebSocketTransportHandler,
) -> Bool {
  match self.state {
    WebSocketState::Connected => self.client.is_connected()
    _ => false
  }
}

// ============================================================================
// PluginTransportHandler trait implementation
// ============================================================================

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with start(
  self,
) {
  match self.state {
    WebSocketState::Connected
    | WebSocketState::Connecting =>
      raise @interfaces.TransportError::AlreadyStarted
    _ => {
      self.state = WebSocketState::Connecting
      self.client.connect() catch {
        e => {
          self.state = WebSocketState::Error(
            "Connection failed",
          )
          raise @interfaces.TransportError::ConnectionFailed(
            ws_error_message(e),
          )
        }
      }
      self.state = WebSocketState::Connected
      self.reconnect_attempts = 0
    }
  }
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with stop(
  self,
) {
  match self.state {
    WebSocketState::Connected
    | WebSocketState::Connecting => {
      self.client.close()
      self.state = WebSocketState::Closed
    }
    _ => self.state = WebSocketState::Closed
  }
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with is_active(
  self,
) {
  self.is_active_impl()
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with send_request(
  self,
  request,
) {
  if not(self.is_active_impl()) {
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
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with send_notification(
  self,
  request,
) {
  if not(self.is_active_impl()) {
    raise @interfaces.TransportError::NotStarted
  }
  let request_json = request.to_json().stringify()
  self.client.send_text(request_json) catch {
    e => raise @interfaces.TransportError::SendFailed(ws_error_message(e))
  }
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with try_receive(
  self,
) {
  self.message_queue.pop()
}

///|
pub impl @interfaces.PluginTransportHandler for NativeWebSocketTransportHandler with on_message(
  self,
  callback,
) {
  self.message_queue.set_callback(callback)
}
