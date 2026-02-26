///|
/// Slack Web API Plugin
/// Provides Slack messaging via Web API and Events API

///|
/// Slack text object
pub(all) struct SlackTextObject {
  /// Text type ("plain_text" or "mrkdwn")
  text_type : String
  /// Text content
  text : String
  /// Emoji support (for plain_text)
  emoji : Bool
}

///|
/// Slack element (button, select, etc.)
pub(all) struct SlackElement {
  /// Element type
  element_type : String
  /// Action ID
  action_id : String?
  /// Text (for buttons)
  text : SlackTextObject?
  /// URL (for link buttons)
  url : String?
  /// Value
  value : String?
  /// Style ("primary" or "danger")
  style : String?
}

///|
/// Slack block
pub(all) struct SlackBlock {
  /// Block type ("section", "divider", "actions", "context", "header")
  block_type : String
  /// Block ID
  block_id : String?
  /// Text object
  text : SlackTextObject?
  /// Accessory element
  accessory : SlackElement?
  /// Elements (for actions/context blocks)
  elements : Array[SlackElement]?
}

///|
/// Slack message
pub(all) struct SlackMessage {
  /// Client message ID
  client_msg_id : String?
  /// Message text
  text : String
  /// User ID
  user_id : String
  /// User name
  user_name : String
  /// Channel ID
  channel_id : String
  /// Message timestamp (Slack ts)
  ts : String
  /// Thread timestamp (for threaded messages)
  thread_ts : String?
  /// Block Kit blocks
  blocks : Array[SlackBlock]?
  /// Bot ID (if from bot)
  bot_id : String?
  /// Message subtype
  subtype : String?
}

///|
/// Slack plugin configuration
pub(all) struct SlackPluginConfig {
  /// Plugin name
  name : String
  /// Bot OAuth token
  bot_token : String
  /// App-level token (for Socket Mode)
  app_token : String?
  /// Signing secret (for webhook verification)
  signing_secret : String
  /// API base URL
  api_base_url : String
}

///|
/// Default Slack plugin config
pub fn SlackPluginConfig::default(
  name~ : String,
  bot_token~ : String,
  signing_secret~ : String,
) -> SlackPluginConfig {
  {
    name,
    bot_token,
    app_token: None,
    signing_secret,
    api_base_url: "https://slack.com/api",
  }
}

///|
/// Slack plugin
pub struct SlackPlugin {
  config : SlackPluginConfig
  /// Received messages buffer
  received_messages : Array[SlackMessage]
  /// Connection state
  mut is_connected : Bool
  /// Current timestamp provider
  mut get_timestamp : () -> Int64
}

///|
/// Create new Slack plugin
pub fn SlackPlugin::new(config : SlackPluginConfig) -> SlackPlugin {
  {
    config,
    received_messages: [],
    is_connected: false,
    get_timestamp: fn() { 0L },
  }
}

///|
/// Set timestamp provider (for testing)
pub fn SlackPlugin::set_timestamp_provider(
  self : SlackPlugin,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Connect to Slack
pub fn SlackPlugin::connect(self : SlackPlugin) -> Unit {
  self.is_connected = true
}

///|
/// Disconnect from Slack
pub fn SlackPlugin::disconnect(self : SlackPlugin) -> Unit {
  self.is_connected = false
}

///|
/// Check if connected
pub fn SlackPlugin::is_connected(self : SlackPlugin) -> Bool {
  self.is_connected
}

///|
/// Set connection state (for ConnectablePlugin trait)
pub fn SlackPlugin::set_connected(self : SlackPlugin, value : Bool) -> Unit {
  self.is_connected = value
}

///|
/// ConnectablePlugin trait implementation
pub impl @interfaces.ConnectablePlugin for SlackPlugin with is_connected(self) -> Bool {
  self.is_connected
}

///|
pub impl @interfaces.ConnectablePlugin for SlackPlugin with set_connected(
  self,
  value,
) -> Unit {
  self.is_connected = value
}

///|
/// Get API endpoint URL
fn SlackPlugin::api_endpoint(self : SlackPlugin, api_method : String) -> String {
  "\{self.config.api_base_url}/\{api_method}"
}

///|
/// Send a text message
pub fn SlackPlugin::send_message(
  self : SlackPlugin,
  channel : String,
  text : String,
  thread_ts? : String? = None,
  mrkdwn? : Bool = true,
) -> Json {
  let params : Map[String, Json] = {
    "channel": Json::string(channel),
    "text": Json::string(text),
    "mrkdwn": Json::boolean(mrkdwn),
  }
  match thread_ts {
    Some(ts) => params["thread_ts"] = Json::string(ts)
    None => ()
  }
  Json::object({
    "api_method": "chat.postMessage",
    "url": Json::string(self.api_endpoint("chat.postMessage")),
    "params": Json::object(params),
  })
}

///|
/// Send a message with blocks
pub fn SlackPlugin::send_blocks(
  self : SlackPlugin,
  channel : String,
  blocks : Array[SlackBlock],
  text? : String? = None,
  thread_ts? : String? = None,
) -> Json {
  let params : Map[String, Json] = { "channel": Json::string(channel) }
  match text {
    Some(t) => params["text"] = Json::string(t)
    None => ()
  }
  match thread_ts {
    Some(ts) => params["thread_ts"] = Json::string(ts)
    None => ()
  }
  // Convert blocks to JSON
  let block_arr : Array[Json] = []
  for block in blocks {
    block_arr.push(block_to_json(block))
  }
  params["blocks"] = Json::array(block_arr)
  Json::object({
    "api_method": "chat.postMessage",
    "url": Json::string(self.api_endpoint("chat.postMessage")),
    "params": Json::object(params),
  })
}

///|
/// Convert SlackBlock to JSON
fn block_to_json(block : SlackBlock) -> Json {
  let obj : Map[String, Json] = { "type": Json::string(block.block_type) }
  match block.block_id {
    Some(id) => obj["block_id"] = Json::string(id)
    None => ()
  }
  match block.text {
    Some(text) => obj["text"] = text_object_to_json(text)
    None => ()
  }
  match block.accessory {
    Some(acc) => obj["accessory"] = element_to_json(acc)
    None => ()
  }
  match block.elements {
    Some(elements) => {
      let elem_arr : Array[Json] = []
      for elem in elements {
        elem_arr.push(element_to_json(elem))
      }
      obj["elements"] = Json::array(elem_arr)
    }
    None => ()
  }
  Json::object(obj)
}

///|
/// Convert SlackTextObject to JSON
fn text_object_to_json(text : SlackTextObject) -> Json {
  let obj : Map[String, Json] = {
    "type": Json::string(text.text_type),
    "text": Json::string(text.text),
  }
  if text.text_type == "plain_text" {
    obj["emoji"] = Json::boolean(text.emoji)
  }
  Json::object(obj)
}

///|
/// Convert SlackElement to JSON
fn element_to_json(elem : SlackElement) -> Json {
  let obj : Map[String, Json] = { "type": Json::string(elem.element_type) }
  match elem.action_id {
    Some(id) => obj["action_id"] = Json::string(id)
    None => ()
  }
  match elem.text {
    Some(text) => obj["text"] = text_object_to_json(text)
    None => ()
  }
  match elem.url {
    Some(url) => obj["url"] = Json::string(url)
    None => ()
  }
  match elem.value {
    Some(v) => obj["value"] = Json::string(v)
    None => ()
  }
  match elem.style {
    Some(s) => obj["style"] = Json::string(s)
    None => ()
  }
  Json::object(obj)
}

///|
/// Update a message
pub fn SlackPlugin::update_message(
  self : SlackPlugin,
  channel : String,
  ts : String,
  text : String,
) -> Json {
  Json::object({
    "api_method": "chat.update",
    "url": Json::string(self.api_endpoint("chat.update")),
    "params": {
      "channel": Json::string(channel),
      "ts": Json::string(ts),
      "text": Json::string(text),
    },
  })
}

///|
/// Delete a message
pub fn SlackPlugin::delete_message(
  self : SlackPlugin,
  channel : String,
  ts : String,
) -> Json {
  Json::object({
    "api_method": "chat.delete",
    "url": Json::string(self.api_endpoint("chat.delete")),
    "params": { "channel": Json::string(channel), "ts": Json::string(ts) },
  })
}

///|
/// Add a reaction
pub fn SlackPlugin::add_reaction(
  self : SlackPlugin,
  channel : String,
  timestamp : String,
  emoji_name : String,
) -> Json {
  Json::object({
    "api_method": "reactions.add",
    "url": Json::string(self.api_endpoint("reactions.add")),
    "params": {
      "channel": Json::string(channel),
      "timestamp": Json::string(timestamp),
      "name": Json::string(emoji_name),
    },
  })
}

///|
/// Upload a file
pub fn SlackPlugin::upload_file(
  self : SlackPlugin,
  channels : Array[String],
  content : String,
  filename? : String = "file.txt",
  title? : String? = None,
  initial_comment? : String? = None,
) -> Json {
  let params : Map[String, Json] = {
    "content": Json::string(content),
    "filename": Json::string(filename),
  }
  // Convert channels to comma-separated string
  let channel_str = channels
    .iter()
    .fold(init="", fn(acc, ch) { if acc == "" { ch } else { "\{acc},\{ch}" } })
  params["channels"] = Json::string(channel_str)
  match title {
    Some(t) => params["title"] = Json::string(t)
    None => ()
  }
  match initial_comment {
    Some(c) => params["initial_comment"] = Json::string(c)
    None => ()
  }
  Json::object({
    "api_method": "files.upload",
    "url": Json::string(self.api_endpoint("files.upload")),
    "params": Json::object(params),
  })
}

///|
/// Process Events API event
pub fn SlackPlugin::process_event(
  self : SlackPlugin,
  event : Json,
) -> SlackMessage? {
  match event {
    Object(obj) =>
      match obj.get("event") {
        Some(Object(ev)) =>
          match ev.get("type") {
            Some(String("message")) => self.parse_message(ev)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
/// Parse message from JSON
fn SlackPlugin::parse_message(
  self : SlackPlugin,
  ev : Map[String, Json],
) -> SlackMessage? {
  // Extract user
  let user_id = match ev.get("user") {
    Some(String(u)) => u
    _ => ""
  }
  // Extract channel
  let channel_id = match ev.get("channel") {
    Some(String(c)) => c
    _ => return None
  }
  // Extract text
  let text = match ev.get("text") {
    Some(String(t)) => t
    _ => ""
  }
  // Extract ts
  let ts = match ev.get("ts") {
    Some(String(t)) => t
    _ => return None
  }
  // Extract thread_ts
  let thread_ts : String? = match ev.get("thread_ts") {
    Some(String(t)) => Some(t)
    _ => None
  }
  // Extract client_msg_id
  let client_msg_id : String? = match ev.get("client_msg_id") {
    Some(String(c)) => Some(c)
    _ => None
  }
  // Extract bot_id
  let bot_id : String? = match ev.get("bot_id") {
    Some(String(b)) => Some(b)
    _ => None
  }
  // Extract subtype
  let subtype : String? = match ev.get("subtype") {
    Some(String(s)) => Some(s)
    _ => None
  }
  ignore(self)
  Some({
    client_msg_id,
    text,
    user_id,
    user_name: "", // Would need to look up from users.info
    channel_id,
    ts,
    thread_ts,
    blocks: None,
    bot_id,
    subtype,
  })
}

///|
/// Process interaction payload
pub fn SlackPlugin::process_interaction(
  self : SlackPlugin,
  payload : Json,
) -> Json? {
  match payload {
    Object(obj) => {
      let response : Map[String, Json] = {}
      match obj.get("type") {
        Some(String(t)) => response["interaction_type"] = Json::string(t)
        _ => ()
      }
      match obj.get("user") {
        Some(Object(user)) =>
          match user.get("id") {
            Some(String(id)) => response["user_id"] = Json::string(id)
            _ => ()
          }
        _ => ()
      }
      match obj.get("channel") {
        Some(Object(ch)) =>
          match ch.get("id") {
            Some(String(id)) => response["channel_id"] = Json::string(id)
            _ => ()
          }
        _ => ()
      }
      match obj.get("actions") {
        Some(Array(actions)) =>
          if actions.length() > 0 {
            match actions[0] {
              Object(action) => {
                match action.get("action_id") {
                  Some(String(id)) => response["action_id"] = Json::string(id)
                  _ => ()
                }
                match action.get("value") {
                  Some(String(v)) => response["action_value"] = Json::string(v)
                  _ => ()
                }
              }
              _ => ()
            }
          }
        _ => ()
      }
      ignore(self)
      Some(Json::object(response))
    }
    _ => None
  }
}

///|
/// Receive message from buffer
pub fn SlackPlugin::receive(self : SlackPlugin) -> SlackMessage? {
  @util.pop_first(self.received_messages)
}

///|
/// Add message to buffer
pub fn SlackPlugin::add_received_message(
  self : SlackPlugin,
  message : SlackMessage,
) -> Unit {
  self.received_messages.push(message)
}

///|
/// Convert SlackMessage to JSON
fn slack_message_to_json(msg : SlackMessage) -> Json {
  let result : Map[String, Json] = {
    "text": Json::string(msg.text),
    "user_id": Json::string(msg.user_id),
    "user_name": Json::string(msg.user_name),
    "channel_id": Json::string(msg.channel_id),
    "ts": Json::string(msg.ts),
  }
  match msg.client_msg_id {
    Some(c) => result["client_msg_id"] = Json::string(c)
    None => ()
  }
  match msg.thread_ts {
    Some(t) => result["thread_ts"] = Json::string(t)
    None => ()
  }
  match msg.bot_id {
    Some(b) => result["bot_id"] = Json::string(b)
    None => ()
  }
  match msg.subtype {
    Some(s) => result["subtype"] = Json::string(s)
    None => ()
  }
  Json::object(result)
}

///|
/// Handle JSON-RPC request
pub fn SlackPlugin::handle_request(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "send_message" => self.handle_send_message(request)
    "send_blocks" => self.handle_send_blocks(request)
    "update_message" => self.handle_update_message(request)
    "delete_message" => self.handle_delete_message(request)
    "add_reaction" => self.handle_add_reaction(request)
    "upload_file" => self.handle_upload_file(request)
    "event" => self.handle_event(request)
    "interaction" => self.handle_interaction(request)
    "receive" => self.handle_receive(request)
    "connect" => self.handle_connect(request)
    "disconnect" => self.handle_disconnect(request)
    "status" => self.handle_status(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn SlackPlugin::handle_send_message(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(response) => return response
  }
  let text = match @interfaces.rpc_require_string(request, "text") {
    Ok(t) => t
    Err(response) => return response
  }
  let thread_ts = @interfaces.rpc_string_or_none(request, "thread_ts")
  let mrkdwn = @interfaces.rpc_optional_bool(request, "mrkdwn", true)
  let result = self.send_message(channel, text, thread_ts~, mrkdwn~)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn SlackPlugin::handle_send_blocks(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(response) => return response
  }
  let text = @interfaces.rpc_string_or_none(request, "text")
  let thread_ts = @interfaces.rpc_string_or_none(request, "thread_ts")
  // Parse blocks from params (simplified - create a section block)
  let blocks : Array[SlackBlock] = []
  match @interfaces.rpc_get_params(request) {
    Some(params) =>
      match params.get("blocks") {
        Some(Array(block_arr)) =>
          for block_json in block_arr {
            match block_json {
              Object(blk) => {
                let block_type = match blk.get("type") {
                  Some(String(t)) => t
                  _ => continue
                }
                let block_id : String? = match blk.get("block_id") {
                  Some(String(id)) => Some(id)
                  _ => None
                }
                let text_obj : SlackTextObject? = match blk.get("text") {
                  Some(Object(txt)) => {
                    let text_type = match txt.get("type") {
                      Some(String(t)) => t
                      _ => "plain_text"
                    }
                    let text_val = match txt.get("text") {
                      Some(String(t)) => t
                      _ => ""
                    }
                    Some({ text_type, text: text_val, emoji: true })
                  }
                  _ => None
                }
                blocks.push({
                  block_type,
                  block_id,
                  text: text_obj,
                  accessory: None,
                  elements: None,
                })
              }
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
  let result = self.send_blocks(channel, blocks, text~, thread_ts~)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn SlackPlugin::handle_update_message(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(response) => return response
  }
  let ts = match @interfaces.rpc_require_string(request, "ts") {
    Ok(t) => t
    Err(response) => return response
  }
  let text = match @interfaces.rpc_require_string(request, "text") {
    Ok(t) => t
    Err(response) => return response
  }
  let result = self.update_message(channel, ts, text)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn SlackPlugin::handle_delete_message(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(response) => return response
  }
  let ts = match @interfaces.rpc_require_string(request, "ts") {
    Ok(t) => t
    Err(response) => return response
  }
  let result = self.delete_message(channel, ts)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn SlackPlugin::handle_add_reaction(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let channel = match @interfaces.rpc_require_string(request, "channel") {
    Ok(c) => c
    Err(response) => return response
  }
  let timestamp = match @interfaces.rpc_require_string(request, "timestamp") {
    Ok(t) => t
    Err(response) => return response
  }
  let emoji_name = match @interfaces.rpc_require_string(request, "name") {
    Ok(n) => n
    Err(response) => return response
  }
  let result = self.add_reaction(channel, timestamp, emoji_name)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn SlackPlugin::handle_upload_file(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let content = match @interfaces.rpc_require_string(request, "content") {
    Ok(c) => c
    Err(response) => return response
  }
  let channels = @interfaces.rpc_string_array(request, "channels")
  if channels.length() == 0 {
    return @interfaces.rpc_invalid_params(
      "Missing 'channels' parameter",
      request.id,
    )
  }
  let filename = @interfaces.rpc_optional_string(
    request, "filename", "file.txt",
  )
  let title = @interfaces.rpc_string_or_none(request, "title")
  let initial_comment = @interfaces.rpc_string_or_none(
    request, "initial_comment",
  )
  let result = self.upload_file(
    channels,
    content,
    filename~,
    title~,
    initial_comment~,
  )
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn SlackPlugin::handle_event(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match @interfaces.rpc_get_params(request) {
    Some(params) =>
      match params.get("event") {
        Some(event) =>
          match self.process_event(event) {
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
fn SlackPlugin::handle_interaction(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match @interfaces.rpc_get_params(request) {
    Some(params) =>
      match params.get("payload") {
        Some(payload) =>
          match self.process_interaction(payload) {
            Some(result) =>
              @interfaces.JsonRpcResponse::success(result~, id=request.id)
            None =>
              @interfaces.rpc_invalid_params(
                "Invalid interaction payload",
                request.id,
              )
          }
        None =>
          @interfaces.rpc_invalid_params(
            "Missing 'payload' parameter",
            request.id,
          )
      }
    None => @interfaces.rpc_invalid_params("Missing parameters", request.id)
  }
}

///|
fn SlackPlugin::handle_receive(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match self.receive() {
    Some(msg) => {
      let result : Map[String, Json] = {}
      result["message"] = slack_message_to_json(msg)
      @interfaces.JsonRpcResponse::success(
        result=Json::object(result),
        id=request.id,
      )
    }
    None => @interfaces.rpc_null_result("message", request.id)
  }
}

///|
fn SlackPlugin::handle_connect(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  @interfaces.handle_connect_common(self, request)
}

///|
fn SlackPlugin::handle_disconnect(
  self : SlackPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  @interfaces.handle_disconnect_common(self, request)
}

///|
fn SlackPlugin::handle_status(
  self : SlackPlugin,
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
