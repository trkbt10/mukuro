///|
/// WebSocket Server for Native Target
/// Provides WebSocket server functionality via C FFI

// ============================================================
// C FFI Declarations
// ============================================================

///|
/// Opaque pointer to C WebSocket server
type WsServerPtr

///|
/// Create a new WebSocket server
extern "c" fn moonbit_ws_server_create(port : Int) -> WsServerPtr = "moonbit_ws_server_create"

///|
/// Start the WebSocket server
#borrow(server)
extern "c" fn moonbit_ws_server_start(server : WsServerPtr) -> Int = "moonbit_ws_server_start"

///|
/// Stop the WebSocket server
#borrow(server)
extern "c" fn moonbit_ws_server_stop(server : WsServerPtr) -> Int = "moonbit_ws_server_stop"

///|
/// Destroy the WebSocket server
#borrow(server)
extern "c" fn moonbit_ws_server_destroy(server : WsServerPtr) -> Unit = "moonbit_ws_server_destroy"

///|
/// Check if server is running
#borrow(server)
extern "c" fn moonbit_ws_server_is_running(server : WsServerPtr) -> Int = "moonbit_ws_server_is_running"

///|
/// Get server port
#borrow(server)
extern "c" fn moonbit_ws_server_get_port(server : WsServerPtr) -> Int = "moonbit_ws_server_get_port"

///|
/// Get client count
#borrow(server)
extern "c" fn moonbit_ws_server_client_count(server : WsServerPtr) -> Int = "moonbit_ws_server_client_count"

///|
/// Accept a new client connection
#borrow(server)
extern "c" fn moonbit_ws_server_accept_client(server : WsServerPtr) -> Int = "moonbit_ws_server_accept_client"

///|
/// Disconnect a client
#borrow(server)
extern "c" fn moonbit_ws_server_disconnect_client(
  server : WsServerPtr,
  client_id : Int,
) -> Int = "moonbit_ws_server_disconnect_client"

///|
/// Send message to a client (requires CString)
#borrow(server, message)
extern "c" fn moonbit_ws_server_send_raw(
  server : WsServerPtr,
  client_id : Int,
  message : Bytes,
) -> Int = "moonbit_ws_server_send"

///|
/// Broadcast message to all clients (requires CString)
#borrow(server, message)
extern "c" fn moonbit_ws_server_broadcast_raw(
  server : WsServerPtr,
  message : Bytes,
) -> Int = "moonbit_ws_server_broadcast"

///|
/// Poll for incoming messages
#borrow(server)
extern "c" fn moonbit_ws_server_poll(server : WsServerPtr) -> Int = "moonbit_ws_server_poll"

// ============================================================
// High-Level API
// ============================================================

///|
/// WebSocket server error
pub(all) suberror WsServerError {
  CreateFailed(String)
  StartFailed(String)
  SendFailed(String)
  ClientNotFound(Int)
  NotRunning
}

///|
/// WebSocket event handler type
pub(all) struct WsEventHandler((WsServerEvent) -> Unit)

///|
/// WebSocket server events
pub(all) enum WsServerEvent {
  ClientConnected(client_id~ : Int)
  ClientDisconnected(client_id~ : Int)
  MessageReceived(client_id~ : Int, message~ : String)
  Error(error~ : String)
}

///|
/// WebSocket server wrapper
pub(all) struct WsServer {
  /// Native server pointer
  ptr : WsServerPtr
  /// Server port
  port : Int
  /// Running state
  mut is_running : Bool
  /// Connected clients
  clients : Map[Int, WsClientInfo]
  /// Event handlers
  event_handlers : Array[WsEventHandler]
}

///|
/// Client information
pub(all) struct WsClientInfo {
  /// Client ID
  id : Int
  /// Connected timestamp
  connected_at : Int64
  /// Authentication state
  mut authenticated : Bool
  /// Auth context (if authenticated)
  mut auth_context : @interfaces.AuthContext?
}

///|
/// Create a new WebSocket server
pub fn WsServer::new(port : Int) -> WsServer {
  let ptr = moonbit_ws_server_create(port)
  { ptr, port, is_running: false, clients: {}, event_handlers: [] }
}

///|
/// Start the server
pub fn WsServer::start(self : WsServer) -> Unit raise WsServerError {
  if self.is_running {
    return
  }
  let result = moonbit_ws_server_start(self.ptr)
  if result != 0 {
    raise WsServerError::StartFailed(
      "Failed to start server on port \{self.port}",
    )
  }
  self.is_running = true
}

///|
/// Stop the server
pub fn WsServer::stop(self : WsServer) -> Unit {
  if not(self.is_running) {
    return
  }
  let _ = moonbit_ws_server_stop(self.ptr)
  self.is_running = false
  self.clients.clear()
}

///|
/// Destroy the server and free resources
pub fn WsServer::destroy(self : WsServer) -> Unit {
  self.stop()
  moonbit_ws_server_destroy(self.ptr)
}

///|
/// Check if server is running (via FFI)
pub fn WsServer::is_running(self : WsServer) -> Bool {
  moonbit_ws_server_is_running(self.ptr) != 0
}

///|
/// Get server port (via FFI)
pub fn WsServer::get_port(self : WsServer) -> Int {
  moonbit_ws_server_get_port(self.ptr)
}

///|
/// Get connected client count (via FFI)
pub fn WsServer::client_count(self : WsServer) -> Int {
  moonbit_ws_server_client_count(self.ptr)
}

///|
/// Add event handler
pub fn WsServer::on_event(self : WsServer, handler : WsEventHandler) -> Unit {
  self.event_handlers.push(handler)
}

///|
/// Emit event to all handlers
fn WsServer::emit_event(self : WsServer, event : WsServerEvent) -> Unit {
  for handler in self.event_handlers {
    handler(event)
  }
}

///|
/// Accept a new client connection
pub fn WsServer::accept_client(
  self : WsServer,
  timestamp : Int64,
) -> Int raise WsServerError {
  if not(self.is_running) {
    raise WsServerError::NotRunning
  }
  let client_id = moonbit_ws_server_accept_client(self.ptr)
  if client_id < 0 {
    raise WsServerError::CreateFailed("Failed to accept client")
  }
  let info : WsClientInfo = {
    id: client_id,
    connected_at: timestamp,
    authenticated: false,
    auth_context: None,
  }
  self.clients[client_id] = info
  self.emit_event(WsServerEvent::ClientConnected(client_id~))
  client_id
}

///|
/// Disconnect a client
pub fn WsServer::disconnect_client(self : WsServer, client_id : Int) -> Unit {
  let _ = moonbit_ws_server_disconnect_client(self.ptr, client_id)
  self.clients.remove(client_id)
  self.emit_event(WsServerEvent::ClientDisconnected(client_id~))
}

///|
/// Send message to a client
pub fn WsServer::send(
  self : WsServer,
  client_id : Int,
  message : String,
) -> Unit raise WsServerError {
  if not(self.is_running) {
    raise WsServerError::NotRunning
  }
  match self.clients.get(client_id) {
    None => raise WsServerError::ClientNotFound(client_id)
    Some(_) => {
      let bytes = string_to_cstring_bytes(message)
      let result = moonbit_ws_server_send_raw(self.ptr, client_id, bytes)
      if result != 0 {
        raise WsServerError::SendFailed(
          "Failed to send message to client \{client_id}",
        )
      }
    }
  }
}

///|
/// Broadcast message to all clients
pub fn WsServer::broadcast(self : WsServer, message : String) -> Int {
  if not(self.is_running) {
    return 0
  }
  let bytes = string_to_cstring_bytes(message)
  let result = moonbit_ws_server_broadcast_raw(self.ptr, bytes)
  if result < 0 {
    0
  } else {
    result
  }
}

///|
/// Get client info
pub fn WsServer::get_client(self : WsServer, client_id : Int) -> WsClientInfo? {
  self.clients.get(client_id)
}

///|
/// Authenticate a client
pub fn WsServer::authenticate_client(
  self : WsServer,
  client_id : Int,
  ctx : @interfaces.AuthContext,
) -> Bool {
  match self.clients.get(client_id) {
    Some(client) => {
      client.authenticated = true
      client.auth_context = Some(ctx)
      true
    }
    None => false
  }
}

///|
/// Check if client is authenticated
pub fn WsServer::is_client_authenticated(
  self : WsServer,
  client_id : Int,
) -> Bool {
  match self.clients.get(client_id) {
    Some(client) => client.authenticated
    None => false
  }
}

///|
/// Poll for events (call periodically)
pub fn WsServer::poll(self : WsServer) -> Unit {
  if not(self.is_running) {
    return
  }
  let client_id = moonbit_ws_server_poll(self.ptr)
  if client_id >= 0 {
    // In a real implementation, we would get the message here
    // For now, this is a placeholder
    ignore(client_id)
  }
}

///|
/// Get all connected client IDs
pub fn WsServer::get_client_ids(self : WsServer) -> Array[Int] {
  let ids : Array[Int] = []
  for id, _ in self.clients {
    ids.push(id)
  }
  ids
}

// ============================================================
// Helper Functions
// ============================================================

///|
/// Convert String to null-terminated C string bytes
fn string_to_cstring_bytes(s : String) -> Bytes {
  let utf8 = @utf8.encode(s)
  // Append null terminator
  let arr : Array[Byte] = []
  for b in utf8 {
    arr.push(b)
  }
  arr.push(b'\x00')
  Bytes::from_iter(arr.iter())
}
