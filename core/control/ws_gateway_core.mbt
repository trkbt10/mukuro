///|
/// WebSocket Gateway Core
/// Handler structure, client lifecycle, and authentication

///|
/// WebSocket Gateway Handler
pub struct WsGatewayHandler {
  /// Gateway reference
  gateway : Gateway?
  /// Connected clients
  clients : Map[String, WsClientConnection]
  /// Message buffer for each client
  message_buffers : Map[String, Array[String]]
  /// Event handlers
  event_handlers : Array[(GatewayEvent) -> Unit]
  /// Timestamp provider
  mut get_timestamp : () -> Int64
  /// ID counter
  mut next_client_id : Int
}

///|
/// Create new WebSocket Gateway handler
pub fn WsGatewayHandler::new(gateway : Gateway?) -> WsGatewayHandler {
  {
    gateway,
    clients: {},
    message_buffers: {},
    event_handlers: [],
    get_timestamp: fn() { 0L },
    next_client_id: 1,
  }
}

///|
/// Set timestamp provider
pub fn WsGatewayHandler::set_timestamp_provider(
  self : WsGatewayHandler,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Generate client ID
fn WsGatewayHandler::generate_client_id(self : WsGatewayHandler) -> String {
  let id = "ws_client_\{self.next_client_id}"
  self.next_client_id += 1
  id
}

///|
/// Handle new client connection
pub fn WsGatewayHandler::on_client_connect(self : WsGatewayHandler) -> String {
  let client_id = self.generate_client_id()
  let now = (self.get_timestamp)()
  let client = WsClientConnection::new(client_id, now)
  self.clients[client_id] = client
  self.message_buffers[client_id] = []
  client_id
}

///|
/// Handle client disconnect
pub fn WsGatewayHandler::on_client_disconnect(
  self : WsGatewayHandler,
  client_id : String,
) -> Unit {
  self.clients.remove(client_id)
  self.message_buffers.remove(client_id)
}

///|
/// Authenticate client
/// For now, accepts any non-empty token as valid (for testing)
pub fn WsGatewayHandler::authenticate_client(
  self : WsGatewayHandler,
  client_id : String,
  token : String,
) -> @interfaces.AuthResult {
  // Simple token validation - accept any non-empty token
  if token.length() == 0 {
    return @interfaces.AuthResult::Denied("Empty token")
  }
  // Create auth context
  let ctx : @interfaces.AuthContext = {
    token,
    user_id: Some("user_" + token),
    expires_at: None,
  }
  // Update client state
  match self.clients.get(client_id) {
    Some(client) => {
      client.authenticated = true
      client.auth_context = Some(ctx)
    }
    None => ()
  }
  ignore(self.gateway)
  @interfaces.AuthResult::Authenticated(ctx)
}

///|
/// Get connected client count
pub fn WsGatewayHandler::client_count(self : WsGatewayHandler) -> Int {
  self.clients.length()
}

///|
/// Check if client is authenticated
pub fn WsGatewayHandler::is_client_authenticated(
  self : WsGatewayHandler,
  client_id : String,
) -> Bool {
  match self.clients.get(client_id) {
    Some(client) => client.authenticated
    None => false
  }
}
