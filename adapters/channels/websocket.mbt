///|
/// WebSocket チャネル設定
pub(all) struct WebSocketChannelConfig {
  /// チャネル名
  name : String
  /// WebSocket URL
  url : String
  /// 認証トークン（オプション）
  auth_token : String?
  /// ハートビート間隔（ミリ秒）
  heartbeat_interval_ms : Int
  /// 基本設定
  base : ChannelBaseConfig
}

///|
/// デフォルト設定
pub fn WebSocketChannelConfig::default(
  name~ : String,
  url~ : String,
) -> WebSocketChannelConfig {
  {
    name,
    url,
    auth_token: None,
    heartbeat_interval_ms: 30000,
    base: ChannelBaseConfig::default(name~),
  }
}

///|
/// WebSocket JavaScript FFI型
#external
type JsWebSocket

///|
/// WebSocketを作成
extern "js" fn js_websocket_create(url : String) -> JsWebSocket =
  #|(url) => new WebSocket(url)

///|
/// WebSocketにイベントハンドラを設定
extern "js" fn js_websocket_on_open(
  ws : JsWebSocket,
  handler : () -> Unit,
) -> Unit =
  #|(ws, handler) => { ws.onopen = handler }

///|
extern "js" fn js_websocket_on_message(
  ws : JsWebSocket,
  handler : (String) -> Unit,
) -> Unit =
  #|(ws, handler) => { ws.onmessage = (e) => handler(typeof e.data === 'string' ? e.data : JSON.stringify(e.data)) }

///|
extern "js" fn js_websocket_on_close(
  ws : JsWebSocket,
  handler : () -> Unit,
) -> Unit =
  #|(ws, handler) => { ws.onclose = handler }

///|
extern "js" fn js_websocket_on_error(
  ws : JsWebSocket,
  handler : () -> Unit,
) -> Unit =
  #|(ws, handler) => { ws.onerror = handler }

///|
/// WebSocketでメッセージを送信
extern "js" fn js_websocket_send(ws : JsWebSocket, message : String) -> Unit =
  #|(ws, msg) => ws.send(msg)

///|
/// WebSocketを閉じる
extern "js" fn js_websocket_close(ws : JsWebSocket) -> Unit =
  #|(ws) => ws.close()

///|
/// WebSocketの接続状態を取得
extern "js" fn js_websocket_ready_state(ws : JsWebSocket) -> Int =
  #|(ws) => ws.readyState

///|
/// WebSocket チャネルアダプタ
pub struct WebSocketChannelAdapter {
  config : WebSocketChannelConfig
  mut status : ChannelStatus
  mut socket : JsWebSocket?
  /// 受信キュー
  received_messages : Array[@types.InboundEnvelope]
}

///|
/// WebSocketChannelAdapterを新規作成
pub fn WebSocketChannelAdapter::new(
  config : WebSocketChannelConfig,
) -> WebSocketChannelAdapter {
  {
    config,
    status: ChannelStatus::Disconnected,
    socket: None,
    received_messages: [],
  }
}

///|
/// ChannelAdapter実装
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with name(self) {
  self.config.name
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with connect(
  self,
) {
  self.status = ChannelStatus::Connecting
  let ws = js_websocket_create(self.config.url)
  self.socket = Some(ws)
  // 認証トークンがある場合は接続時に送信
  let auth_token = self.config.auth_token
  let channel_name = self.config.name
  let received = self.received_messages
  js_websocket_on_open(ws, fn() {
    self.status = ChannelStatus::Connected
    // 認証メッセージを送信
    match auth_token {
      Some(token) => {
        let auth_msg : Json = { "type": "auth", "token": token }
        js_websocket_send(ws, auth_msg.stringify())
      }
      None => ()
    }
  })
  js_websocket_on_message(ws, fn(data) {
    // メッセージをパース
    let json : Json = @json.parse(data) catch { _ => return }
    // InboundEnvelopeに変換
    let chat_id = match json {
      { "chat_id": String(id), .. } => id
      _ => "default"
    }
    let sender_id = match json {
      { "sender_id": String(id), .. } => id
      { "user_id": String(id), .. } => id
      _ => "unknown"
    }
    let content = match json {
      { "content": String(c), .. } => c
      { "message": String(m), .. } => m
      { "text": String(t), .. } => t
      _ => data
    }
    let envelope : @types.InboundEnvelope = {
      channel: channel_name,
      chat_id,
      sender_id,
      sender_name: sender_id,
      content,
      message_type: @types.MessageType::Text,
      metadata: {},
      timestamp: @js.js_date_now(),
    }
    received.push(envelope)
  })
  js_websocket_on_close(ws, fn() { self.status = ChannelStatus::Disconnected })
  js_websocket_on_error(ws, fn() {
    self.status = ChannelStatus::Error("WebSocket error")
  })
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with disconnect(
  self,
) {
  match self.socket {
    Some(ws) => {
      js_websocket_close(ws)
      self.socket = None
    }
    None => ()
  }
  self.status = ChannelStatus::Disconnected
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with is_connected(
  self,
) {
  match self.socket {
    Some(ws) => js_websocket_ready_state(ws) == 1 // OPEN = 1
    None => false
  }
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with send(
  self,
  message,
) {
  match self.socket {
    Some(ws) => {
      let payload = ws_outbound_to_json(message)
      js_websocket_send(ws, payload.stringify())
    }
    None => raise ChannelError::NetworkError("WebSocket not connected")
  }
}

///|
pub impl @interfaces.ChannelAdapter for WebSocketChannelAdapter with receive(
  self,
) {
  if self.received_messages.length() > 0 {
    let msg = self.received_messages[0]
    // 配列をシフト
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
    raise ChannelError::NetworkError("No messages in queue")
  }
}

///|
/// OutboundMessageをWebSocket用JSONに変換
fn ws_outbound_to_json(message : @types.OutboundMessage) -> Json {
  {
    "type": "message",
    "channel": message.channel,
    "chat_id": message.chat_id,
    "content": message.content,
  }
}
