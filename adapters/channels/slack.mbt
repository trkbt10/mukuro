///|
/// Slack App チャネル設定
pub(all) struct SlackChannelConfig {
  /// チャネル名
  name : String
  /// Bot Token (xoxb-...)
  bot_token : String
  /// App Token (xapp-...) for Socket Mode
  app_token : String?
  /// Signing Secret
  signing_secret : String?
  /// API Base URL
  api_base_url : String
  /// 基本設定
  base : ChannelBaseConfig
}

///|
/// デフォルト設定
pub fn SlackChannelConfig::default(
  name~ : String,
  bot_token~ : String,
) -> SlackChannelConfig {
  {
    name,
    bot_token,
    app_token: None,
    signing_secret: None,
    api_base_url: "https://slack.com/api",
    base: ChannelBaseConfig::default(name~),
  }
}

///|
/// Slack App チャネルアダプタ
pub struct SlackChannelAdapter {
  config : SlackChannelConfig
  mut status : ChannelStatus
  /// Socket Mode WebSocket接続
  mut socket : JsWebSocket?
  /// 受信キュー
  received_messages : Array[@types.InboundEnvelope]
}

///|
/// SlackChannelAdapterを新規作成
pub fn SlackChannelAdapter::new(
  config : SlackChannelConfig,
) -> SlackChannelAdapter {
  {
    config,
    status: ChannelStatus::Disconnected,
    socket: None,
    received_messages: [],
  }
}

///|
/// ChannelAdapter実装
pub impl @interfaces.ChannelAdapter for SlackChannelAdapter with name(self) {
  self.config.name
}

///|
pub impl @interfaces.ChannelAdapter for SlackChannelAdapter with connect(self) {
  // Socket Modeの場合はWebSocket接続を開始
  match self.config.app_token {
    Some(app_token) => {
      // apps.connections.open を呼び出してWebSocket URLを取得
      let api_url = "\{self.config.api_base_url}/apps.connections.open"
      let headers : Map[String, String] = {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": "Bearer \{app_token}",
      }
      let body = @js.js_text_encode("")
      let channel_name = self.config.name
      let received = self.received_messages
      @js.fetch_with_callback(
        api_url,
        "POST",
        headers,
        Some(body),
        fn(response) {
          let body_str = response.body.to_unchecked_string()
          let json : Json = @json.parse(body_str) catch { _ => return }
          match json {
            { "ok": True, "url": String(ws_url), .. } => {
              let ws = js_websocket_create(ws_url)
              self.socket = Some(ws)
              self.status = ChannelStatus::Connecting
              js_websocket_on_open(ws, fn() {
                self.status = ChannelStatus::Connected
              })
              js_websocket_on_message(ws, fn(data) {
                let payload : Json = @json.parse(data) catch { _ => return }
                // envelope_idがある場合はACKを返す
                match payload {
                  { "envelope_id": String(envelope_id), .. } =>
                    match self.socket {
                      Some(socket) => {
                        let ack : Json = { "envelope_id": envelope_id }
                        js_websocket_send(socket, ack.stringify())
                      }
                      None => ()
                    }
                  _ => ()
                }
                // イベントタイプをチェック
                match payload {
                  { "type": String("events_api"), "payload": event_payload, .. } =>
                    match event_payload {
                      { "event": event, .. } =>
                        match event {
                          { "type": String("message"), .. } =>
                            // Botからのメッセージは無視
                            match event {
                              { "bot_id": _, .. } => ()
                              { "subtype": _, .. } => ()
                              _ => {
                                let chat_id = match event {
                                  { "channel": String(ch), .. } => ch
                                  _ => return
                                }
                                let sender_id = match event {
                                  { "user": String(u), .. } => u
                                  _ => "unknown"
                                }
                                let content = match event {
                                  { "text": String(t), .. } => t
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
                          _ => ()
                        }
                      _ => ()
                    }
                  _ => ()
                }
              })
              js_websocket_on_close(ws, fn() {
                self.status = ChannelStatus::Disconnected
              })
              js_websocket_on_error(ws, fn() {
                self.status = ChannelStatus::Error("Slack socket error")
              })
            }
            _ => self.status = ChannelStatus::Error("Failed to open connection")
          }
        },
        fn(_error) {
          self.status = ChannelStatus::Error("Failed to connect to Slack")
        },
      )
    }
    None =>
      // Events APIモード（Webhookベース）
      self.status = ChannelStatus::Connected
  }
}

///|
pub impl @interfaces.ChannelAdapter for SlackChannelAdapter with disconnect(
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
pub impl @interfaces.ChannelAdapter for SlackChannelAdapter with is_connected(
  self,
) {
  match self.status {
    ChannelStatus::Connected => true
    _ => false
  }
}

///|
pub impl @interfaces.ChannelAdapter for SlackChannelAdapter with send(
  self,
  message,
) {
  let api_url = "\{self.config.api_base_url}/chat.postMessage"
  let payload : Json = { "channel": message.chat_id, "text": message.content }
  let headers : Map[String, String] = {
    "Content-Type": "application/json; charset=utf-8",
    "Authorization": "Bearer \{self.config.bot_token}",
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
pub impl @interfaces.ChannelAdapter for SlackChannelAdapter with receive(self) {
  match pop_inbound_envelope(self.received_messages) {
    Some(msg) => msg
    None => raise ChannelError::NetworkError("No messages in queue")
  }
}

///|
/// Events APIリクエスト（Webhook）を処理
pub fn SlackChannelAdapter::handle_webhook(
  self : SlackChannelAdapter,
  request_body : Json,
) -> Json {
  // URL verification
  match request_body {
    { "type": String("url_verification"), "challenge": String(challenge), .. } =>
      return { "challenge": challenge }
    _ => ()
  }
  // イベント処理
  match request_body {
    { "event": event, .. } =>
      match event {
        { "type": String("message"), .. } => {
          // Botからのメッセージは無視
          match event {
            { "bot_id": _, .. } => return {}
            { "subtype": _, .. } => return {}
            _ => ()
          }
          let chat_id = match event {
            { "channel": String(ch), .. } => ch
            _ => return {}
          }
          let sender_id = match event {
            { "user": String(u), .. } => u
            _ => "unknown"
          }
          let content = match event {
            { "text": String(t), .. } => t
            _ => ""
          }
          if content.length() > 0 {
            let envelope : @types.InboundEnvelope = {
              channel: self.config.name,
              chat_id,
              sender_id,
              sender_name: sender_id,
              content,
              message_type: @types.MessageType::Text,
              metadata: {},
              timestamp: @js.js_date_now(),
            }
            self.received_messages.push(envelope)
          }
        }
        _ => ()
      }
    _ => ()
  }
  {}
}
