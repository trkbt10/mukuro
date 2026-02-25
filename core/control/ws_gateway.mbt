///|
/// WebSocket Gateway Control Plane
/// Provides real-time WebSocket API for Gateway management

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
/// Handle incoming JSON-RPC message from WebSocket client
pub fn WsGatewayHandler::handle_message(
  self : WsGatewayHandler,
  client_id : String,
  message : String,
) -> String {
  // Parse JSON-RPC request
  let request : @interfaces.JsonRpcRequest = match
    parse_jsonrpc_request(message) {
    Some(req) => req
    None => return jsonrpc_error_response(None, -32700, "Parse error", None)
  }
  // Check if client exists
  match self.clients.get(client_id) {
    Some(client) => self.dispatch_request(client, request)
    None => jsonrpc_error_response(request.id, -32600, "Client not found", None)
  }
}

///|
/// Dispatch JSON-RPC request to appropriate handler
fn WsGatewayHandler::dispatch_request(
  self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
) -> String {
  match request.rpc_method {
    // Authentication
    "auth" => self.handle_auth(client, request)
    // Gateway methods (require auth)
    "gateway.status" =>
      self.require_auth(client, request, fn(_) {
        self.handle_gateway_status(request)
      })
    "gateway.health" =>
      self.require_auth(client, request, fn(_) {
        self.handle_gateway_health(request)
      })
    // Channel methods (require auth)
    "channel.list" =>
      self.require_auth(client, request, fn(_) {
        self.handle_channel_list(request)
      })
    "channel.connect" =>
      self.require_auth(client, request, fn(_) {
        self.handle_channel_connect(request)
      })
    "channel.disconnect" =>
      self.require_auth(client, request, fn(_) {
        self.handle_channel_disconnect(request)
      })
    // Session methods (require auth)
    "session.list" =>
      self.require_auth(client, request, fn(_) {
        self.handle_session_list(request)
      })
    "session.get" =>
      self.require_auth(client, request, fn(_) {
        self.handle_session_get(request)
      })
    // Message methods (require auth)
    "message.send" =>
      self.require_auth(client, request, fn(_) {
        self.handle_message_send(request)
      })
    // Subscription methods
    "subscribe" => self.handle_subscribe(client, request)
    "unsubscribe" => self.handle_unsubscribe(client, request)
    // Unknown method
    _ =>
      jsonrpc_error_response(
        request.id,
        -32601,
        "Method not found: \{request.rpc_method}",
        None,
      )
  }
}

///|
/// Require authentication wrapper
fn WsGatewayHandler::require_auth(
  _self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
  handler : (@interfaces.AuthContext) -> String,
) -> String {
  if not(client.authenticated) {
    return jsonrpc_error_response(request.id, -32000, "Not authenticated", None)
  }
  match client.auth_context {
    Some(ctx) => handler(ctx)
    None =>
      jsonrpc_error_response(request.id, -32000, "Invalid auth context", None)
  }
}

///|
/// Handle auth request
fn WsGatewayHandler::handle_auth(
  self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let token = match @interfaces.rpc_require_string(request, "token") {
    Ok(t) => t
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'token' parameter",
        None,
      )
  }
  let result = self.authenticate_client(client.id, token)
  match result {
    @interfaces.AuthResult::Authenticated(ctx) =>
      jsonrpc_success_response(request.id, {
        "authenticated": true,
        "token": Json::string(ctx.token),
        "user_id": match ctx.user_id {
          Some(u) => Json::string(u)
          None => Json::null()
        },
      })
    @interfaces.AuthResult::Denied(msg) =>
      jsonrpc_error_response(request.id, -32001, msg, None)
    @interfaces.AuthResult::Expired =>
      jsonrpc_error_response(request.id, -32001, "Token expired", None)
  }
}

///|
/// Handle gateway.status request
fn WsGatewayHandler::handle_gateway_status(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  match self.gateway {
    Some(gw) => {
      let status = gw.status()
      jsonrpc_success_response(request.id, {
        "state": Json::string(gateway_state_to_string(status.state)),
        "started_at": match status.started_at {
          Some(t) => Json::number(t.to_double())
          None => Json::null()
        },
        "connected_channels_count": Json::number(
          status.connected_channels.length().to_double(),
        ),
        "connected_channels": Json::array(
          status.connected_channels.map(fn(c) { Json::string(c) }),
        ),
        "active_sessions": Json::number(status.active_sessions.to_double()),
        "version": Json::string(status.version),
      })
    }
    None =>
      jsonrpc_error_response(request.id, -32002, "Gateway not configured", None)
  }
}

///|
/// Convert GatewayState to string
fn gateway_state_to_string(state : @interfaces.GatewayState) -> String {
  match state {
    @interfaces.GatewayState::Stopped => "stopped"
    @interfaces.GatewayState::Starting => "starting"
    @interfaces.GatewayState::Running => "running"
    @interfaces.GatewayState::Stopping => "stopping"
    @interfaces.GatewayState::Error(_) => "error"
  }
}

///|
/// Handle gateway.health request
fn WsGatewayHandler::handle_gateway_health(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  match self.gateway {
    Some(_) =>
      jsonrpc_success_response(request.id, {
        "healthy": true,
        "checks": Json::array([]),
      })
    None =>
      jsonrpc_error_response(request.id, -32002, "Gateway not configured", None)
  }
}

///|
/// Handle channel.list request
fn WsGatewayHandler::handle_channel_list(
  _self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  // Return empty list for now (would need to query Gateway's channel manager)
  jsonrpc_success_response(request.id, { "channels": Json::array([]) })
}

///|
/// Handle session.list request
fn WsGatewayHandler::handle_session_list(
  _self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  // Return empty list for now (would need to query Gateway's session store)
  jsonrpc_success_response(request.id, { "sessions": Json::array([]) })
}

///|
/// Handle channel.connect request
fn WsGatewayHandler::handle_channel_connect(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let channel_name = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'channel' parameter",
        None,
      )
  }
  // Connect channel via Gateway
  match self.gateway {
    Some(gw) =>
      // In a real implementation, this would call gw.connect_channel(channel_name)
      ignore(gw)
    None => ()
  }
  // Return success (mock implementation)
  jsonrpc_success_response(request.id, {
    "channel": Json::string(channel_name),
    "connected": true,
  })
}

///|
/// Handle channel.disconnect request
fn WsGatewayHandler::handle_channel_disconnect(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let channel_name = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'channel' parameter",
        None,
      )
  }
  // Disconnect channel via Gateway
  match self.gateway {
    Some(gw) =>
      // In a real implementation, this would call gw.disconnect_channel(channel_name)
      ignore(gw)
    None => ()
  }
  // Return success (mock implementation)
  jsonrpc_success_response(request.id, {
    "channel": Json::string(channel_name),
    "disconnected": true,
  })
}

///|
/// Handle session.get request
fn WsGatewayHandler::handle_session_get(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let session_id = match @interfaces.rpc_require_string(request, "session_id") {
    Ok(s) => s
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'session_id' parameter",
        None,
      )
  }
  // Get session from Gateway's session store
  match self.gateway {
    Some(gw) =>
      // In a real implementation, this would call gw.get_session(session_id)
      ignore(gw)
    None => ()
  }
  // Return not found (mock implementation - no sessions stored)
  jsonrpc_error_response(
    request.id,
    -32004,
    "Session not found: \{session_id}",
    None,
  )
}

///|
/// Handle message.send request
fn WsGatewayHandler::handle_message_send(
  self : WsGatewayHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let channel = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'channel' parameter",
        None,
      )
  }
  let chat_id = match @interfaces.rpc_require_string(request, "chat_id") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'chat_id' parameter",
        None,
      )
  }
  let content = match @interfaces.rpc_require_string(request, "content") {
    Ok(c) => c
    Err(_) =>
      return jsonrpc_error_response(
        request.id,
        -32602,
        "Missing 'content' parameter",
        None,
      )
  }
  // Send message via Gateway's outbound dispatcher
  match self.gateway {
    Some(gw) =>
      // In a real implementation, this would call gw.send_message(channel, chat_id, content)
      ignore(gw)
    None => ()
  }
  // Return success (mock implementation)
  jsonrpc_success_response(request.id, {
    "sent": true,
    "channel": Json::string(channel),
    "chat_id": Json::string(chat_id),
    "content_length": Json::number(content.length().to_double()),
  })
}

///|
/// Handle subscribe request
fn WsGatewayHandler::handle_subscribe(
  self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let events = @interfaces.rpc_string_array(request, "events")
  if events.length() == 0 {
    return jsonrpc_error_response(
      request.id,
      -32602,
      "Missing 'events' parameter",
      None,
    )
  }
  for event in events {
    if not(client.subscriptions.contains(event)) {
      client.subscriptions.push(event)
    }
  }
  ignore(self)
  jsonrpc_success_response(request.id, {
    "subscribed": Json::array(
      client.subscriptions.map(fn(s) { Json::string(s) }),
    ),
  })
}

///|
/// Handle unsubscribe request
fn WsGatewayHandler::handle_unsubscribe(
  self : WsGatewayHandler,
  client : WsClientConnection,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let events = @interfaces.rpc_string_array(request, "events")
  for event in events {
    // Remove from subscriptions
    let new_subs : Array[String] = []
    for sub in client.subscriptions {
      if sub != event {
        new_subs.push(sub)
      }
    }
    client.subscriptions.clear()
    for sub in new_subs {
      client.subscriptions.push(sub)
    }
  }
  ignore(self)
  jsonrpc_success_response(request.id, {
    "subscribed": Json::array(
      client.subscriptions.map(fn(s) { Json::string(s) }),
    ),
  })
}

///|
/// Broadcast event to subscribed clients
pub fn WsGatewayHandler::broadcast_event(
  self : WsGatewayHandler,
  event : GatewayEvent,
) -> Unit {
  let event_type = get_event_type(event)
  let event_json = event_to_json(event)
  // Broadcast to all subscribed clients
  for client_id, client in self.clients {
    if client.subscriptions.contains(event_type) ||
      client.subscriptions.contains("*") {
      // Add to message buffer
      match self.message_buffers.get(client_id) {
        Some(buffer) => buffer.push(event_json.stringify())
        None => ()
      }
    }
  }
}

///|
/// Get event type string
pub fn get_event_type(event : GatewayEvent) -> String {
  match event {
    StateChanged(..) => "state_changed"
    MessageReceived(..) => "message_received"
    MessageSent(..) => "message_sent"
    ChannelConnected(..) => "channel_connected"
    ChannelDisconnected(..) => "channel_disconnected"
    Error(..) => "error"
  }
}

///|
/// Convert event to JSON
pub fn event_to_json(event : GatewayEvent) -> Json {
  let obj : Map[String, Json] = { "type": Json::string(get_event_type(event)) }
  match event {
    StateChanged(old~, new~) => {
      obj["old_state"] = Json::string(gateway_state_to_string(old))
      obj["new_state"] = Json::string(gateway_state_to_string(new))
    }
    MessageReceived(envelope~) =>
      obj["envelope"] = inbound_envelope_to_json(envelope)
    MessageSent(message~) => obj["message"] = outbound_message_to_json(message)
    ChannelConnected(channel~) => obj["channel"] = Json::string(channel)
    ChannelDisconnected(channel~) => obj["channel"] = Json::string(channel)
    Error(error~) => obj["error"] = Json::string(error)
  }
  Json::object({
    "jsonrpc": "2.0",
    "method": "event",
    "params": Json::object(obj),
  })
}

///|
/// Convert InboundEnvelope to JSON
fn inbound_envelope_to_json(envelope : @types.InboundEnvelope) -> Json {
  Json::object({
    "channel": Json::string(envelope.channel),
    "chat_id": Json::string(envelope.chat_id),
    "sender_id": Json::string(envelope.sender_id),
    "sender_name": Json::string(envelope.sender_name),
    "content": Json::string(envelope.content),
    "timestamp": Json::number(envelope.timestamp.to_double()),
  })
}

///|
/// Convert OutboundMessage to JSON
fn outbound_message_to_json(message : @types.OutboundMessage) -> Json {
  let obj : Map[String, Json] = {
    "channel": Json::string(message.channel),
    "chat_id": Json::string(message.chat_id),
    "content": Json::string(message.content),
  }
  match message.reply_to {
    Some(r) => obj["reply_to"] = Json::string(r)
    None => ()
  }
  Json::object(obj)
}

///|
/// Get pending messages for client
pub fn WsGatewayHandler::get_pending_messages(
  self : WsGatewayHandler,
  client_id : String,
) -> Array[String] {
  match self.message_buffers.get(client_id) {
    Some(buffer) => {
      let messages = buffer.copy()
      buffer.clear()
      messages
    }
    None => []
  }
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

// ============================================================
// JSON-RPC Helper Functions
// ============================================================

///|
/// Parse JSON-RPC request from string
fn parse_jsonrpc_request(message : String) -> @interfaces.JsonRpcRequest? {
  let json : Json = @json.parse(message) catch { _ => return None }
  match json {
    Object(obj) => {
      let rpc_method = match obj.get("method") {
        Some(String(m)) => m
        _ => return None
      }
      let id : Int? = match obj.get("id") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
      let params : Json? = obj.get("params")
      Some({ jsonrpc: "2.0", rpc_method, params, id })
    }
    _ => None
  }
}

///|
/// Build JSON-RPC success response
pub fn jsonrpc_success_response(id : Int?, result : Json) -> String {
  let response : Map[String, Json] = { "jsonrpc": "2.0", "result": result }
  match id {
    Some(i) => response["id"] = Json::number(i.to_double())
    None => ()
  }
  Json::object(response).stringify()
}

///|
/// Build JSON-RPC error response
pub fn jsonrpc_error_response(
  id : Int?,
  code : Int,
  message : String,
  data : Json?,
) -> String {
  let error : Map[String, Json] = {
    "code": Json::number(code.to_double()),
    "message": Json::string(message),
  }
  match data {
    Some(d) => error["data"] = d
    None => ()
  }
  let response : Map[String, Json] = {
    "jsonrpc": "2.0",
    "error": Json::object(error),
  }
  match id {
    Some(i) => response["id"] = Json::number(i.to_double())
    None => ()
  }
  Json::object(response).stringify()
}
