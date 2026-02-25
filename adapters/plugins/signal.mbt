///|
/// Signal Plugin
/// Provides Signal messaging via signal-cli or linked device

///|
/// Signal message
pub(all) struct SignalMessage {
  /// Message timestamp (used as ID)
  timestamp : Int64
  /// Sender phone number
  sender : String
  /// Recipient (phone number or group ID)
  recipient : String
  /// Message text
  text : String
  /// Is group message
  is_group : Bool
  /// Group ID (if group message)
  group_id : String?
  /// Attachments
  attachments : Array[SignalAttachment]
  /// Quote (replied message)
  quote : SignalQuote?
  /// Mentions
  mentions : Array[SignalMention]
  /// Reaction (if this is a reaction)
  reaction : SignalReaction?
}

///|
/// Signal attachment
pub(all) struct SignalAttachment {
  /// Content type
  content_type : String
  /// Filename
  filename : String
  /// File path or ID
  id : String
  /// Size in bytes
  size : Int64
}

///|
/// Signal quote (reply reference)
pub(all) struct SignalQuote {
  /// Quoted message timestamp
  timestamp : Int64
  /// Quoted message author
  author : String
  /// Quoted text
  text : String
}

///|
/// Signal mention
pub(all) struct SignalMention {
  /// Start position in text
  start : Int
  /// Length of mention
  length : Int
  /// Mentioned user phone number
  uuid : String
}

///|
/// Signal reaction
pub(all) struct SignalReaction {
  /// Emoji
  emoji : String
  /// Target message timestamp
  target_timestamp : Int64
  /// Target message author
  target_author : String
  /// Is removal
  is_remove : Bool
}

///|
/// Signal plugin configuration
pub(all) struct SignalPluginConfig {
  /// Plugin name
  name : String
  /// Account phone number
  phone_number : String
  /// Signal-cli socket path
  socket_path : String
  /// Trust all keys (for testing)
  trust_all : Bool
}

///|
/// Default config
pub fn SignalPluginConfig::default(name~ : String) -> SignalPluginConfig {
  {
    name,
    phone_number: "",
    socket_path: "/var/run/signal-cli/socket",
    trust_all: false,
  }
}

///|
/// Signal plugin
pub struct SignalPlugin {
  config : SignalPluginConfig
  /// Received messages queue
  received_messages : Array[SignalMessage]
  /// Timestamp counter for outgoing messages
  mut next_timestamp : Int64
  mut is_connected : Bool
}

///|
/// Create new Signal plugin
pub fn SignalPlugin::new(config : SignalPluginConfig) -> SignalPlugin {
  { config, received_messages: [], next_timestamp: 1000000000000L, is_connected: false }
}

///|
/// Generate timestamp for new message
fn SignalPlugin::generate_timestamp(self : SignalPlugin) -> Int64 {
  let ts = self.next_timestamp
  self.next_timestamp = self.next_timestamp + 1L
  ts
}

///|
/// Create send message command
pub fn SignalPlugin::create_send_command(
  self : SignalPlugin,
  recipient : String,
  text : String,
  attachments~ : Array[String] = [],
  quote~ : SignalQuote? = None,
  mentions~ : Array[SignalMention] = [],
) -> Json {
  let cmd : Map[String, Json] = {
    "jsonrpc": "2.0",
    "method": "send",
    "params": {
      "account": self.config.phone_number,
      "message": text,
    },
  }
  // Add recipient (could be phone or group)
  let params = match cmd.get("params") {
    Some(Object(p)) => p
    _ => {}
  }
  if recipient.has_prefix("+") {
    params["recipient"] = Json::array([Json::string(recipient)])
  } else {
    params["groupId"] = Json::string(recipient)
  }
  // Add attachments
  if attachments.length() > 0 {
    let att_json : Array[Json] = []
    for att in attachments {
      att_json.push(Json::string(att))
    }
    params["attachments"] = Json::array(att_json)
  }
  // Add quote
  match quote {
    Some(q) =>
      params["quote"] = {
        "timestamp": Json::number(q.timestamp.to_double()),
        "author": q.author,
        "message": q.text,
      }
    None => ()
  }
  // Add mentions
  if mentions.length() > 0 {
    let mentions_json : Array[Json] = []
    for m in mentions {
      mentions_json.push(
        {
          "start": Json::number(m.start.to_double()),
          "length": Json::number(m.length.to_double()),
          "uuid": m.uuid,
        },
      )
    }
    params["mentions"] = Json::array(mentions_json)
  }
  cmd["params"] = Json::object(params)
  cmd["id"] = Json::number(self.generate_timestamp().to_double())
  Json::object(cmd)
}

///|
/// Create reaction command
pub fn SignalPlugin::create_reaction_command(
  self : SignalPlugin,
  recipient : String,
  emoji : String,
  target_author : String,
  target_timestamp : Int64,
  remove~ : Bool = false,
) -> Json {
  let cmd : Map[String, Json] = {
    "jsonrpc": "2.0",
    "method": "sendReaction",
    "params": {
      "account": self.config.phone_number,
      "emoji": emoji,
      "targetAuthor": target_author,
      "targetTimestamp": Json::number(target_timestamp.to_double()),
      "remove": Json::boolean(remove),
    },
  }
  let params = match cmd.get("params") {
    Some(Object(p)) => p
    _ => {}
  }
  if recipient.has_prefix("+") {
    params["recipient"] = Json::string(recipient)
  } else {
    params["groupId"] = Json::string(recipient)
  }
  cmd["params"] = Json::object(params)
  cmd["id"] = Json::number(self.generate_timestamp().to_double())
  Json::object(cmd)
}

///|
/// Process incoming message from signal-cli
pub fn SignalPlugin::handle_incoming(self : SignalPlugin, data : Json) -> Json {
  // Handle different message types
  match data {
    { "envelope": envelope, .. } => self.process_envelope(envelope)
    _ => ()
  }
  { "status": "ok" }
}

///|
fn SignalPlugin::process_envelope(self : SignalPlugin, envelope : Json) -> Unit {
  let sender = match envelope {
    { "source": String(s), .. } => s
    { "sourceNumber": String(s), .. } => s
    _ => return
  }
  let timestamp = match envelope {
    { "timestamp": Number(t, ..), .. } => t.to_int64()
    _ => 0L
  }
  // Check for data message
  match envelope {
    { "dataMessage": data_msg, .. } =>
      self.process_data_message(sender, timestamp, data_msg)
    _ => ()
  }
  // Check for sync message
  match envelope {
    { "syncMessage": { "sentMessage": sent_msg, .. }, .. } =>
      match sent_msg {
        { "destination": String(dest), .. } =>
          self.process_data_message(dest, timestamp, sent_msg)
        _ => ()
      }
    _ => ()
  }
}

///|
fn SignalPlugin::process_data_message(
  self : SignalPlugin,
  sender : String,
  timestamp : Int64,
  data_msg : Json,
) -> Unit {
  let text = match data_msg {
    { "message": String(m), .. } => m
    _ => ""
  }
  // Skip empty messages (might be typing indicator, etc.)
  if text.length() == 0 {
    // Check if it's a reaction
    match data_msg {
      { "reaction": reaction, .. } => {
        self.process_reaction(sender, timestamp, reaction)
        return
      }
      _ => ()
    }
    return
  }
  // Check for group
  let (is_group, group_id, recipient) = match data_msg {
    { "groupInfo": { "groupId": String(gid), .. }, .. } => (true, Some(gid), gid)
    _ => (false, None, sender)
  }
  // Parse attachments
  let attachments = match data_msg {
    { "attachments": Array(atts), .. } => {
      let result : Array[SignalAttachment] = []
      for att in atts {
        match att {
          { "contentType": String(ct), .. } => {
            let filename = match att {
              { "filename": String(f), .. } => f
              _ => ""
            }
            let att_id = match att {
              { "id": String(i), .. } => i
              _ => ""
            }
            let size = match att {
              { "size": Number(s, ..), .. } => s.to_int64()
              _ => 0L
            }
            result.push({ content_type: ct, filename, id: att_id, size })
          }
          _ => ()
        }
      }
      result
    }
    _ => []
  }
  // Parse quote
  let quote = match data_msg {
    {
      "quote": { "id": Number(qid, ..), "author": String(qa), .. } as q,
      ..
    } => {
      let qtext = match q {
        { "text": String(t), .. } => t
        _ => ""
      }
      Some({ timestamp: qid.to_int64(), author: qa, text: qtext })
    }
    _ => None
  }
  // Parse mentions
  let mentions = match data_msg {
    { "mentions": Array(ments), .. } => {
      let result : Array[SignalMention] = []
      for m in ments {
        match m {
          {
            "start": Number(s, ..),
            "length": Number(l, ..),
            "uuid": String(u),
            ..
          } => result.push({ start: s.to_int(), length: l.to_int(), uuid: u })
          _ => ()
        }
      }
      result
    }
    _ => []
  }
  let message : SignalMessage = {
    timestamp,
    sender,
    recipient,
    text,
    is_group,
    group_id,
    attachments,
    quote,
    mentions,
    reaction: None,
  }
  self.received_messages.push(message)
}

///|
fn SignalPlugin::process_reaction(
  self : SignalPlugin,
  sender : String,
  timestamp : Int64,
  reaction : Json,
) -> Unit {
  let emoji = match reaction {
    { "emoji": String(e), .. } => e
    _ => return
  }
  let target_timestamp = match reaction {
    { "targetSentTimestamp": Number(t, ..), .. } => t.to_int64()
    _ => 0L
  }
  let target_author = match reaction {
    { "targetAuthor": String(a), .. } => a
    _ => ""
  }
  let is_remove = match reaction {
    { "isRemove": True, .. } => true
    _ => false
  }
  let message : SignalMessage = {
    timestamp,
    sender,
    recipient: sender,
    text: "",
    is_group: false,
    group_id: None,
    attachments: [],
    quote: None,
    mentions: [],
    reaction: Some({ emoji, target_timestamp, target_author, is_remove }),
  }
  self.received_messages.push(message)
}

///|
/// Pop received message
pub fn SignalPlugin::receive(self : SignalPlugin) -> SignalMessage? {
  @util.pop_first(self.received_messages)
}

///|
/// Handle JSON-RPC request
pub fn SignalPlugin::handle_request(
  self : SignalPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "send" => self.handle_send(request)
    "send_reaction" => self.handle_send_reaction(request)
    "incoming" => self.handle_incoming_rpc(request)
    "receive" => self.handle_receive(request)
    "status" => self.handle_status(request)
    "connect" => self.handle_connect(request)
    "disconnect" => self.handle_disconnect(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn SignalPlugin::handle_send(
  self : SignalPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (recipient, text) = match request.params {
    Some({ "recipient": String(r), "text": String(t), .. }) => (r, t)
    Some({ "to": String(r), "text": String(t), .. }) => (r, t)
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'recipient' or 'text' parameter",
        id=request.id,
      )
  }
  let attachments = match request.params {
    Some({ "attachments": Array(a), .. }) => {
      let result : Array[String] = []
      for v in a {
        match v {
          String(s) => result.push(s)
          _ => ()
        }
      }
      result
    }
    _ => []
  }
  let cmd = self.create_send_command(recipient, text, attachments~)
  @interfaces.JsonRpcResponse::success(
    result={ "command": cmd, "status": "pending" },
    id=request.id,
  )
}

///|
fn SignalPlugin::handle_send_reaction(
  self : SignalPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (recipient, emoji, target_author, target_timestamp) = match request.params {
    Some(
      {
        "recipient": String(r),
        "emoji": String(e),
        "target_author": String(ta),
        "target_timestamp": Number(tt, ..),
        ..
      },
    ) => (r, e, ta, tt.to_int64())
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing required parameters",
        id=request.id,
      )
  }
  let remove = match request.params {
    Some({ "remove": True, .. }) => true
    _ => false
  }
  let cmd = self.create_reaction_command(
    recipient, emoji, target_author, target_timestamp, remove~,
  )
  @interfaces.JsonRpcResponse::success(
    result={ "command": cmd, "status": "pending" },
    id=request.id,
  )
}

///|
fn SignalPlugin::handle_incoming_rpc(
  self : SignalPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let data = match request.params {
    Some({ "data": d, .. }) => d
    Some(d) => d
    None => return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing data",
        id=request.id,
      )
  }
  let result = self.handle_incoming(data)
  @interfaces.JsonRpcResponse::success(result~, id=request.id)
}

///|
fn SignalPlugin::handle_receive(
  self : SignalPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match self.receive() {
    Some(msg) => {
      let result : Map[String, Json] = {
        "timestamp": Json::number(msg.timestamp.to_double()),
        "sender": msg.sender,
        "recipient": msg.recipient,
        "text": msg.text,
        "is_group": Json::boolean(msg.is_group),
      }
      match msg.group_id {
        Some(gid) => result["group_id"] = Json::string(gid)
        None => ()
      }
      match msg.reaction {
        Some(r) =>
          result["reaction"] = {
            "emoji": r.emoji,
            "target_timestamp": Json::number(r.target_timestamp.to_double()),
            "target_author": r.target_author,
            "is_remove": Json::boolean(r.is_remove),
          }
        None => ()
      }
      @interfaces.JsonRpcResponse::success(result=Json::object(result), id=request.id)
    }
    None =>
      @interfaces.JsonRpcResponse::success(
        result={ "message": Json::null() },
        id=request.id,
      )
  }
}

///|
fn SignalPlugin::handle_status(
  self : SignalPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  @interfaces.JsonRpcResponse::success(
    result={
      "connected": self.is_connected,
      "phone_number": self.config.phone_number,
      "pending_messages": Json::number(
        self.received_messages.length().to_double(),
      ),
    },
    id=request.id,
  )
}

///|
fn SignalPlugin::handle_connect(
  self : SignalPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.is_connected = true
  @interfaces.rpc_connect_response(request.id)
}

///|
fn SignalPlugin::handle_disconnect(
  self : SignalPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.is_connected = false
  @interfaces.rpc_disconnect_response(request.id)
}
