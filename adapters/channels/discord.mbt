///|
/// Discord Bot チャネル設定
pub(all) struct DiscordChannelConfig {
  /// チャネル名
  name : String
  /// Bot Token
  bot_token : String
  /// Application ID
  application_id : String
  /// Gateway URL
  gateway_url : String
  /// API Base URL
  api_base_url : String
  /// 基本設定
  base : ChannelBaseConfig
}

///|
/// デフォルト設定
pub fn DiscordChannelConfig::default(
  name~ : String,
  bot_token~ : String,
  application_id~ : String,
) -> DiscordChannelConfig {
  {
    name,
    bot_token,
    application_id,
    gateway_url: "wss://gateway.discord.gg/?v=10&encoding=json",
    api_base_url: "https://discord.com/api/v10",
    base: ChannelBaseConfig::default(name~),
  }
}

///|
/// Discord Bot チャネルアダプタ
pub struct DiscordChannelAdapter {
  config : DiscordChannelConfig
  mut status : ChannelStatus
  /// WebSocket接続
  mut socket : JsWebSocket?
  /// ハートビート間隔
  mut heartbeat_interval : Int
  /// 最後のシーケンス番号
  mut last_sequence : Int?
  /// セッションID
  mut session_id : String?
  /// 受信キュー
  received_messages : Array[@types.InboundEnvelope]
}

///|
/// DiscordChannelAdapterを新規作成
pub fn DiscordChannelAdapter::new(
  config : DiscordChannelConfig,
) -> DiscordChannelAdapter {
  {
    config,
    status: ChannelStatus::Disconnected,
    socket: None,
    heartbeat_interval: 0,
    last_sequence: None,
    session_id: None,
    received_messages: [],
  }
}

///|
/// ChannelAdapter実装
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with name(self) {
  self.config.name
}

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with connect(self) {
  self.status = ChannelStatus::Connecting
  let ws = js_websocket_create(self.config.gateway_url)
  self.socket = Some(ws)
  let bot_token = self.config.bot_token
  let channel_name = self.config.name
  let received = self.received_messages
  js_websocket_on_open(ws, fn() { self.status = ChannelStatus::Connected })
  js_websocket_on_message(ws, fn(data) {
    let payload : Json = @json.parse(data) catch { _ => return }
    // シーケンス番号を更新
    match payload {
      { "s": Number(s, ..), .. } => self.last_sequence = Some(s.to_int())
      _ => ()
    }
    // opcodeを取得
    let opcode = match payload {
      { "op": Number(op, ..), .. } => op.to_int()
      _ => return
    }
    match opcode {
      // Hello (10) - ハートビート開始
      10 =>
        match payload {
          { "d": { "heartbeat_interval": Number(interval, ..), .. }, .. } => {
            self.heartbeat_interval = interval.to_int()
            // Identify送信
            let identify : Json = {
              "op": 2,
              "d": {
                "token": bot_token,
                "intents": 513, // GUILDS + GUILD_MESSAGES
                "properties": {
                  "os": "browser",
                  "browser": "mukuro",
                  "device": "mukuro",
                },
              },
            }
            js_websocket_send(ws, identify.stringify())
          }
          _ => ()
        }
      // Heartbeat ACK (11)
      11 => ()
      // Dispatch (0) - イベント受信
      0 =>
        match payload {
          { "t": String(event_type), "d": event_data, .. } =>
            if event_type == "MESSAGE_CREATE" {
              // Botからのメッセージは無視
              match event_data {
                { "author": { "bot": True, .. }, .. } => ()
                _ => {
                  let chat_id = match event_data {
                    { "channel_id": String(id), .. } => id
                    _ => return
                  }
                  let sender_id = match event_data {
                    { "author": { "id": String(id), .. }, .. } => id
                    _ => "unknown"
                  }
                  let content = match event_data {
                    { "content": String(c), .. } => c
                    _ => ""
                  }
                  if content.length() > 0 {
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
                  }
                }
              }
            } else if event_type == "READY" {
              match event_data {
                { "session_id": String(sid), .. } => self.session_id = Some(sid)
                _ => ()
              }
            }
          _ => ()
        }
      _ => ()
    }
  })
  js_websocket_on_close(ws, fn() { self.status = ChannelStatus::Disconnected })
  js_websocket_on_error(ws, fn() {
    self.status = ChannelStatus::Error("Discord gateway error")
  })
}

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with disconnect(
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
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with is_connected(
  self,
) {
  match self.socket {
    Some(ws) => js_websocket_ready_state(ws) == 1
    None => false
  }
}

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with send(
  self,
  message,
) {
  // REST APIでメッセージを送信
  let api_url = "\{self.config.api_base_url}/channels/\{message.chat_id}/messages"
  let payload : Json = { "content": message.content }
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "Authorization": "Bot \{self.config.bot_token}",
  }
  let body = @js.js_text_encode(payload.stringify())
  @js.fetch_with_callback(
    api_url,
    "POST",
    headers,
    Some(body),
    fn(_response) { () },
    fn(_error) { () },
  )
}

///|
pub impl @interfaces.ChannelAdapter for DiscordChannelAdapter with receive(self) {
  match @util.pop_first(self.received_messages) {
    Some(msg) => msg
    None => raise ChannelError::NetworkError("No messages in queue")
  }
}

///|
/// ハートビートを送信
pub fn DiscordChannelAdapter::send_heartbeat(
  self : DiscordChannelAdapter,
) -> Unit {
  match self.socket {
    Some(ws) => {
      let seq : Json = match self.last_sequence {
        Some(s) => Json::number(s.to_double())
        None => Json::null()
      }
      let heartbeat : Json = { "op": 1, "d": seq }
      js_websocket_send(ws, heartbeat.stringify())
    }
    None => ()
  }
}
