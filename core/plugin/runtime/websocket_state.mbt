///|
/// WebSocket connection state

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
