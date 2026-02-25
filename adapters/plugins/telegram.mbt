///|
/// Telegram Bot API Plugin
/// Provides Telegram messaging via Bot API

///|
/// Telegram message types
pub(all) enum TelegramMessageType {
  /// Text message
  Text
  /// Photo message
  Photo
  /// Document message
  Document
  /// Audio message
  Audio
  /// Video message
  Video
  /// Voice message
  Voice
  /// Video note (circular video)
  VideoNote
  /// Location message
  Location
  /// Venue message
  Venue
  /// Contact message
  Contact
  /// Sticker message
  Sticker
  /// Animation (GIF)
  Animation
  /// Poll
  Poll
}

///|
/// Telegram photo size
pub(all) struct TelegramPhoto {
  /// File ID
  file_id : String
  /// File unique ID
  file_unique_id : String
  /// Photo width
  width : Int
  /// Photo height
  height : Int
  /// File size in bytes
  file_size : Int?
}

///|
/// Telegram document
pub(all) struct TelegramDocument {
  /// File ID
  file_id : String
  /// File unique ID
  file_unique_id : String
  /// File name
  file_name : String?
  /// MIME type
  mime_type : String?
  /// File size in bytes
  file_size : Int?
}

///|
/// Telegram message
pub(all) struct TelegramMessage {
  /// Message ID
  message_id : Int
  /// Chat ID
  chat_id : Int64
  /// Sender user ID
  from_id : Int64?
  /// Sender username
  from_username : String?
  /// Sender display name
  from_name : String
  /// Message type
  message_type : TelegramMessageType
  /// Text content
  text : String
  /// Caption (for media messages)
  caption : String?
  /// Photo array (for photo messages)
  photo : Array[TelegramPhoto]?
  /// Document (for document messages)
  document : TelegramDocument?
  /// Reply to message ID
  reply_to_message_id : Int?
  /// Timestamp (Unix seconds)
  timestamp : Int64
}

///|
/// Telegram inline keyboard button
pub(all) struct TelegramInlineButton {
  /// Button text
  text : String
  /// Callback data
  callback_data : String?
  /// URL to open
  url : String?
}

///|
/// Telegram reply keyboard button
pub(all) struct TelegramKeyboardButton {
  /// Button text
  text : String
  /// Request contact
  request_contact : Bool
  /// Request location
  request_location : Bool
}

///|
/// Telegram plugin configuration
pub(all) struct TelegramPluginConfig {
  /// Plugin name
  name : String
  /// Bot token
  bot_token : String
  /// Webhook URL (for webhook mode)
  webhook_url : String?
  /// API base URL (default: https://api.telegram.org)
  api_base_url : String
}

///|
/// Default Telegram plugin config
pub fn TelegramPluginConfig::default(
  name~ : String,
  bot_token~ : String,
) -> TelegramPluginConfig {
  {
    name,
    bot_token,
    webhook_url: None,
    api_base_url: "https://api.telegram.org",
  }
}

///|
/// Telegram plugin
pub struct TelegramPlugin {
  config : TelegramPluginConfig
  /// Received messages buffer
  received_messages : Array[TelegramMessage]
  /// Connection state
  mut is_connected : Bool
  /// Current timestamp provider
  mut get_timestamp : () -> Int64
  /// Last update ID (for long polling)
  last_update_id : Int64
}

///|
/// Create new Telegram plugin
pub fn TelegramPlugin::new(config : TelegramPluginConfig) -> TelegramPlugin {
  {
    config,
    received_messages: [],
    is_connected: false,
    get_timestamp: fn() { 0L },
    last_update_id: 0L,
  }
}

///|
/// Set timestamp provider (for testing)
pub fn TelegramPlugin::set_timestamp_provider(
  self : TelegramPlugin,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Connect to Telegram
pub fn TelegramPlugin::connect(self : TelegramPlugin) -> Unit {
  self.is_connected = true
}

///|
/// Disconnect from Telegram
pub fn TelegramPlugin::disconnect(self : TelegramPlugin) -> Unit {
  self.is_connected = false
}

///|
/// Check if connected
pub fn TelegramPlugin::is_connected(self : TelegramPlugin) -> Bool {
  self.is_connected
}

///|
/// Get API URL
fn TelegramPlugin::api_url(
  self : TelegramPlugin,
  api_method : String,
) -> String {
  "\{self.config.api_base_url}/bot\{self.config.bot_token}/\{api_method}"
}

///|
/// Send a text message
pub fn TelegramPlugin::send_message(
  self : TelegramPlugin,
  chat_id : Int64,
  text : String,
  reply_to_message_id? : Int? = None,
  parse_mode? : String? = None,
  disable_notification? : Bool = false,
) -> Json {
  let params : Map[String, Json] = {
    "chat_id": Json::number(chat_id.to_double()),
    "text": Json::string(text),
  }
  match reply_to_message_id {
    Some(id) => params["reply_to_message_id"] = Json::number(id.to_double())
    None => ()
  }
  match parse_mode {
    Some(mode) => params["parse_mode"] = Json::string(mode)
    None => ()
  }
  if disable_notification {
    params["disable_notification"] = Json::boolean(true)
  }
  // Return request parameters (actual HTTP call would be done by caller)
  Json::object({
    "method": "sendMessage",
    "url": Json::string(self.api_url("sendMessage")),
    "params": Json::object(params),
  })
}

///|
/// Send a photo
pub fn TelegramPlugin::send_photo(
  self : TelegramPlugin,
  chat_id : Int64,
  photo : String,
  caption? : String? = None,
  reply_to_message_id? : Int? = None,
) -> Json {
  let params : Map[String, Json] = {
    "chat_id": Json::number(chat_id.to_double()),
    "photo": Json::string(photo),
  }
  match caption {
    Some(cap) => params["caption"] = Json::string(cap)
    None => ()
  }
  match reply_to_message_id {
    Some(id) => params["reply_to_message_id"] = Json::number(id.to_double())
    None => ()
  }
  Json::object({
    "method": "sendPhoto",
    "url": Json::string(self.api_url("sendPhoto")),
    "params": Json::object(params),
  })
}

///|
/// Send a document
pub fn TelegramPlugin::send_document(
  self : TelegramPlugin,
  chat_id : Int64,
  document : String,
  caption? : String? = None,
) -> Json {
  let params : Map[String, Json] = {
    "chat_id": Json::number(chat_id.to_double()),
    "document": Json::string(document),
  }
  match caption {
    Some(cap) => params["caption"] = Json::string(cap)
    None => ()
  }
  Json::object({
    "method": "sendDocument",
    "url": Json::string(self.api_url("sendDocument")),
    "params": Json::object(params),
  })
}

///|
/// Send a location
pub fn TelegramPlugin::send_location(
  self : TelegramPlugin,
  chat_id : Int64,
  latitude : Double,
  longitude : Double,
) -> Json {
  Json::object({
    "method": "sendLocation",
    "url": Json::string(self.api_url("sendLocation")),
    "params": {
      "chat_id": Json::number(chat_id.to_double()),
      "latitude": Json::number(latitude),
      "longitude": Json::number(longitude),
    },
  })
}

///|
/// Edit a message
pub fn TelegramPlugin::edit_message(
  self : TelegramPlugin,
  chat_id : Int64,
  message_id : Int,
  text : String,
  parse_mode? : String? = None,
) -> Json {
  let params : Map[String, Json] = {
    "chat_id": Json::number(chat_id.to_double()),
    "message_id": Json::number(message_id.to_double()),
    "text": Json::string(text),
  }
  match parse_mode {
    Some(mode) => params["parse_mode"] = Json::string(mode)
    None => ()
  }
  Json::object({
    "method": "editMessageText",
    "url": Json::string(self.api_url("editMessageText")),
    "params": Json::object(params),
  })
}

///|
/// Delete a message
pub fn TelegramPlugin::delete_message(
  self : TelegramPlugin,
  chat_id : Int64,
  message_id : Int,
) -> Json {
  Json::object({
    "method": "deleteMessage",
    "url": Json::string(self.api_url("deleteMessage")),
    "params": {
      "chat_id": Json::number(chat_id.to_double()),
      "message_id": Json::number(message_id.to_double()),
    },
  })
}

///|
/// Send inline keyboard
pub fn TelegramPlugin::send_inline_keyboard(
  self : TelegramPlugin,
  chat_id : Int64,
  text : String,
  keyboard : Array[Array[TelegramInlineButton]],
) -> Json {
  let rows : Array[Json] = []
  for row in keyboard {
    let buttons : Array[Json] = []
    for button in row {
      let btn : Map[String, Json] = { "text": Json::string(button.text) }
      match button.callback_data {
        Some(data) => btn["callback_data"] = Json::string(data)
        None => ()
      }
      match button.url {
        Some(url) => btn["url"] = Json::string(url)
        None => ()
      }
      buttons.push(Json::object(btn))
    }
    rows.push(Json::array(buttons))
  }
  Json::object({
    "method": "sendMessage",
    "url": Json::string(self.api_url("sendMessage")),
    "params": {
      "chat_id": Json::number(chat_id.to_double()),
      "text": Json::string(text),
      "reply_markup": { "inline_keyboard": Json::array(rows) },
    },
  })
}

///|
/// Process incoming webhook update
pub fn TelegramPlugin::process_webhook(
  self : TelegramPlugin,
  update : Json,
) -> TelegramMessage? {
  match update {
    Object(obj) =>
      match obj.get("message") {
        Some(Object(msg)) => self.parse_message(msg)
        _ => None
      }
    _ => None
  }
}

///|
/// Parse a Telegram message from JSON
fn TelegramPlugin::parse_message(
  self : TelegramPlugin,
  msg : Map[String, Json],
) -> TelegramMessage? {
  // Extract message_id
  let message_id = match msg.get("message_id") {
    Some(Number(n, ..)) => n.to_int()
    _ => return None
  }
  // Extract chat_id
  let chat_id : Int64 = match msg.get("chat") {
    Some(Object(chat)) =>
      match chat.get("id") {
        Some(Number(n, ..)) => n.to_int64()
        _ => return None
      }
    _ => return None
  }
  // Extract from
  let (from_id, from_username, from_name) = match msg.get("from") {
    Some(Object(from)) => {
      let id : Int64? = match from.get("id") {
        Some(Number(n, ..)) => Some(n.to_int64())
        _ => None
      }
      let username : String? = match from.get("username") {
        Some(String(u)) => Some(u)
        _ => None
      }
      let first_name = match from.get("first_name") {
        Some(String(n)) => n
        _ => ""
      }
      let last_name = match from.get("last_name") {
        Some(String(n)) => " \{n}"
        _ => ""
      }
      (id, username, "\{first_name}\{last_name}")
    }
    _ => (None, None, "Unknown")
  }
  // Extract text
  let text = match msg.get("text") {
    Some(String(t)) => t
    _ => ""
  }
  // Extract caption
  let caption : String? = match msg.get("caption") {
    Some(String(c)) => Some(c)
    _ => None
  }
  // Extract timestamp
  let timestamp : Int64 = match msg.get("date") {
    Some(Number(n, ..)) => n.to_int64()
    _ => (self.get_timestamp)()
  }
  // Extract reply_to_message_id
  let reply_to_message_id : Int? = match msg.get("reply_to_message") {
    Some(Object(reply)) =>
      match reply.get("message_id") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
  // Determine message type and extract media
  let (message_type, photo, document) = if msg.contains("photo") {
    (TelegramMessageType::Photo, parse_photo_array(msg.get("photo")), None)
  } else if msg.contains("document") {
    (TelegramMessageType::Document, None, parse_document(msg.get("document")))
  } else if msg.contains("audio") {
    (TelegramMessageType::Audio, None, None)
  } else if msg.contains("video") {
    (TelegramMessageType::Video, None, None)
  } else if msg.contains("voice") {
    (TelegramMessageType::Voice, None, None)
  } else if msg.contains("sticker") {
    (TelegramMessageType::Sticker, None, None)
  } else if msg.contains("location") {
    (TelegramMessageType::Location, None, None)
  } else {
    (TelegramMessageType::Text, None, None)
  }
  Some({
    message_id,
    chat_id,
    from_id,
    from_username,
    from_name,
    message_type,
    text,
    caption,
    photo,
    document,
    reply_to_message_id,
    timestamp,
  })
}

///|
/// Parse photo array from JSON
fn parse_photo_array(json : Json?) -> Array[TelegramPhoto]? {
  match json {
    Some(Array(photos)) => {
      let result : Array[TelegramPhoto] = []
      for photo in photos {
        match photo {
          Object(p) => {
            let file_id = match p.get("file_id") {
              Some(String(id)) => id
              _ => continue
            }
            let file_unique_id = match p.get("file_unique_id") {
              Some(String(id)) => id
              _ => ""
            }
            let width = match p.get("width") {
              Some(Number(n, ..)) => n.to_int()
              _ => 0
            }
            let height = match p.get("height") {
              Some(Number(n, ..)) => n.to_int()
              _ => 0
            }
            let file_size : Int? = match p.get("file_size") {
              Some(Number(n, ..)) => Some(n.to_int())
              _ => None
            }
            result.push({ file_id, file_unique_id, width, height, file_size })
          }
          _ => ()
        }
      }
      if result.length() > 0 {
        Some(result)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Parse document from JSON
fn parse_document(json : Json?) -> TelegramDocument? {
  match json {
    Some(Object(doc)) => {
      let file_id = match doc.get("file_id") {
        Some(String(id)) => id
        _ => return None
      }
      let file_unique_id = match doc.get("file_unique_id") {
        Some(String(id)) => id
        _ => ""
      }
      let file_name : String? = match doc.get("file_name") {
        Some(String(n)) => Some(n)
        _ => None
      }
      let mime_type : String? = match doc.get("mime_type") {
        Some(String(m)) => Some(m)
        _ => None
      }
      let file_size : Int? = match doc.get("file_size") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
      Some({ file_id, file_unique_id, file_name, mime_type, file_size })
    }
    _ => None
  }
}

///|
/// Receive a message (from buffer)
pub fn TelegramPlugin::receive(self : TelegramPlugin) -> TelegramMessage? {
  @util.pop_first(self.received_messages)
}

///|
/// Add message to receive buffer (for testing/simulation)
pub fn TelegramPlugin::add_received_message(
  self : TelegramPlugin,
  message : TelegramMessage,
) -> Unit {
  self.received_messages.push(message)
}

///|
/// Convert TelegramMessage to JSON
fn telegram_message_to_json(msg : TelegramMessage) -> Json {
  let result : Map[String, Json] = {
    "message_id": Json::number(msg.message_id.to_double()),
    "chat_id": Json::number(msg.chat_id.to_double()),
    "from_name": Json::string(msg.from_name),
    "text": Json::string(msg.text),
    "timestamp": Json::number(msg.timestamp.to_double()),
  }
  match msg.from_id {
    Some(id) => result["from_id"] = Json::number(id.to_double())
    None => ()
  }
  match msg.from_username {
    Some(username) => result["from_username"] = Json::string(username)
    None => ()
  }
  match msg.caption {
    Some(cap) => result["caption"] = Json::string(cap)
    None => ()
  }
  match msg.reply_to_message_id {
    Some(id) => result["reply_to_message_id"] = Json::number(id.to_double())
    None => ()
  }
  // Add message type
  let type_str = match msg.message_type {
    Text => "text"
    Photo => "photo"
    Document => "document"
    Audio => "audio"
    Video => "video"
    Voice => "voice"
    VideoNote => "video_note"
    Location => "location"
    Venue => "venue"
    Contact => "contact"
    Sticker => "sticker"
    Animation => "animation"
    Poll => "poll"
  }
  result["message_type"] = Json::string(type_str)
  Json::object(result)
}

///|
/// Handle JSON-RPC request
pub fn TelegramPlugin::handle_request(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "send_message" => self.handle_send_message(request)
    "send_photo" => self.handle_send_photo(request)
    "send_document" => self.handle_send_document(request)
    "send_location" => self.handle_send_location(request)
    "edit_message" => self.handle_edit_message(request)
    "delete_message" => self.handle_delete_message(request)
    "send_inline_keyboard" => self.handle_send_inline_keyboard(request)
    "webhook" => self.handle_webhook(request)
    "receive" => self.handle_receive(request)
    "connect" => self.handle_connect(request)
    "disconnect" => self.handle_disconnect(request)
    "status" => self.handle_status(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn TelegramPlugin::handle_send_message(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let chat_id = match @interfaces.rpc_require_int64(request, "chat_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let text = match @interfaces.rpc_require_string(request, "text") {
    Ok(t) => t
    Err(response) => return response
  }
  let reply_to = @interfaces.rpc_int_or_none(request, "reply_to_message_id")
  let parse_mode = @interfaces.rpc_string_or_none(request, "parse_mode")
  let disable_notification = @interfaces.rpc_optional_bool(
    request, "disable_notification", false,
  )
  let result = self.send_message(
    chat_id,
    text,
    reply_to_message_id=reply_to,
    parse_mode~,
    disable_notification~,
  )
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn TelegramPlugin::handle_send_photo(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let chat_id = match @interfaces.rpc_require_int64(request, "chat_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let photo = match @interfaces.rpc_require_string(request, "photo") {
    Ok(p) => p
    Err(response) => return response
  }
  let caption = @interfaces.rpc_string_or_none(request, "caption")
  let reply_to = @interfaces.rpc_int_or_none(request, "reply_to_message_id")
  let result = self.send_photo(
    chat_id,
    photo,
    caption~,
    reply_to_message_id=reply_to,
  )
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn TelegramPlugin::handle_send_document(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let chat_id = match @interfaces.rpc_require_int64(request, "chat_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let document = match @interfaces.rpc_require_string(request, "document") {
    Ok(d) => d
    Err(response) => return response
  }
  let caption = @interfaces.rpc_string_or_none(request, "caption")
  let result = self.send_document(chat_id, document, caption~)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn TelegramPlugin::handle_send_location(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let chat_id = match @interfaces.rpc_require_int64(request, "chat_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let latitude = match @interfaces.rpc_require_double(request, "latitude") {
    Ok(l) => l
    Err(response) => return response
  }
  let longitude = match @interfaces.rpc_require_double(request, "longitude") {
    Ok(l) => l
    Err(response) => return response
  }
  let result = self.send_location(chat_id, latitude, longitude)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn TelegramPlugin::handle_edit_message(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let chat_id = match @interfaces.rpc_require_int64(request, "chat_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let message_id = match @interfaces.rpc_require_int(request, "message_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let text = match @interfaces.rpc_require_string(request, "text") {
    Ok(t) => t
    Err(response) => return response
  }
  let parse_mode = @interfaces.rpc_string_or_none(request, "parse_mode")
  let result = self.edit_message(chat_id, message_id, text, parse_mode~)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn TelegramPlugin::handle_delete_message(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let chat_id = match @interfaces.rpc_require_int64(request, "chat_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let message_id = match @interfaces.rpc_require_int(request, "message_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let result = self.delete_message(chat_id, message_id)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn TelegramPlugin::handle_send_inline_keyboard(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let chat_id = match @interfaces.rpc_require_int64(request, "chat_id") {
    Ok(id) => id
    Err(response) => return response
  }
  let text = match @interfaces.rpc_require_string(request, "text") {
    Ok(t) => t
    Err(response) => return response
  }
  // Parse keyboard from params
  let keyboard : Array[Array[TelegramInlineButton]] = []
  match @interfaces.rpc_get_params(request) {
    Some(params) =>
      match params.get("keyboard") {
        Some(Array(rows)) =>
          for row_json in rows {
            let row : Array[TelegramInlineButton] = []
            match row_json {
              Array(buttons) =>
                for btn_json in buttons {
                  match btn_json {
                    Object(btn) => {
                      let text_val = match btn.get("text") {
                        Some(String(t)) => t
                        _ => continue
                      }
                      let callback_data : String? = match
                        btn.get("callback_data") {
                        Some(String(d)) => Some(d)
                        _ => None
                      }
                      let url : String? = match btn.get("url") {
                        Some(String(u)) => Some(u)
                        _ => None
                      }
                      row.push({ text: text_val, callback_data, url })
                    }
                    _ => ()
                  }
                }
              _ => ()
            }
            if row.length() > 0 {
              keyboard.push(row)
            }
          }
        _ => ()
      }
    None => ()
  }
  let result = self.send_inline_keyboard(chat_id, text, keyboard)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn TelegramPlugin::handle_webhook(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match @interfaces.rpc_get_params(request) {
    Some(params) =>
      match params.get("update") {
        Some(update) =>
          match self.process_webhook(update) {
            Some(msg) => {
              self.received_messages.push(msg)
              @interfaces.rpc_ok(request.id)
            }
            None =>
              @interfaces.rpc_invalid_params(
                "Invalid update format",
                request.id,
              )
          }
        None =>
          @interfaces.rpc_invalid_params(
            "Missing 'update' parameter",
            request.id,
          )
      }
    None => @interfaces.rpc_invalid_params("Missing parameters", request.id)
  }
}

///|
fn TelegramPlugin::handle_receive(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match self.receive() {
    Some(msg) => {
      let result : Map[String, Json] = {}
      result["message"] = telegram_message_to_json(msg)
      @interfaces.JsonRpcResponse::success(
        result=Json::object(result),
        id=request.id,
      )
    }
    None => @interfaces.rpc_null_result("message", request.id)
  }
}

///|
fn TelegramPlugin::handle_connect(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.connect()
  @interfaces.rpc_connect_response(request.id)
}

///|
fn TelegramPlugin::handle_disconnect(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.disconnect()
  @interfaces.rpc_disconnect_response(request.id)
}

///|
fn TelegramPlugin::handle_status(
  self : TelegramPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let extra : Map[String, Json] = {
    "pending_messages": Json::number(
      self.received_messages.length().to_double(),
    ),
    "api_base_url": Json::string(self.config.api_base_url),
  }
  @interfaces.rpc_status_response(self.is_connected, extra, request.id)
}
