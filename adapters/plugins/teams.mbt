///|
/// Microsoft Teams Plugin
/// Provides Teams Bot integration via Bot Framework

///|
/// Teams message
pub(all) struct TeamsMessage {
  /// Message ID
  id : String
  /// Conversation ID
  conversation_id : String
  /// Channel ID
  channel_id : String
  /// Team ID
  team_id : String
  /// From user
  from_id : String
  /// From user name
  from_name : String
  /// Message text
  text : String
  /// Message type (message, typing, etc.)
  message_type : String
  /// Timestamp
  timestamp : String
  /// Service URL
  service_url : String
  /// Tenant ID
  tenant_id : String
}

///|
/// Adaptive card element
pub(all) struct AdaptiveCardElement {
  /// Element type
  element_type : String
  /// Element text
  text : String
  /// Element size
  size : String
  /// Element weight
  weight : String
}

///|
/// Adaptive card action
pub(all) struct AdaptiveCardAction {
  /// Action type (Action.Submit, Action.OpenUrl)
  action_type : String
  /// Action title
  title : String
  /// Action data or URL
  data : String
}

///|
/// Adaptive card
pub(all) struct AdaptiveCard {
  /// Card body elements
  body : Array[AdaptiveCardElement]
  /// Card actions
  actions : Array[AdaptiveCardAction]
}

///|
/// Create adaptive card JSON
pub fn AdaptiveCard::to_json(self : AdaptiveCard) -> Json {
  let body_json : Array[Json] = []
  for elem in self.body {
    let obj : Map[String, Json] = { "type": elem.element_type, "text": elem.text }
    if elem.size.length() > 0 {
      obj["size"] = Json::string(elem.size)
    }
    if elem.weight.length() > 0 {
      obj["weight"] = Json::string(elem.weight)
    }
    body_json.push(Json::object(obj))
  }
  let actions_json : Array[Json] = []
  for action in self.actions {
    let obj : Map[String, Json] = {
      "type": action.action_type,
      "title": action.title,
    }
    if action.action_type == "Action.OpenUrl" {
      obj["url"] = Json::string(action.data)
    } else {
      obj["data"] = Json::string(action.data)
    }
    actions_json.push(Json::object(obj))
  }
  {
    "type": "AdaptiveCard",
    "version": "1.4",
    "body": Json::array(body_json),
    "actions": Json::array(actions_json),
  }
}

///|
/// Teams plugin configuration
pub(all) struct TeamsPluginConfig {
  /// Plugin name
  name : String
  /// Bot ID (App ID)
  bot_id : String
  /// Bot Name
  bot_name : String
  /// Tenant ID (for single-tenant apps)
  tenant_id : String
}

///|
/// Default config
pub fn TeamsPluginConfig::default(name~ : String) -> TeamsPluginConfig {
  { name, bot_id: "", bot_name: "MukuroBot", tenant_id: "" }
}

///|
/// Teams plugin
pub struct TeamsPlugin {
  config : TeamsPluginConfig
  /// Received messages queue
  received_messages : Array[TeamsMessage]
  /// Conversations
  conversations : Map[String, TeamsMessage]
  mut is_connected : Bool
}

///|
/// Create new Teams plugin
pub fn TeamsPlugin::new(config : TeamsPluginConfig) -> TeamsPlugin {
  { config, received_messages: [], conversations: {}, is_connected: false }
}

///|
/// Create text response activity
pub fn TeamsPlugin::create_text_response(
  _self : TeamsPlugin,
  reply_to : TeamsMessage,
  text : String,
) -> Json {
  {
    "type": "message",
    "text": text,
    "from": { "id": reply_to.from_id, "name": reply_to.from_name },
    "conversation": { "id": reply_to.conversation_id },
    "recipient": { "id": reply_to.from_id },
    "serviceUrl": reply_to.service_url,
    "channelId": "msteams",
  }
}

///|
/// Create adaptive card response
pub fn TeamsPlugin::create_card_response(
  _self : TeamsPlugin,
  reply_to : TeamsMessage,
  card : AdaptiveCard,
) -> Json {
  let attachment : Map[String, Json] = {
    "contentType": "application/vnd.microsoft.card.adaptive",
    "content": card.to_json(),
  }
  {
    "type": "message",
    "attachments": Json::array([Json::object(attachment)]),
    "from": { "id": reply_to.from_id, "name": reply_to.from_name },
    "conversation": { "id": reply_to.conversation_id },
    "recipient": { "id": reply_to.from_id },
    "serviceUrl": reply_to.service_url,
    "channelId": "msteams",
  }
}

///|
/// Process incoming activity
pub fn TeamsPlugin::handle_activity(self : TeamsPlugin, activity : Json) -> Json {
  let activity_type = match activity {
    { "type": String(t), .. } => t
    _ => return { "status": "ignored" }
  }
  match activity_type {
    "message" => self.process_message(activity)
    "conversationUpdate" => self.process_conversation_update(activity)
    "invoke" => self.process_invoke(activity)
    _ => { "status": "ignored" }
  }
}

///|
fn TeamsPlugin::process_message(self : TeamsPlugin, activity : Json) -> Json {
  let id = match activity {
    { "id": String(i), .. } => i
    _ => ""
  }
  let conversation_id = match activity {
    { "conversation": { "id": String(c), .. }, .. } => c
    _ => ""
  }
  let channel_id = match activity {
    { "channelData": { "channel": { "id": String(c), .. }, .. }, .. } => c
    _ => ""
  }
  let team_id = match activity {
    { "channelData": { "team": { "id": String(t), .. }, .. }, .. } => t
    _ => ""
  }
  let from_id = match activity {
    { "from": { "id": String(f), .. }, .. } => f
    _ => ""
  }
  let from_name = match activity {
    { "from": { "name": String(n), .. }, .. } => n
    _ => ""
  }
  let text = match activity {
    { "text": String(t), .. } => t
    _ => ""
  }
  let timestamp = match activity {
    { "timestamp": String(t), .. } => t
    _ => ""
  }
  let service_url = match activity {
    { "serviceUrl": String(s), .. } => s
    _ => ""
  }
  let tenant_id = match activity {
    { "channelData": { "tenant": { "id": String(t), .. }, .. }, .. } => t
    _ => ""
  }
  // Remove bot mention from text
  let cleaned_text = remove_mention(text, self.config.bot_name)
  let message : TeamsMessage = {
    id,
    conversation_id,
    channel_id,
    team_id,
    from_id,
    from_name,
    text: cleaned_text,
    message_type: "message",
    timestamp,
    service_url,
    tenant_id,
  }
  self.received_messages.push(message)
  self.conversations[conversation_id] = message
  { "status": "ok" }
}

///|
fn remove_mention(text : String, bot_name : String) -> String {
  // Simple mention removal - in reality would parse HTML
  let mention_pattern = "<at>\{bot_name}</at>"
  if text.contains(mention_pattern) {
    text.replace(old=mention_pattern, new="").trim().to_string()
  } else {
    text
  }
}

///|
fn TeamsPlugin::process_conversation_update(
  _self : TeamsPlugin,
  _activity : Json,
) -> Json {
  // Handle member added/removed events
  { "status": "ok" }
}

///|
fn TeamsPlugin::process_invoke(
  _self : TeamsPlugin,
  activity : Json,
) -> Json {
  // Handle card action invokes
  let invoke_name = match activity {
    { "name": String(n), .. } => n
    _ => ""
  }
  match invoke_name {
    "adaptiveCard/action" => {
      let action_data = match activity {
        { "value": { "action": { "data": data, .. }, .. }, .. } => data
        _ => Json::null()
      }
      {
        "status": 200,
        "body": { "statusCode": 200, "type": "application/vnd.microsoft.activity.message", "value": action_data },
      }
    }
    _ => { "status": 200 }
  }
}

///|
/// Pop received message
pub fn TeamsPlugin::receive(self : TeamsPlugin) -> TeamsMessage? {
  @util.pop_first(self.received_messages)
}

///|
/// Handle JSON-RPC request
pub fn TeamsPlugin::handle_request(
  self : TeamsPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "send" => self.handle_send(request)
    "send_card" => self.handle_send_card(request)
    "activity" => self.handle_activity_rpc(request)
    "receive" => self.handle_receive(request)
    "status" => self.handle_status(request)
    "connect" => self.handle_connect(request)
    "disconnect" => self.handle_disconnect(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn TeamsPlugin::handle_send(
  self : TeamsPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (conversation_id, text) = match request.params {
    Some({ "conversation_id": String(c), "text": String(t), .. }) => (c, t)
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'conversation_id' or 'text' parameter",
        id=request.id,
      )
  }
  // Get conversation context
  match self.conversations.get(conversation_id) {
    Some(conv) => {
      let payload = self.create_text_response(conv, text)
      @interfaces.JsonRpcResponse::success(
        result={ "payload": payload, "status": "pending" },
        id=request.id,
      )
    }
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Conversation not found",
        id=request.id,
      )
  }
}

///|
fn TeamsPlugin::handle_send_card(
  self : TeamsPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let conversation_id = match request.params {
    Some({ "conversation_id": String(c), .. }) => c
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'conversation_id' parameter",
        id=request.id,
      )
  }
  // Parse card body
  let body = match request.params {
    Some({ "body": Array(b), .. }) => {
      let elems : Array[AdaptiveCardElement] = []
      for elem in b {
        match elem {
          { "type": String(t), "text": String(txt), .. } => {
            let size = match elem {
              { "size": String(s), .. } => s
              _ => ""
            }
            let weight = match elem {
              { "weight": String(w), .. } => w
              _ => ""
            }
            elems.push({ element_type: t, text: txt, size, weight })
          }
          _ => ()
        }
      }
      elems
    }
    _ => []
  }
  // Parse card actions
  let actions = match request.params {
    Some({ "actions": Array(a), .. }) => {
      let acts : Array[AdaptiveCardAction] = []
      for act in a {
        match act {
          { "type": String(t), "title": String(title), .. } => {
            let data = match act {
              { "data": String(d), .. } => d
              { "url": String(u), .. } => u
              _ => ""
            }
            acts.push({ action_type: t, title, data })
          }
          _ => ()
        }
      }
      acts
    }
    _ => []
  }
  let card : AdaptiveCard = { body, actions }
  match self.conversations.get(conversation_id) {
    Some(conv) => {
      let payload = self.create_card_response(conv, card)
      @interfaces.JsonRpcResponse::success(
        result={ "payload": payload, "status": "pending" },
        id=request.id,
      )
    }
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Conversation not found",
        id=request.id,
      )
  }
}

///|
fn TeamsPlugin::handle_activity_rpc(
  self : TeamsPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let activity = match request.params {
    Some({ "activity": a, .. }) => a
    Some(a) => a
    None => return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing activity",
        id=request.id,
      )
  }
  let result = self.handle_activity(activity)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn TeamsPlugin::handle_receive(
  self : TeamsPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match self.receive() {
    Some(msg) =>
      @interfaces.JsonRpcResponse::success(
        result={
          "id": msg.id,
          "conversation_id": msg.conversation_id,
          "from_id": msg.from_id,
          "from_name": msg.from_name,
          "text": msg.text,
          "timestamp": msg.timestamp,
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
fn TeamsPlugin::handle_status(
  self : TeamsPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  @interfaces.JsonRpcResponse::success(
    result={
      "connected": self.is_connected,
      "bot_id": self.config.bot_id,
      "pending_messages": Json::number(
        self.received_messages.length().to_double(),
      ),
    },
    id=request.id,
  )
}

///|
fn TeamsPlugin::handle_connect(
  self : TeamsPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.is_connected = true
  @interfaces.rpc_connect_response(request.id)
}

///|
fn TeamsPlugin::handle_disconnect(
  self : TeamsPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.is_connected = false
  @interfaces.rpc_disconnect_response(request.id)
}
