///|
/// HTTP/REST チャネル設定
pub(all) struct HttpChannelConfig {
  /// チャネル名
  name : String
  /// 認証トークン（オプション）
  auth_token : String?
  /// Webhook URL（outbound用）
  webhook_url : String?
  /// 基本設定
  base : ChannelBaseConfig
}

///|
/// デフォルト設定
pub fn HttpChannelConfig::default(name~ : String) -> HttpChannelConfig {
  {
    name,
    auth_token: None,
    webhook_url: None,
    base: ChannelBaseConfig::default(name~),
  }
}

///|
/// HTTP チャネルアダプタ
/// RESTful APIベースのメッセージ送受信
pub struct HttpChannelAdapter {
  config : HttpChannelConfig
  mut status : ChannelStatus
  /// 受信キュー（ポーリング用）
  received_messages : Array[@types.InboundEnvelope]
}

///|
/// HttpChannelAdapterを新規作成
pub fn HttpChannelAdapter::new(
  config : HttpChannelConfig,
) -> HttpChannelAdapter {
  { config, status: ChannelStatus::Disconnected, received_messages: [] }
}

///|
/// ChannelAdapter実装
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with name(self) {
  self.config.name
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with connect(self) {
  // HTTPはステートレスなので接続処理は不要
  self.status = ChannelStatus::Connected
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with disconnect(self) {
  self.status = ChannelStatus::Disconnected
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with is_connected(
  self,
) {
  match self.status {
    ChannelStatus::Connected => true
    _ => false
  }
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with send(
  self,
  message,
) {
  // Webhook URLが設定されている場合はPOSTリクエストを送信
  match self.config.webhook_url {
    Some(url) => {
      let payload = outbound_to_json(message)
      let headers : Map[String, String] = { "Content-Type": "application/json" }
      // 認証トークンを追加
      match self.config.auth_token {
        Some(token) => headers["Authorization"] = "Bearer \{token}"
        None => ()
      }
      @js.post_json(
        url,
        payload,
        fn(_response) {
          // 送信成功
          ()
        },
        fn(_error) {
          // 送信失敗
          ()
        },
      )
    }
    None =>
      // Webhook URLが未設定の場合は何もしない
      ()
  }
}

///|
pub impl @interfaces.ChannelAdapter for HttpChannelAdapter with receive(self) {
  match @util.pop_first(self.received_messages) {
    Some(msg) => msg
    None => raise ChannelError::NetworkError("No messages in queue")
  }
}

///|
/// HTTPリクエストを処理してInboundEnvelopeを生成
pub fn HttpChannelAdapter::handle_request(
  self : HttpChannelAdapter,
  request_body : Json,
  chat_id : String,
  sender_id : String,
) -> Unit {
  // JSONからメッセージを抽出
  let content = match request_body {
    { "content": String(c), .. } => c
    { "message": String(m), .. } => m
    { "text": String(t), .. } => t
    _ => request_body.stringify()
  }
  // InboundEnvelopeを構築
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
  // キューに追加
  self.received_messages.push(envelope)
}

///|
/// OutboundMessageをJSONに変換
fn outbound_to_json(message : @types.OutboundMessage) -> Json {
  {
    "channel": message.channel,
    "chat_id": message.chat_id,
    "content": message.content,
  }
}
