///|
/// WhatsApp Business API Plugin
/// Provides WhatsApp messaging via Cloud API

///|
/// WhatsApp message types
pub(all) enum WhatsAppMessageType {
  /// Text message
  Text
  /// Image message
  Image
  /// Document message
  Document
  /// Audio message
  Audio
  /// Video message
  Video
  /// Location message
  Location
  /// Contact message
  Contact
  /// Interactive message (buttons, lists)
  Interactive
  /// Template message
  Template
  /// Reaction
  Reaction
}

///|
/// WhatsApp message
pub(all) struct WhatsAppMessage {
  /// Message ID
  id : String
  /// Sender phone number (with country code)
  from : String
  /// Recipient phone number
  to : String
  /// Message type
  message_type : WhatsAppMessageType
  /// Text content
  text : String
  /// Media URL (for image/document/audio/video)
  media_url : String?
  /// Media MIME type
  media_mime_type : String?
  /// Caption (for media messages)
  caption : String?
  /// Timestamp
  timestamp : Int64
  /// Message status (sent, delivered, read)
  status : String
}

///|
/// Interactive button
pub(all) struct WhatsAppButton {
  /// Button ID
  id : String
  /// Button title
  title : String
}

///|
/// List section item
pub(all) struct WhatsAppListItem {
  /// Item ID
  id : String
  /// Item title
  title : String
  /// Item description
  description : String
}

///|
/// Template message
pub(all) struct WhatsAppTemplate {
  /// Template name
  name : String
  /// Language code
  language : String
  /// Template components (header, body, buttons)
  components : Array[Json]
}

///|
/// WhatsApp plugin configuration
pub(all) struct WhatsAppPluginConfig {
  /// Plugin name
  name : String
  /// Phone number ID
  phone_number_id : String
  /// Business Account ID
  business_account_id : String
  /// API version
  api_version : String
  /// Webhook verify token
  verify_token : String
}

///|
/// Default config
pub fn WhatsAppPluginConfig::default(name~ : String) -> WhatsAppPluginConfig {
  {
    name,
    phone_number_id: "",
    business_account_id: "",
    api_version: "v18.0",
    verify_token: "",
  }
}

///|
/// WhatsApp plugin
pub struct WhatsAppPlugin {
  config : WhatsAppPluginConfig
  /// Received messages queue
  received_messages : Array[WhatsAppMessage]
  /// Message status updates
  status_updates : Map[String, String]
  mut is_connected : Bool
}

///|
/// Create new WhatsApp plugin
pub fn WhatsAppPlugin::new(config : WhatsAppPluginConfig) -> WhatsAppPlugin {
  { config, received_messages: [], status_updates: {}, is_connected: false }
}

///|
/// Create text message payload
pub fn WhatsAppPlugin::create_text_message(
  _self : WhatsAppPlugin,
  to : String,
  text : String,
) -> Json {
  {
    "messaging_product": "whatsapp",
    "recipient_type": "individual",
    "to": to,
    "type": "text",
    "text": { "preview_url": false, "body": text },
  }
}

///|
/// Create image message payload
pub fn WhatsAppPlugin::create_image_message(
  _self : WhatsAppPlugin,
  to : String,
  image_url : String,
  caption? : String = "",
) -> Json {
  let image : Map[String, Json] = { "link": image_url }
  if caption.length() > 0 {
    image["caption"] = Json::string(caption)
  }
  {
    "messaging_product": "whatsapp",
    "recipient_type": "individual",
    "to": to,
    "type": "image",
    "image": Json::object(image),
  }
}

///|
/// Create document message payload
pub fn WhatsAppPlugin::create_document_message(
  _self : WhatsAppPlugin,
  to : String,
  document_url : String,
  filename : String,
  caption? : String = "",
) -> Json {
  let doc : Map[String, Json] = { "link": document_url, "filename": filename }
  if caption.length() > 0 {
    doc["caption"] = Json::string(caption)
  }
  {
    "messaging_product": "whatsapp",
    "recipient_type": "individual",
    "to": to,
    "type": "document",
    "document": Json::object(doc),
  }
}

///|
/// Create location message payload
pub fn WhatsAppPlugin::create_location_message(
  _self : WhatsAppPlugin,
  to : String,
  latitude : Double,
  longitude : Double,
  name? : String = "",
  address? : String = "",
) -> Json {
  let loc : Map[String, Json] = {
    "latitude": Json::number(latitude),
    "longitude": Json::number(longitude),
  }
  if name.length() > 0 {
    loc["name"] = Json::string(name)
  }
  if address.length() > 0 {
    loc["address"] = Json::string(address)
  }
  {
    "messaging_product": "whatsapp",
    "recipient_type": "individual",
    "to": to,
    "type": "location",
    "location": Json::object(loc),
  }
}

///|
/// Create interactive buttons message
pub fn WhatsAppPlugin::create_buttons_message(
  _self : WhatsAppPlugin,
  to : String,
  body_text : String,
  buttons : Array[WhatsAppButton],
  header? : String = "",
  footer? : String = "",
) -> Json {
  let btns : Array[Json] = []
  for btn in buttons {
    btns.push({ "type": "reply", "reply": { "id": btn.id, "title": btn.title } })
  }
  let action : Map[String, Json] = { "buttons": Json::array(btns) }
  let interactive : Map[String, Json] = {
    "type": "button",
    "body": { "text": body_text },
    "action": Json::object(action),
  }
  if header.length() > 0 {
    interactive["header"] = { "type": "text", "text": header }
  }
  if footer.length() > 0 {
    interactive["footer"] = { "text": footer }
  }
  {
    "messaging_product": "whatsapp",
    "recipient_type": "individual",
    "to": to,
    "type": "interactive",
    "interactive": Json::object(interactive),
  }
}

///|
/// Create template message payload
pub fn WhatsAppPlugin::create_template_message(
  _self : WhatsAppPlugin,
  to : String,
  template : WhatsAppTemplate,
) -> Json {
  {
    "messaging_product": "whatsapp",
    "recipient_type": "individual",
    "to": to,
    "type": "template",
    "template": {
      "name": template.name,
      "language": { "code": template.language },
      "components": Json::array(template.components),
    },
  }
}

///|
/// Process incoming webhook
pub fn WhatsAppPlugin::handle_webhook(
  self : WhatsAppPlugin,
  payload : Json,
) -> Json {
  // Handle webhook verification
  match payload {
    { "hub.mode": String("subscribe"), "hub.challenge": String(challenge), .. } =>
      return { "challenge": challenge }
    _ => ()
  }
  // Process incoming messages
  match payload {
    { "entry": Array(entries), .. } =>
      for entry in entries {
        match entry {
          { "changes": Array(changes), .. } =>
            for change in changes {
              match change {
                { "value": value, .. } => self.process_value(value)
                _ => ()
              }
            }
          _ => ()
        }
      }
    _ => ()
  }
  { "status": "ok" }
}

///|
fn WhatsAppPlugin::process_value(self : WhatsAppPlugin, value : Json) -> Unit {
  // Process messages
  match value {
    { "messages": Array(messages), .. } =>
      for msg in messages {
        self.process_message(msg)
      }
    _ => ()
  }
  // Process status updates
  match value {
    { "statuses": Array(statuses), .. } =>
      for status in statuses {
        match status {
          { "id": String(msg_id), "status": String(stat), .. } =>
            self.status_updates[msg_id] = stat
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn WhatsAppPlugin::process_message(self : WhatsAppPlugin, msg : Json) -> Unit {
  let id = match msg {
    { "id": String(i), .. } => i
    _ => return
  }
  let from = match msg {
    { "from": String(f), .. } => f
    _ => return
  }
  let timestamp = match msg {
    { "timestamp": String(t), .. } => {
      let parsed = @strconv.parse_int64(t) catch { _ => 0L }
      parsed
    }
    _ => 0L
  }
  let (message_type, text, media_url, caption) = match msg {
    { "type": String("text"), "text": { "body": String(body), .. }, .. } =>
      (WhatsAppMessageType::Text, body, None, None)
    { "type": String("image"), "image": img, .. } => {
      let url = match img {
        { "url": String(u), .. } => Some(u)
        _ => None
      }
      let cap = match img {
        { "caption": String(c), .. } => Some(c)
        _ => None
      }
      (WhatsAppMessageType::Image, "", url, cap)
    }
    _ => (WhatsAppMessageType::Text, "", None, None)
  }
  let message : WhatsAppMessage = {
    id,
    from,
    to: self.config.phone_number_id,
    message_type,
    text,
    media_url,
    media_mime_type: None,
    caption,
    timestamp,
    status: "received",
  }
  self.received_messages.push(message)
}

///|
/// Pop received message
pub fn WhatsAppPlugin::receive(self : WhatsAppPlugin) -> WhatsAppMessage? {
  @util.pop_first(self.received_messages)
}

///|
/// Handle JSON-RPC request
pub fn WhatsAppPlugin::handle_request(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "send_text" => self.handle_send_text(request)
    "send_image" => self.handle_send_image(request)
    "send_document" => self.handle_send_document(request)
    "send_location" => self.handle_send_location(request)
    "send_buttons" => self.handle_send_buttons(request)
    "send_template" => self.handle_send_template(request)
    "webhook" => self.handle_webhook_rpc(request)
    "receive" => self.handle_receive(request)
    "status" => self.handle_status(request)
    "connect" => self.handle_connect(request)
    "disconnect" => self.handle_disconnect(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn WhatsAppPlugin::handle_send_text(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let to = match @interfaces.rpc_require_string(request, "to") {
    Ok(t) => t
    Err(response) => return response
  }
  let text = match @interfaces.rpc_require_string(request, "text") {
    Ok(t) => t
    Err(response) => return response
  }
  let payload = self.create_text_message(to, text)
  @interfaces.JsonRpcResponse::success(
    result={ "payload": payload, "status": "pending" },
    id=request.id,
  )
}

///|
fn WhatsAppPlugin::handle_send_image(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let to = match @interfaces.rpc_require_string(request, "to") {
    Ok(t) => t
    Err(response) => return response
  }
  let url = match @interfaces.rpc_require_string(request, "url") {
    Ok(u) => u
    Err(response) => return response
  }
  let caption = @interfaces.rpc_optional_string(request, "caption", "")
  let payload = self.create_image_message(to, url, caption~)
  @interfaces.JsonRpcResponse::success(
    result={ "payload": payload, "status": "pending" },
    id=request.id,
  )
}

///|
fn WhatsAppPlugin::handle_send_document(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let to = match @interfaces.rpc_require_string(request, "to") {
    Ok(t) => t
    Err(response) => return response
  }
  let url = match @interfaces.rpc_require_string(request, "url") {
    Ok(u) => u
    Err(response) => return response
  }
  let filename = match @interfaces.rpc_require_string(request, "filename") {
    Ok(f) => f
    Err(response) => return response
  }
  let caption = @interfaces.rpc_optional_string(request, "caption", "")
  let payload = self.create_document_message(to, url, filename, caption~)
  @interfaces.JsonRpcResponse::success(
    result={ "payload": payload, "status": "pending" },
    id=request.id,
  )
}

///|
fn WhatsAppPlugin::handle_send_location(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let to = match @interfaces.rpc_require_string(request, "to") {
    Ok(t) => t
    Err(response) => return response
  }
  let lat = match @interfaces.rpc_require_double(request, "latitude") {
    Ok(l) => l
    Err(response) => return response
  }
  let lng = match @interfaces.rpc_require_double(request, "longitude") {
    Ok(l) => l
    Err(response) => return response
  }
  let name = @interfaces.rpc_optional_string(request, "name", "")
  let address = @interfaces.rpc_optional_string(request, "address", "")
  let payload = self.create_location_message(to, lat, lng, name~, address~)
  @interfaces.JsonRpcResponse::success(
    result={ "payload": payload, "status": "pending" },
    id=request.id,
  )
}

///|
fn WhatsAppPlugin::handle_send_buttons(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let to = match @interfaces.rpc_require_string(request, "to") {
    Ok(t) => t
    Err(response) => return response
  }
  let body_text = match @interfaces.rpc_require_string(request, "body") {
    Ok(b) => b
    Err(response) => return response
  }
  let buttons = match request.params {
    Some({ "buttons": Array(btns), .. }) => {
      let parsed_btns : Array[WhatsAppButton] = []
      for btn in btns {
        match btn {
          { "id": String(bid), "title": String(title), .. } =>
            parsed_btns.push({ id: bid, title })
          _ => ()
        }
      }
      parsed_btns
    }
    _ =>
      return @interfaces.rpc_invalid_params(
        "Missing 'buttons' parameter",
        request.id,
      )
  }
  let header = @interfaces.rpc_optional_string(request, "header", "")
  let footer = @interfaces.rpc_optional_string(request, "footer", "")
  let payload = self.create_buttons_message(
    to,
    body_text,
    buttons,
    header~,
    footer~,
  )
  @interfaces.JsonRpcResponse::success(
    result={ "payload": payload, "status": "pending" },
    id=request.id,
  )
}

///|
fn WhatsAppPlugin::handle_send_template(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let to = match @interfaces.rpc_require_string(request, "to") {
    Ok(t) => t
    Err(response) => return response
  }
  let template_name = match
    @interfaces.rpc_require_string(request, "template_name") {
    Ok(n) => n
    Err(response) => return response
  }
  let language = match @interfaces.rpc_require_string(request, "language") {
    Ok(l) => l
    Err(response) => return response
  }
  let components = match request.params {
    Some({ "components": Array(c), .. }) => c
    _ => []
  }
  let template : WhatsAppTemplate = {
    name: template_name,
    language,
    components,
  }
  let payload = self.create_template_message(to, template)
  @interfaces.JsonRpcResponse::success(
    result={ "payload": payload, "status": "pending" },
    id=request.id,
  )
}

///|
fn WhatsAppPlugin::handle_webhook_rpc(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let payload = match request.params {
    Some({ "payload": p, .. }) => p
    Some(p) => p
    None =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing payload",
        id=request.id,
      )
  }
  let result = self.handle_webhook(payload)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn WhatsAppPlugin::handle_receive(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match self.receive() {
    Some(msg) =>
      @interfaces.JsonRpcResponse::success(
        result={
          "id": msg.id,
          "from": msg.from,
          "to": msg.to,
          "text": msg.text,
          "timestamp": Json::number(msg.timestamp.to_double()),
          "status": msg.status,
        },
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::success(
        result={ "message": Json::null() },
        id=request.id,
      )
  }
}

///|
fn WhatsAppPlugin::handle_status(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let extra : Map[String, Json] = {
    "phone_number_id": self.config.phone_number_id,
    "pending_messages": Json::number(
      self.received_messages.length().to_double(),
    ),
  }
  @interfaces.rpc_status_response(self.is_connected, extra, request.id)
}

///|
fn WhatsAppPlugin::handle_connect(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  @interfaces.handle_connect_common(self, request)
}

///|
fn WhatsAppPlugin::handle_disconnect(
  self : WhatsAppPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  @interfaces.handle_disconnect_common(self, request)
}

///|
/// ConnectablePlugin trait implementation
pub impl @interfaces.ConnectablePlugin for WhatsAppPlugin with is_connected(
  self,
) {
  self.is_connected
}

///|
pub impl @interfaces.ConnectablePlugin for WhatsAppPlugin with set_connected(
  self,
  connected,
) {
  self.is_connected = connected
}
