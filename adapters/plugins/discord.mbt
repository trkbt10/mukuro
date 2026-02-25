///|
/// Discord Bot API Plugin
/// Provides Discord messaging via Bot API

///|
/// Discord message types
pub(all) enum DiscordMessageType {
  /// Default text message
  Default
  /// Reply message
  Reply
  /// Slash command
  ChatInputCommand
  /// Thread starter
  ThreadStart
  /// User join message
  UserJoin
}

///|
/// Discord embed field
pub(all) struct DiscordEmbedField {
  /// Field name
  name : String
  /// Field value
  value : String
  /// Inline display
  inline : Bool
}

///|
/// Discord embed
pub(all) struct DiscordEmbed {
  /// Embed title
  title : String?
  /// Embed description
  description : String?
  /// Embed URL
  url : String?
  /// Embed color (as integer)
  color : Int?
  /// Embed fields
  fields : Array[DiscordEmbedField]?
  /// Footer text
  footer_text : String?
  /// Thumbnail URL
  thumbnail_url : String?
  /// Image URL
  image_url : String?
}

///|
/// Discord attachment
pub(all) struct DiscordAttachment {
  /// Attachment ID (Snowflake)
  id : String
  /// File name
  filename : String
  /// File size in bytes
  size : Int
  /// Attachment URL
  url : String
  /// Proxy URL
  proxy_url : String
  /// Content type
  content_type : String?
}

///|
/// Discord message
pub(all) struct DiscordMessage {
  /// Message ID (Snowflake)
  id : String
  /// Channel ID
  channel_id : String
  /// Guild ID (None for DMs)
  guild_id : String?
  /// Author user ID
  author_id : String
  /// Author username
  author_name : String
  /// Author discriminator
  author_discriminator : String
  /// Author avatar hash
  author_avatar : String?
  /// Is author a bot
  author_is_bot : Bool
  /// Message content
  content : String
  /// Message type
  message_type : DiscordMessageType
  /// Embeds
  embeds : Array[DiscordEmbed]?
  /// Attachments
  attachments : Array[DiscordAttachment]?
  /// Referenced message ID (for replies)
  referenced_message_id : String?
  /// Timestamp (ISO 8601)
  timestamp : String
}

///|
/// Discord component types
pub(all) enum DiscordComponentType {
  /// Action row (container)
  ActionRow
  /// Button
  Button
  /// Select menu
  SelectMenu
}

///|
/// Discord button style
pub(all) enum DiscordButtonStyle {
  /// Primary (blurple)
  Primary
  /// Secondary (grey)
  Secondary
  /// Success (green)
  Success
  /// Danger (red)
  Danger
  /// Link (grey with link icon)
  Link
}

///|
/// Discord button
pub(all) struct DiscordButton {
  /// Button style
  style : DiscordButtonStyle
  /// Button label
  label : String
  /// Custom ID (for non-link buttons)
  custom_id : String?
  /// URL (for link buttons)
  url : String?
  /// Disabled state
  disabled : Bool
  /// Emoji name
  emoji : String?
}

///|
/// Discord plugin configuration
pub(all) struct DiscordPluginConfig {
  /// Plugin name
  name : String
  /// Bot token
  bot_token : String
  /// Application ID
  application_id : String
  /// API base URL
  api_base_url : String
  /// Gateway URL
  gateway_url : String
}

///|
/// Default Discord plugin config
pub fn DiscordPluginConfig::default(
  name~ : String,
  bot_token~ : String,
  application_id~ : String,
) -> DiscordPluginConfig {
  {
    name,
    bot_token,
    application_id,
    api_base_url: "https://discord.com/api/v10",
    gateway_url: "wss://gateway.discord.gg",
  }
}

///|
/// Discord plugin
pub struct DiscordPlugin {
  config : DiscordPluginConfig
  /// Received messages buffer
  received_messages : Array[DiscordMessage]
  /// Connection state
  mut is_connected : Bool
  /// Current timestamp provider
  mut get_timestamp : () -> Int64
}

///|
/// Create new Discord plugin
pub fn DiscordPlugin::new(config : DiscordPluginConfig) -> DiscordPlugin {
  {
    config,
    received_messages: [],
    is_connected: false,
    get_timestamp: fn() { 0L },
  }
}

///|
/// Set timestamp provider (for testing)
pub fn DiscordPlugin::set_timestamp_provider(
  self : DiscordPlugin,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Connect to Discord
pub fn DiscordPlugin::connect(self : DiscordPlugin) -> Unit {
  self.is_connected = true
}

///|
/// Disconnect from Discord
pub fn DiscordPlugin::disconnect(self : DiscordPlugin) -> Unit {
  self.is_connected = false
}

///|
/// Check if connected
pub fn DiscordPlugin::is_connected(self : DiscordPlugin) -> Bool {
  self.is_connected
}

///|
/// Get API endpoint URL
fn DiscordPlugin::api_endpoint(self : DiscordPlugin, path : String) -> String {
  "\{self.config.api_base_url}\{path}"
}

///|
/// Send a message
pub fn DiscordPlugin::send_message(
  self : DiscordPlugin,
  channel_id : String,
  content : String,
  reply_to? : String? = None,
  tts? : Bool = false,
) -> Json {
  let params : Map[String, Json] = { "content": Json::string(content) }
  if tts {
    params["tts"] = Json::boolean(true)
  }
  match reply_to {
    Some(msg_id) =>
      params["message_reference"] = Json::object({
        "message_id": Json::string(msg_id),
      })
    None => ()
  }
  Json::object({
    "endpoint": "sendMessage",
    "url": Json::string(self.api_endpoint("/channels/\{channel_id}/messages")),
    "method": "POST",
    "params": Json::object(params),
  })
}

///|
/// Send a message with embeds
pub fn DiscordPlugin::send_embed(
  self : DiscordPlugin,
  channel_id : String,
  embeds : Array[DiscordEmbed],
  content? : String? = None,
) -> Json {
  let params : Map[String, Json] = {}
  match content {
    Some(c) => params["content"] = Json::string(c)
    None => ()
  }
  // Convert embeds to JSON
  let embed_arr : Array[Json] = []
  for embed in embeds {
    embed_arr.push(embed_to_json(embed))
  }
  params["embeds"] = Json::array(embed_arr)
  Json::object({
    "endpoint": "sendMessage",
    "url": Json::string(self.api_endpoint("/channels/\{channel_id}/messages")),
    "method": "POST",
    "params": Json::object(params),
  })
}

///|
/// Convert embed to JSON
fn embed_to_json(embed : DiscordEmbed) -> Json {
  let obj : Map[String, Json] = {}
  match embed.title {
    Some(t) => obj["title"] = Json::string(t)
    None => ()
  }
  match embed.description {
    Some(d) => obj["description"] = Json::string(d)
    None => ()
  }
  match embed.url {
    Some(u) => obj["url"] = Json::string(u)
    None => ()
  }
  match embed.color {
    Some(c) => obj["color"] = Json::number(c.to_double())
    None => ()
  }
  match embed.fields {
    Some(fields) => {
      let field_arr : Array[Json] = []
      for field in fields {
        field_arr.push(
          Json::object({
            "name": Json::string(field.name),
            "value": Json::string(field.value),
            "inline": Json::boolean(field.inline),
          }),
        )
      }
      obj["fields"] = Json::array(field_arr)
    }
    None => ()
  }
  match embed.footer_text {
    Some(f) => obj["footer"] = Json::object({ "text": Json::string(f) })
    None => ()
  }
  match embed.thumbnail_url {
    Some(t) => obj["thumbnail"] = Json::object({ "url": Json::string(t) })
    None => ()
  }
  match embed.image_url {
    Some(i) => obj["image"] = Json::object({ "url": Json::string(i) })
    None => ()
  }
  Json::object(obj)
}

///|
/// Edit a message
pub fn DiscordPlugin::edit_message(
  self : DiscordPlugin,
  channel_id : String,
  message_id : String,
  content : String,
) -> Json {
  Json::object({
    "endpoint": "editMessage",
    "url": Json::string(
      self.api_endpoint("/channels/\{channel_id}/messages/\{message_id}"),
    ),
    "method": "PATCH",
    "params": { "content": Json::string(content) },
  })
}

///|
/// Delete a message
pub fn DiscordPlugin::delete_message(
  self : DiscordPlugin,
  channel_id : String,
  message_id : String,
) -> Json {
  Json::object({
    "endpoint": "deleteMessage",
    "url": Json::string(
      self.api_endpoint("/channels/\{channel_id}/messages/\{message_id}"),
    ),
    "method": "DELETE",
    "params": {},
  })
}

///|
/// Add a reaction
pub fn DiscordPlugin::add_reaction(
  self : DiscordPlugin,
  channel_id : String,
  message_id : String,
  emoji : String,
) -> Json {
  Json::object({
    "endpoint": "addReaction",
    "url": Json::string(
      self.api_endpoint(
        "/channels/\{channel_id}/messages/\{message_id}/reactions/\{emoji}/@me",
      ),
    ),
    "method": "PUT",
    "params": {},
  })
}

///|
/// Send message with buttons
pub fn DiscordPlugin::send_with_buttons(
  self : DiscordPlugin,
  channel_id : String,
  content : String,
  buttons : Array[DiscordButton],
) -> Json {
  let components : Array[Json] = []
  let button_arr : Array[Json] = []
  for button in buttons {
    let btn : Map[String, Json] = {
      "type": Json::number(2.0), // Button type
      "label": Json::string(button.label),
      "style": Json::number(button_style_to_int(button.style).to_double()),
      "disabled": Json::boolean(button.disabled),
    }
    match button.custom_id {
      Some(id) => btn["custom_id"] = Json::string(id)
      None => ()
    }
    match button.url {
      Some(url) => btn["url"] = Json::string(url)
      None => ()
    }
    match button.emoji {
      Some(em) => btn["emoji"] = Json::object({ "name": Json::string(em) })
      None => ()
    }
    button_arr.push(Json::object(btn))
  }
  components.push(
    Json::object({
      "type": Json::number(1.0), // Action row type
      "components": Json::array(button_arr),
    }),
  )
  Json::object({
    "endpoint": "sendMessage",
    "url": Json::string(self.api_endpoint("/channels/\{channel_id}/messages")),
    "method": "POST",
    "params": {
      "content": Json::string(content),
      "components": Json::array(components),
    },
  })
}

///|
/// Convert button style to int
fn button_style_to_int(style : DiscordButtonStyle) -> Int {
  match style {
    Primary => 1
    Secondary => 2
    Success => 3
    Danger => 4
    Link => 5
  }
}

///|
/// Process gateway event
pub fn DiscordPlugin::process_gateway_event(
  self : DiscordPlugin,
  event : Json,
) -> DiscordMessage? {
  match event {
    Object(obj) =>
      match obj.get("t") {
        Some(String("MESSAGE_CREATE")) =>
          match obj.get("d") {
            Some(Object(data)) => self.parse_message(data)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
/// Parse message from JSON
fn DiscordPlugin::parse_message(
  self : DiscordPlugin,
  data : Map[String, Json],
) -> DiscordMessage? {
  // Extract ID
  let id = match data.get("id") {
    Some(String(i)) => i
    _ => return None
  }
  // Extract channel_id
  let channel_id = match data.get("channel_id") {
    Some(String(c)) => c
    _ => return None
  }
  // Extract guild_id
  let guild_id : String? = match data.get("guild_id") {
    Some(String(g)) => Some(g)
    _ => None
  }
  // Extract author
  let (
    author_id,
    author_name,
    author_discriminator,
    author_avatar,
    author_is_bot,
  ) = match data.get("author") {
    Some(Object(author)) => {
      let id = match author.get("id") {
        Some(String(i)) => i
        _ => return None
      }
      let username = match author.get("username") {
        Some(String(u)) => u
        _ => "Unknown"
      }
      let discriminator = match author.get("discriminator") {
        Some(String(d)) => d
        _ => "0000"
      }
      let avatar : String? = match author.get("avatar") {
        Some(String(a)) => Some(a)
        _ => None
      }
      let is_bot = match author.get("bot") {
        Some(True) => true
        _ => false
      }
      (id, username, discriminator, avatar, is_bot)
    }
    _ => return None
  }
  // Extract content
  let content = match data.get("content") {
    Some(String(c)) => c
    _ => ""
  }
  // Extract timestamp
  let timestamp = match data.get("timestamp") {
    Some(String(t)) => t
    _ => ""
  }
  // Extract message type
  let message_type = match data.get("type") {
    Some(Number(0.0, ..)) => DiscordMessageType::Default
    Some(Number(19.0, ..)) => DiscordMessageType::Reply
    Some(Number(20.0, ..)) => DiscordMessageType::ChatInputCommand
    Some(Number(21.0, ..)) => DiscordMessageType::ThreadStart
    Some(Number(7.0, ..)) => DiscordMessageType::UserJoin
    _ => DiscordMessageType::Default
  }
  // Extract referenced message
  let referenced_message_id : String? = match data.get("referenced_message") {
    Some(Object(ref_msg)) =>
      match ref_msg.get("id") {
        Some(String(i)) => Some(i)
        _ => None
      }
    _ => None
  }
  // Parse embeds (simplified)
  let embeds : Array[DiscordEmbed]? = None
  // Parse attachments (simplified)
  let attachments : Array[DiscordAttachment]? = None
  ignore(self)
  Some({
    id,
    channel_id,
    guild_id,
    author_id,
    author_name,
    author_discriminator,
    author_avatar,
    author_is_bot,
    content,
    message_type,
    embeds,
    attachments,
    referenced_message_id,
    timestamp,
  })
}

///|
/// Receive message from buffer
pub fn DiscordPlugin::receive(self : DiscordPlugin) -> DiscordMessage? {
  @util.pop_first(self.received_messages)
}

///|
/// Add message to buffer
pub fn DiscordPlugin::add_received_message(
  self : DiscordPlugin,
  message : DiscordMessage,
) -> Unit {
  self.received_messages.push(message)
}

///|
/// Convert DiscordMessage to JSON
fn discord_message_to_json(msg : DiscordMessage) -> Json {
  let result : Map[String, Json] = {
    "id": Json::string(msg.id),
    "channel_id": Json::string(msg.channel_id),
    "author_id": Json::string(msg.author_id),
    "author_name": Json::string(msg.author_name),
    "author_discriminator": Json::string(msg.author_discriminator),
    "author_is_bot": Json::boolean(msg.author_is_bot),
    "content": Json::string(msg.content),
    "timestamp": Json::string(msg.timestamp),
  }
  match msg.guild_id {
    Some(g) => result["guild_id"] = Json::string(g)
    None => ()
  }
  match msg.author_avatar {
    Some(a) => result["author_avatar"] = Json::string(a)
    None => ()
  }
  match msg.referenced_message_id {
    Some(r) => result["referenced_message_id"] = Json::string(r)
    None => ()
  }
  let type_str = match msg.message_type {
    Default => "default"
    Reply => "reply"
    ChatInputCommand => "chat_input_command"
    ThreadStart => "thread_start"
    UserJoin => "user_join"
  }
  result["message_type"] = Json::string(type_str)
  Json::object(result)
}

///|
/// Handle JSON-RPC request
pub fn DiscordPlugin::handle_request(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "send_message" => self.handle_send_message(request)
    "send_embed" => self.handle_send_embed(request)
    "edit_message" => self.handle_edit_message(request)
    "delete_message" => self.handle_delete_message(request)
    "add_reaction" => self.handle_add_reaction(request)
    "send_with_buttons" => self.handle_send_with_buttons(request)
    "gateway_event" => self.handle_gateway_event(request)
    "receive" => self.handle_receive(request)
    "connect" => self.handle_connect(request)
    "disconnect" => self.handle_disconnect(request)
    "status" => self.handle_status(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn DiscordPlugin::handle_send_message(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel_id = match @interfaces.rpc_require_string(request, "channel_id") {
    Ok(c) => c
    Err(response) => return response
  }
  let content = match @interfaces.rpc_require_string(request, "content") {
    Ok(c) => c
    Err(response) => return response
  }
  let reply_to = @interfaces.rpc_string_or_none(request, "reply_to")
  let tts = @interfaces.rpc_optional_bool(request, "tts", false)
  let result = self.send_message(channel_id, content, reply_to~, tts~)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn DiscordPlugin::handle_send_embed(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel_id = match @interfaces.rpc_require_string(request, "channel_id") {
    Ok(c) => c
    Err(response) => return response
  }
  let content = @interfaces.rpc_string_or_none(request, "content")
  // Parse embeds from params (simplified - just create one embed)
  let title = @interfaces.rpc_string_or_none(request, "title")
  let description = @interfaces.rpc_string_or_none(request, "description")
  let color = @interfaces.rpc_int_or_none(request, "color")
  let embed : DiscordEmbed = {
    title,
    description,
    url: None,
    color,
    fields: None,
    footer_text: None,
    thumbnail_url: None,
    image_url: None,
  }
  let result = self.send_embed(channel_id, [embed], content~)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn DiscordPlugin::handle_edit_message(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel_id = match @interfaces.rpc_require_string(request, "channel_id") {
    Ok(c) => c
    Err(response) => return response
  }
  let message_id = match @interfaces.rpc_require_string(request, "message_id") {
    Ok(m) => m
    Err(response) => return response
  }
  let content = match @interfaces.rpc_require_string(request, "content") {
    Ok(c) => c
    Err(response) => return response
  }
  let result = self.edit_message(channel_id, message_id, content)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn DiscordPlugin::handle_delete_message(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel_id = match @interfaces.rpc_require_string(request, "channel_id") {
    Ok(c) => c
    Err(response) => return response
  }
  let message_id = match @interfaces.rpc_require_string(request, "message_id") {
    Ok(m) => m
    Err(response) => return response
  }
  let result = self.delete_message(channel_id, message_id)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn DiscordPlugin::handle_add_reaction(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel_id = match @interfaces.rpc_require_string(request, "channel_id") {
    Ok(c) => c
    Err(response) => return response
  }
  let message_id = match @interfaces.rpc_require_string(request, "message_id") {
    Ok(m) => m
    Err(response) => return response
  }
  let emoji = match @interfaces.rpc_require_string(request, "emoji") {
    Ok(e) => e
    Err(response) => return response
  }
  let result = self.add_reaction(channel_id, message_id, emoji)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn DiscordPlugin::handle_send_with_buttons(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel_id = match @interfaces.rpc_require_string(request, "channel_id") {
    Ok(c) => c
    Err(response) => return response
  }
  let content = match @interfaces.rpc_require_string(request, "content") {
    Ok(c) => c
    Err(response) => return response
  }
  // Parse buttons from params
  let buttons : Array[DiscordButton] = []
  match @interfaces.rpc_get_params(request) {
    Some(params) =>
      match params.get("buttons") {
        Some(Array(btn_arr)) =>
          for btn_json in btn_arr {
            match btn_json {
              Object(btn) => {
                let label = match btn.get("label") {
                  Some(String(l)) => l
                  _ => continue
                }
                let style = match btn.get("style") {
                  Some(String("primary")) => DiscordButtonStyle::Primary
                  Some(String("secondary")) => DiscordButtonStyle::Secondary
                  Some(String("success")) => DiscordButtonStyle::Success
                  Some(String("danger")) => DiscordButtonStyle::Danger
                  Some(String("link")) => DiscordButtonStyle::Link
                  _ => DiscordButtonStyle::Primary
                }
                let custom_id : String? = match btn.get("custom_id") {
                  Some(String(c)) => Some(c)
                  _ => None
                }
                let url : String? = match btn.get("url") {
                  Some(String(u)) => Some(u)
                  _ => None
                }
                let disabled = match btn.get("disabled") {
                  Some(True) => true
                  _ => false
                }
                buttons.push({
                  style,
                  label,
                  custom_id,
                  url,
                  disabled,
                  emoji: None,
                })
              }
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
  let result = self.send_with_buttons(channel_id, content, buttons)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn DiscordPlugin::handle_gateway_event(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match @interfaces.rpc_get_params(request) {
    Some(params) =>
      match params.get("event") {
        Some(event) =>
          match self.process_gateway_event(event) {
            Some(msg) => {
              self.received_messages.push(msg)
              @interfaces.rpc_ok(request.id)
            }
            None =>
              @interfaces.rpc_invalid_params("Invalid event format", request.id)
          }
        None =>
          @interfaces.rpc_invalid_params(
            "Missing 'event' parameter",
            request.id,
          )
      }
    None => @interfaces.rpc_invalid_params("Missing parameters", request.id)
  }
}

///|
fn DiscordPlugin::handle_receive(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match self.receive() {
    Some(msg) => {
      let result : Map[String, Json] = {}
      result["message"] = discord_message_to_json(msg)
      @interfaces.JsonRpcResponse::success(
        result=Json::object(result),
        id=request.id,
      )
    }
    None => @interfaces.rpc_null_result("message", request.id)
  }
}

///|
fn DiscordPlugin::handle_connect(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.connect()
  @interfaces.rpc_connect_response(request.id)
}

///|
fn DiscordPlugin::handle_disconnect(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.disconnect()
  @interfaces.rpc_disconnect_response(request.id)
}

///|
fn DiscordPlugin::handle_status(
  self : DiscordPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let extra : Map[String, Json] = {
    "pending_messages": Json::number(
      self.received_messages.length().to_double(),
    ),
    "api_base_url": Json::string(self.config.api_base_url),
    "application_id": Json::string(self.config.application_id),
  }
  @interfaces.rpc_status_response(self.is_connected, extra, request.id)
}
