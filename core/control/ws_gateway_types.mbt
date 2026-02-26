///|
/// WebSocket Gateway Types
/// Type definitions for WebSocket gateway control plane

///|
/// Gateway events for WebSocket broadcasting
pub(all) enum GatewayEvent {
  /// Gateway state changed
  StateChanged(old~ : @interfaces.GatewayState, new~ : @interfaces.GatewayState)
  /// Message received from channel
  MessageReceived(envelope~ : @types.InboundEnvelope)
  /// Message sent to channel
  MessageSent(message~ : @types.OutboundMessage)
  /// Channel connected
  ChannelConnected(channel~ : String)
  /// Channel disconnected
  ChannelDisconnected(channel~ : String)
  /// Error occurred
  Error(error~ : String)
}

///|
/// WebSocket client connection info
pub(all) struct WsClientConnection {
  /// Client ID
  id : String
  /// Authentication state
  mut authenticated : Bool
  /// Auth context (if authenticated)
  mut auth_context : @interfaces.AuthContext?
  /// Subscribed event types
  subscriptions : Array[String]
  /// Connection timestamp
  connected_at : Int64
}

///|
/// Create new client connection
pub fn WsClientConnection::new(
  id : String,
  connected_at : Int64,
) -> WsClientConnection {
  {
    id,
    authenticated: false,
    auth_context: None,
    subscriptions: [],
    connected_at,
  }
}
