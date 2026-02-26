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
  /// ポーリングタイムアウト（秒）
  polling_timeout : Int
  /// 許可するupdate types
  allowed_updates : Array[String]
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
    polling_timeout: 30,
    allowed_updates: ["message", "edited_message", "callback_query"],
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
  let payload : Map[String, Json] = {}
  payload["chat_id"] = Json::string(message.chat_id)
  payload["text"] = Json::string(message.content)
  // reply_toがある場合は返信として送信
  match message.reply_to {
    Some(reply_to_id) =>
      payload["reply_to_message_id"] = Json::string(reply_to_id)
    None => ()
  }
  // 注: 添付ファイル送信は send_photo/send_document を直接使用してください
  // OutboundAttachmentはBytesデータを持ち、Telegramへのアップロードには
  // multipart/form-dataが必要なため、ここでは対応しない
  @js.post_json(api_url, Json::object(payload), fn(_) { () }, fn(_) { () })
}

///|
pub impl @interfaces.ChannelAdapter for TelegramChannelAdapter with receive(
  self,
) {
  match @util.pop_first(self.received_messages) {
    Some(msg) => msg
    None => raise ChannelError::NetworkError("No messages in queue")
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
  // コールバッククエリを処理
  match update {
    { "callback_query": query, .. } => self.process_callback_query(query)
    _ => ()
  }
}

///|
/// コールバッククエリを処理
fn TelegramChannelAdapter::process_callback_query(
  self : TelegramChannelAdapter,
  query : Json,
) -> Unit {
  // コールバックデータを抽出
  let callback_data = match query {
    { "data": String(data), .. } => data
    _ => return
  }
  // チャットIDを抽出
  let chat_id = match query {
    { "message": { "chat": { "id": Number(id, ..), .. }, .. }, .. } =>
      id.to_int64().to_string()
    _ => return
  }
  // 送信者IDを抽出
  let sender_id = match query {
    { "from": { "id": Number(id, ..), .. }, .. } => id.to_int64().to_string()
    _ => "unknown"
  }
  // 送信者名を抽出
  let sender_name = match query {
    { "from": from, .. } => extract_sender_name({ "from": from })
    _ => "unknown"
  }
  // メタデータを構築
  let metadata : Map[String, Json] = {}
  match query {
    { "id": String(query_id), .. } =>
      metadata["callback_query_id"] = Json::string(query_id)
    _ => ()
  }
  match query {
    { "message": { "message_id": Number(id, ..), .. }, .. } =>
      metadata["message_id"] = Json::number(id)
    _ => ()
  }
  metadata["is_callback"] = Json::boolean(true)
  // InboundEnvelopeを構築
  let envelope : @types.InboundEnvelope = {
    channel: self.config.name,
    chat_id,
    sender_id,
    sender_name,
    content: callback_data,
    message_type: @types.MessageType::Command(callback_data),
    metadata,
    timestamp: @js.js_date_now(),
  }
  // キューに追加
  self.received_messages.push(envelope)
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
  // 送信者名を抽出（first_name + last_name）
  let sender_name = extract_sender_name(message)
  // メッセージ内容を抽出
  let content = match message {
    { "text": String(text), .. } => text
    { "caption": String(caption), .. } => caption
    _ => ""
  }
  if content.length() == 0 {
    return
  }
  // 添付ファイル情報を抽出
  let attachments = extract_attachments(message)
  // メッセージタイプを判定
  let message_type = if attachments.length() > 0 {
    @types.MessageType::Attachment(attachments)
  } else {
    @types.MessageType::Text
  }
  // メタデータを構築
  let metadata = build_message_metadata(message)
  // InboundEnvelopeを構築
  let envelope : @types.InboundEnvelope = {
    channel: self.config.name,
    chat_id,
    sender_id,
    sender_name,
    content,
    message_type,
    metadata,
    timestamp: @js.js_date_now(),
  }
  // キューに追加
  self.received_messages.push(envelope)
}

///|
/// 送信者名を抽出
fn extract_sender_name(message : Json) -> String {
  match message {
    {
      "from": { "first_name": String(first), "last_name": String(last), .. },
      ..
    } => "\{first} \{last}"
    { "from": { "first_name": String(first), .. }, .. } => first
    { "from": { "username": String(username), .. }, .. } => username
    _ => "unknown"
  }
}

///|
/// 添付ファイル情報を抽出
fn extract_attachments(message : Json) -> Array[@types.AttachmentInfo] {
  let attachments : Array[@types.AttachmentInfo] = []
  // 写真（複数サイズから最大のものを選択）
  match message {
    { "photo": Array(photos), .. } =>
      if photos.length() > 0 {
        let last_photo = photos[photos.length() - 1]
        match last_photo {
          { "file_id": String(file_id), .. } =>
            attachments.push({
              filename: "photo.jpg",
              content_type: "image/jpeg",
              url: "telegram://file/\{file_id}",
              size: extract_file_size(last_photo),
            })
          _ => ()
        }
      }
    _ => ()
  }
  // ドキュメント
  match message {
    { "document": { "file_id": String(file_id), .. } as doc, .. } =>
      attachments.push({
        filename: extract_file_name_or_default(doc, "document"),
        content_type: extract_mime_type_or_default(
          doc, "application/octet-stream",
        ),
        url: "telegram://file/\{file_id}",
        size: extract_file_size(doc),
      })
    _ => ()
  }
  // 音声
  match message {
    { "voice": { "file_id": String(file_id), .. } as voice, .. } =>
      attachments.push({
        filename: "voice.ogg",
        content_type: "audio/ogg",
        url: "telegram://file/\{file_id}",
        size: extract_file_size(voice),
      })
    _ => ()
  }
  // 動画
  match message {
    { "video": { "file_id": String(file_id), .. } as video, .. } =>
      attachments.push({
        filename: extract_file_name_or_default(video, "video.mp4"),
        content_type: extract_mime_type_or_default(video, "video/mp4"),
        url: "telegram://file/\{file_id}",
        size: extract_file_size(video),
      })
    _ => ()
  }
  // 音声メッセージ
  match message {
    { "audio": { "file_id": String(file_id), .. } as audio, .. } =>
      attachments.push({
        filename: extract_file_name_or_default(audio, "audio.mp3"),
        content_type: extract_mime_type_or_default(audio, "audio/mpeg"),
        url: "telegram://file/\{file_id}",
        size: extract_file_size(audio),
      })
    _ => ()
  }
  // ステッカー
  match message {
    { "sticker": { "file_id": String(file_id), .. } as sticker, .. } =>
      attachments.push({
        filename: "sticker.webp",
        content_type: "image/webp",
        url: "telegram://file/\{file_id}",
        size: extract_file_size(sticker),
      })
    _ => ()
  }
  attachments
}

///|
/// ファイル名を抽出（デフォルト値付き）
fn extract_file_name_or_default(file_obj : Json, default : String) -> String {
  match file_obj {
    { "file_name": String(name), .. } => name
    _ => default
  }
}

///|
/// MIMEタイプを抽出（デフォルト値付き）
fn extract_mime_type_or_default(file_obj : Json, default : String) -> String {
  match file_obj {
    { "mime_type": String(mime), .. } => mime
    _ => default
  }
}

///|
/// ファイルサイズを抽出
fn extract_file_size(file_obj : Json) -> Int64 {
  match file_obj {
    { "file_size": Number(size, ..), .. } => size.to_int64()
    _ => 0L
  }
}

///|
/// メッセージメタデータを構築
fn build_message_metadata(message : Json) -> Map[String, Json] {
  let metadata : Map[String, Json] = {}
  // message_id
  match message {
    { "message_id": Number(id, ..), .. } =>
      metadata["message_id"] = Json::number(id)
    _ => ()
  }
  // reply_to_message_id
  match message {
    { "reply_to_message": { "message_id": Number(id, ..), .. }, .. } =>
      metadata["reply_to_message_id"] = Json::number(id)
    _ => ()
  }
  // chat_type
  match message {
    { "chat": { "type": String(chat_type), .. }, .. } =>
      metadata["chat_type"] = Json::string(chat_type)
    _ => ()
  }
  // forward_from
  match message {
    { "forward_from": { "id": Number(id, ..), .. }, .. } =>
      metadata["forward_from_id"] = Json::number(id)
    _ => ()
  }
  metadata
}

///|
/// Pollingでupdatesを取得
pub fn TelegramChannelAdapter::poll_updates(
  self : TelegramChannelAdapter,
) -> Unit {
  let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/getUpdates"
  let allowed_updates_json : Array[Json] = []
  for update_type in self.config.allowed_updates {
    allowed_updates_json.push(Json::string(update_type))
  }
  let payload : Json = {
    "offset": (self.last_update_id + 1L).to_int(),
    "timeout": self.config.polling_timeout,
    "allowed_updates": Json::array(allowed_updates_json),
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

///|
/// 写真を送信
pub fn TelegramChannelAdapter::send_photo(
  self : TelegramChannelAdapter,
  chat_id : String,
  photo_url : String,
  caption? : String = "",
  reply_to? : String? = None,
) -> Unit {
  let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/sendPhoto"
  let payload : Map[String, Json] = {}
  payload["chat_id"] = Json::string(chat_id)
  payload["photo"] = Json::string(photo_url)
  if caption.length() > 0 {
    payload["caption"] = Json::string(caption)
  }
  match reply_to {
    Some(msg_id) => payload["reply_to_message_id"] = Json::string(msg_id)
    None => ()
  }
  @js.post_json(api_url, Json::object(payload), fn(_) { () }, fn(_) { () })
}

///|
/// ドキュメントを送信
pub fn TelegramChannelAdapter::send_document(
  self : TelegramChannelAdapter,
  chat_id : String,
  document_url : String,
  caption? : String = "",
  reply_to? : String? = None,
) -> Unit {
  let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/sendDocument"
  let payload : Map[String, Json] = {}
  payload["chat_id"] = Json::string(chat_id)
  payload["document"] = Json::string(document_url)
  if caption.length() > 0 {
    payload["caption"] = Json::string(caption)
  }
  match reply_to {
    Some(msg_id) => payload["reply_to_message_id"] = Json::string(msg_id)
    None => ()
  }
  @js.post_json(api_url, Json::object(payload), fn(_) { () }, fn(_) { () })
}

///|
/// メッセージを返信付きで送信
pub fn TelegramChannelAdapter::send_reply(
  self : TelegramChannelAdapter,
  chat_id : String,
  text : String,
  reply_to_message_id : String,
) -> Unit {
  let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/sendMessage"
  let payload : Json = {
    "chat_id": chat_id,
    "text": text,
    "reply_to_message_id": reply_to_message_id,
  }
  @js.post_json(api_url, payload, fn(_) { () }, fn(_) { () })
}

///|
/// file_idからダウンロードURLを取得
pub fn TelegramChannelAdapter::get_file_url(
  self : TelegramChannelAdapter,
  file_id : String,
  on_success : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/getFile"
  let payload : Json = { "file_id": file_id }
  @js.post_json(
    api_url,
    payload,
    fn(response) {
      match response {
        { "ok": True, "result": { "file_path": String(file_path), .. }, .. } => {
          let download_url = "\{self.config.api_base_url}/file/bot\{self.config.bot_token}/\{file_path}"
          on_success(download_url)
        }
        { "description": String(desc), .. } => on_error(desc)
        _ => on_error("Failed to get file")
      }
    },
    on_error,
  )
}

///|
/// コールバッククエリに応答
pub fn TelegramChannelAdapter::answer_callback_query(
  self : TelegramChannelAdapter,
  callback_query_id : String,
  text? : String = "",
  show_alert? : Bool = false,
) -> Unit {
  let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/answerCallbackQuery"
  let payload : Json = {
    "callback_query_id": callback_query_id,
    "text": text,
    "show_alert": show_alert,
  }
  @js.post_json(api_url, payload, fn(_) { () }, fn(_) { () })
}

///|
/// インラインキーボード付きメッセージを送信
pub fn TelegramChannelAdapter::send_with_keyboard(
  self : TelegramChannelAdapter,
  chat_id : String,
  text : String,
  keyboard : Array[Array[InlineKeyboardButton]],
) -> Unit {
  let api_url = "\{self.config.api_base_url}/bot\{self.config.bot_token}/sendMessage"
  // キーボードをJSONに変換
  let keyboard_json : Array[Json] = []
  for row in keyboard {
    let row_json : Array[Json] = []
    for button in row {
      let btn : Map[String, Json] = {}
      btn["text"] = Json::string(button.text)
      match button.callback_data {
        Some(data) => btn["callback_data"] = Json::string(data)
        None => ()
      }
      match button.url {
        Some(url) => btn["url"] = Json::string(url)
        None => ()
      }
      row_json.push(Json::object(btn))
    }
    keyboard_json.push(Json::array(row_json))
  }
  let payload : Json = {
    "chat_id": chat_id,
    "text": text,
    "reply_markup": { "inline_keyboard": Json::array(keyboard_json) },
  }
  @js.post_json(api_url, payload, fn(_) { () }, fn(_) { () })
}

///|
/// インラインキーボードのボタン
pub(all) struct InlineKeyboardButton {
  text : String
  callback_data : String?
  url : String?
}

///|
/// InlineKeyboardButtonを作成（コールバックデータ付き）
pub fn InlineKeyboardButton::callback(
  text : String,
  data : String,
) -> InlineKeyboardButton {
  { text, callback_data: Some(data), url: None }
}

///|
/// InlineKeyboardButtonを作成（URL付き）
pub fn InlineKeyboardButton::link(
  text : String,
  url : String,
) -> InlineKeyboardButton {
  { text, callback_data: None, url: Some(url) }
}
