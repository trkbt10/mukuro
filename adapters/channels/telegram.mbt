///|
/// Telegram Bot チャネル設定
pub(all) struct TelegramChannelConfig {
  /// チャネル名
  name : String
  /// Bot Token
  bot_token : String
  /// Webhook URL（webhook mode用）
  webhook_url : String?
  /// API Base URL
  api_base_url : String
  /// 基本設定
  base : ChannelBaseConfig
}

///|
/// デフォルト設定
pub fn TelegramChannelConfig::default(
  name~ : String,
  bot_token~ : String,
) -> TelegramChannelConfig {
  {
    name,
    bot_token,
    webhook_url: None,
    api_base_url: "https://api.telegram.org",
    base: ChannelBaseConfig::default(name~),
  }
}

///|
/// Telegram Bot チャネルアダプタ
pub struct TelegramChannelAdapter {
  config : TelegramChannelConfig
  mut status : ChannelStatus
  /// 最後に処理したupdate_id
  mut last_update_id : Int64
  /// 受信キュー
  received_messages : Array[@types.InboundEnvelope]
}

///|
/// TelegramChannelAdapterを新規作成
pub fn TelegramChannelAdapter::new(
  config : TelegramChannelConfig,
) -> TelegramChannelAdapter {
  {
    config,
    status: ChannelStatus::Disconnected,
    last_update_id: 0L,
    received_messages: [],
  }
}

///|
/// ChannelAdapter実装
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with name(self) {
  self.config.name
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with connect(
  self,
) {
  // Webhookモードの場合はWebhookを設定
  match self.config.webhook_url {
    Some(url) => {
      let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/setWebhook"
      let payload : Json = { "url": url }
      @js.post_json(
        api_url,
        payload,
        fn(_response) { self.status = ChannelStatus::Connected },
        fn(_error) {
          self.status = ChannelStatus::Error("Failed to set webhook")
        },
      )
    }
    None =>
      // Pollingモードは別途実装が必要
      self.status = ChannelStatus::Connected
  }
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with disconnect(
  self,
) {
  // Webhookを削除
  match self.config.webhook_url {
    Some(_) => {
      let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/deleteWebhook"
      @js.post_json(api_url, {}, fn(_) { () }, fn(_) { () })
    }
    None => ()
  }
  self.status = ChannelStatus::Disconnected
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with is_connected(
  self,
) {
  match self.status {
    ChannelStatus::Connected => true
    _ => false
  }
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with send(
  self,
  message,
) {
  let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/sendMessage"
  let payload : Json = { "chat_id": message.chat_id, "text": message.content }
  @js.post_json(api_url, payload, fn(_) { () }, fn(_) { () })
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with receive(
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
    raise ChannelError::NetworkError("No messages in queue")
  }
}

///|
/// Webhook経由で受信したupdateを処理
pub fn TelegramChannelAdapter::handle_update(
  self : TelegramChannelAdapter,
  update : Json,
) -> Unit {
  // update_idを更新
  match update {
    { "update_id": Number(id, ..), .. } => self.last_update_id = id.to_int64()
    _ => ()
  }
  // メッセージを抽出
  let message = match update {
    { "message": msg, .. } => Some(msg)
    { "edited_message": msg, .. } => Some(msg)
    _ => None
  }
  match message {
    Some(msg) => self.process_message(msg)
    None => ()
  }
}

///|
/// Telegramメッセージを処理
fn TelegramChannelAdapter::process_message(
  self : TelegramChannelAdapter,
  message : Json,
) -> Unit {
  // チャットIDを抽出
  let chat_id = match message {
    { "chat": { "id": Number(id, ..), .. }, .. } => id.to_int64().to_string()
    _ => return
  }
  // 送信者IDを抽出
  let sender_id = match message {
    { "from": { "id": Number(id, ..), .. }, .. } => id.to_int64().to_string()
    _ => "unknown"
  }
  // メッセージ内容を抽出
  let content = match message {
    { "text": String(text), .. } => text
    { "caption": String(caption), .. } => caption
    _ => ""
  }
  if content.length() == 0 {
    return
  }
  // メッセージタイプを判定（添付ファイルがある場合はAttachment）
  let message_type = match message {
    { "photo": _, .. }
    | { "document": _, .. }
    | { "voice": _, .. }
    | { "video": _, .. } => @types.MessageType::Attachment([])
    _ => @types.MessageType::Text
  }
  // InboundEnvelopeを構築
  let envelope : @types.InboundEnvelope = {
    channel: self.config.name,
    chat_id,
    sender_id,
    sender_name: sender_id,
    content,
    message_type,
    metadata: {},
    timestamp: @js.js_date_now(),
  }
  // キューに追加
  self.received_messages.push(envelope)
}

///|
/// Pollingでupdatesを取得
pub fn TelegramChannelAdapter::poll_updates(
  self : TelegramChannelAdapter,
) -> Unit {
  let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/getUpdates"
  let payload : Json = {
    "offset": (self.last_update_id + 1L).to_int(),
    "timeout": 30,
  }
  @js.post_json(
    api_url,
    payload,
    fn(response) {
      match response {
        { "ok": True, "result": Array(updates), .. } =>
          for update in updates {
            self.handle_update(update)
          }
        _ => ()
      }
    },
    fn(_error) { () },
  )
}
