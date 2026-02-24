///|
/// WebSocket チャネル設定（native）
pub(all) struct WebSocketChannelConfig {
  name : String
  url : String
  auth_token : String?
  heartbeat_interval_ms : Int
  receive_timeout_ms : Int
  base : ChannelBaseConfig
}

///|
pub fn WebSocketChannelConfig::default(
  name~ : String,
  url~ : String,
) -> WebSocketChannelConfig {
  {
    name,
    url,
    auth_token: None,
    heartbeat_interval_ms: 30000,
    receive_timeout_ms: 50,
    base: ChannelBaseConfig::default(name~),
  }
}

///|
pub struct WebSocketChannelAdapter {
  config : WebSocketChannelConfig
  mut status : ChannelStatus
  received_messages : Array[@types.InboundEnvelope]
  mut conn : @xws.Conn?
}

///|
pub fn WebSocketChannelAdapter::new(
  config : WebSocketChannelConfig,
) -> WebSocketChannelAdapter {
  {
    config,
    status: ChannelStatus::Disconnected,
    received_messages: [],
    conn: None,
  }
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with name(self) {
  self.config.name
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with connect(
  self,
) {
  if self.config.url.length() == 0 {
    raise ChannelError::ConnectionFailed("WebSocket URL is empty")
  }
  @async.with_event_loop(fn(_group) {
    let headers : Map[String, String] = {}
    match self.config.auth_token {
      Some(token) => headers["Authorization"] = "Bearer \{token}"
      None => ()
    }
    let conn = @xws.Conn::connect(self.config.url, headers~) catch {
      e => raise map_ws_error(e)
    }
    self.conn = Some(conn)
  }) catch {
    e => {
      self.status = ChannelStatus::Error(e.to_string())
      raise ChannelError::NetworkError(e.to_string())
    }
  }
  self.status = ChannelStatus::Connected
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with disconnect(
  self,
) {
  match self.conn {
    Some(conn) => {
      conn.close()
      self.conn = None
    }
    None => ()
  }
  self.status = ChannelStatus::Disconnected
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with is_connected(
  self,
) {
  match self.status {
    ChannelStatus::Connected => true
    _ => false
  }
}

///|
fn map_ws_error(err : @xws.WebSocketError) -> ChannelError {
  ChannelError::NetworkError(err.to_string())
}

///|
fn WebSocketChannelAdapter::ensure_connected(
  self : WebSocketChannelAdapter,
) -> Unit raise {
  if !@interfaces.ChannelAdapter::is_connected(self) || self.conn is None {
    @interfaces.ChannelAdapter::connect(self)
  }
}

///|
fn WebSocketChannelAdapter::reset_connection(
  self : WebSocketChannelAdapter,
) -> Unit {
  match self.conn {
    Some(conn) => {
      conn.close()
      self.conn = None
    }
    None => ()
  }
  self.status = ChannelStatus::Disconnected
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with send(
  self,
  message,
) {
  self.ensure_connected()
  let payload = ws_outbound_to_json(message).stringify()
  let mut attempts = 0
  while attempts < 2 {
    let send_result : Result[Unit, ChannelError] = try {
      @async.with_event_loop(fn(_group) {
        let conn = match self.conn {
          Some(c) => c
          None =>
            raise ChannelError::ConnectionFailed("WebSocket not connected")
        }
        conn.send_text(payload) catch {
          e => {
            self.reset_connection()
            raise map_ws_error(e)
          }
        }
      })
      Ok(())
    } catch {
      e => Err(ChannelError::NetworkError(e.to_string()))
    }
    match send_result {
      Ok(_) => return
      Err(err) => {
        attempts = attempts + 1
        if attempts >= 2 {
          raise err
        }
        self.ensure_connected()
      }
    }
  }
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with receive(
  self,
) {
  if self.received_messages.length() > 0 {
    let msg = self.received_messages[0]
    let new_arr : Array[@types.InboundEnvelope] = []
    for i in 1..<self.received_messages.length() {
      new_arr.push(self.received_messages[i])
    }
    self.received_messages.clear()
    for m in new_arr {
      self.received_messages.push(m)
    }
    msg
  } else {
    self.ensure_connected()
    let recv_result : Result[Unit, ChannelError] = try {
      @async.with_event_loop(fn(_group) {
        let conn = match self.conn {
          Some(c) => c
          None =>
            raise ChannelError::ConnectionFailed("WebSocket not connected")
        }
        let incoming = @async.with_timeout_opt(self.config.receive_timeout_ms, () => {
          conn.recv() catch {
            e => {
              self.reset_connection()
              raise map_ws_error(e)
            }
          }
        }) catch {
          e => raise ChannelError::NetworkError(e.to_string())
        }
        match incoming {
          Some(@xws.Message::Text(text)) =>
            self.handle_incoming_text(text, None, None)
          Some(@xws.Message::Binary(bin)) =>
            self.handle_incoming_text("<binary:\{bin.length()}>", None, None)
          None => ()
        }
      })
      Ok(())
    } catch {
      e => Err(ChannelError::NetworkError(e.to_string()))
    }
    match recv_result {
      Ok(_) => ()
      Err(err) => raise err
    }
    if self.received_messages.length() == 0 {
      raise ChannelError::NetworkError("No messages in queue")
    }
    @interfaces.ChannelAdapter::receive(self)
  }
}

///|
/// 将来の常時接続受信ループ導入に向けた手動投入API
pub fn WebSocketChannelAdapter::handle_incoming_text(
  self : WebSocketChannelAdapter,
  text : String,
  chat_id : String?,
  sender_id : String?,
) -> Unit {
  let json : Json = @json.parse(text) catch { _ => Json::null() }
  let resolved_chat_id = chat_id.unwrap_or(
    match json {
      { "chat_id": String(id), .. } => id
      _ => "default"
    },
  )
  let resolved_sender_id = sender_id.unwrap_or(
    match json {
      { "sender_id": String(id), .. } => id
      { "user_id": String(id), .. } => id
      _ => "unknown"
    },
  )
  let content = match json {
    { "content": String(c), .. } => c
    { "message": String(m), .. } => m
    { "text": String(t), .. } => t
    _ => text
  }
  let envelope : @types.InboundEnvelope = {
    channel: self.config.name,
    chat_id: resolved_chat_id,
    sender_id: resolved_sender_id,
    sender_name: resolved_sender_id,
    content,
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: @native.c_time() * 1000,
  }
  self.received_messages.push(envelope)
}

///|
fn ws_outbound_to_json(message : @types.OutboundMessage) -> Json {
  {
    "type": "message",
    "channel": message.channel,
    "chat_id": message.chat_id,
    "content": message.content,
  }
}
