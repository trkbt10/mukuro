///|
/// Native WebSocket client for plugin communication
/// Uses mizchi/x/websocket for actual WebSocket connections

///|
/// WebSocket client error
pub(all) suberror WebSocketClientError {
  ConnectionFailed(String)
  SendFailed(String)
  ReceiveFailed(String)
  Closed
  Timeout
}

///|
/// WebSocket client wrapper
pub struct NativeWebSocketClient {
  /// WebSocket URL
  url : String
  /// Connection headers
  headers : Map[String, String]
  /// Current connection
  mut conn : @websocket.Conn?
  /// Whether connected
  mut connected : Bool
}

///|
/// Create a new WebSocket client
pub fn NativeWebSocketClient::new(
  url~ : String,
  headers~ : Map[String, String],
) -> NativeWebSocketClient {
  { url, headers, conn: None, connected: false }
}

///|
/// Connect to the WebSocket server
pub async fn NativeWebSocketClient::connect(
  self : NativeWebSocketClient,
) -> Unit raise WebSocketClientError {
  let conn = @websocket.Conn::connect(self.url, headers=self.headers) catch {
    e => raise WebSocketClientError::ConnectionFailed(e.to_string())
  }
  self.conn = Some(conn)
  self.connected = true
}

///|
/// Send a text message
pub async fn NativeWebSocketClient::send_text(
  self : NativeWebSocketClient,
  message : String,
) -> Unit raise WebSocketClientError {
  match self.conn {
    Some(conn) =>
      conn.send_text(message) catch {
        e => raise WebSocketClientError::SendFailed(e.to_string())
      }
    None => raise WebSocketClientError::Closed
  }
}

///|
/// Receive a message (blocking)
pub async fn NativeWebSocketClient::recv(
  self : NativeWebSocketClient,
) -> String raise WebSocketClientError {
  match self.conn {
    Some(conn) => {
      let msg = conn.recv() catch {
        @websocket.WebSocketError::ConnectionClosed(_, _) => {
          self.connected = false
          raise WebSocketClientError::Closed
        }
        e => raise WebSocketClientError::ReceiveFailed(e.to_string())
      }
      match msg {
        @websocket.Message::Text(text) => text
        @websocket.Message::Binary(data) =>
          // Try to decode as UTF-8
          @utf8.decode(data) catch {
            _ => raise WebSocketClientError::ReceiveFailed("Invalid UTF-8 data")
          }
      }
    }
    None => raise WebSocketClientError::Closed
  }
}

///|
/// Close the connection
pub async fn NativeWebSocketClient::close(self : NativeWebSocketClient) -> Unit {
  match self.conn {
    Some(conn) => {
      conn.send_close() catch {
        _ => ()
      }
      conn.close()
      self.conn = None
      self.connected = false
    }
    None => ()
  }
}

///|
/// Check if connected
pub fn NativeWebSocketClient::is_connected(
  self : NativeWebSocketClient,
) -> Bool {
  self.connected
}

///|
/// Send JSON-RPC request and wait for response
pub async fn NativeWebSocketClient::send_jsonrpc_request(
  self : NativeWebSocketClient,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse raise WebSocketClientError {
  // Send request
  let request_json = request.to_json().stringify()
  self.send_text(request_json)
  // Wait for response
  let response_text = self.recv()
  // Parse response
  let json = @json.parse(response_text) catch {
    e => raise WebSocketClientError::ReceiveFailed("Invalid JSON: \{e}")
  }
  match parse_jsonrpc_response_json(json) {
    Some(response) => response
    None =>
      raise WebSocketClientError::ReceiveFailed(
        "Invalid JSON-RPC response: \{response_text}",
      )
  }
}

///|
/// Parse JSON as JSON-RPC response
pub fn parse_jsonrpc_response_json(json : Json) -> @interfaces.JsonRpcResponse? {
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
