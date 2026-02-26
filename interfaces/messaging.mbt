///|
/// Messaging Plugin Interfaces
/// Common traits and types for messaging platform plugins (Telegram, Discord, Slack, etc.)

///|
/// Unified message structure for cross-platform messaging
/// Platform-specific fields stored in metadata
pub(all) struct UnifiedMessage {
  /// Platform-agnostic message ID (string for flexibility)
  id : String
  /// Chat/Channel/Room identifier
  chat_id : String
  /// Sender identifier
  sender_id : String
  /// Sender display name
  sender_name : String
  /// Message content (text)
  content : String
  /// Unix timestamp in milliseconds
  timestamp : Int64
  /// Reply reference (message ID being replied to)
  reply_to : String?
  /// Platform-specific metadata
  metadata : Map[String, Json]
}

///|
/// Create a new unified message
pub fn UnifiedMessage::new(
  id~ : String,
  chat_id~ : String,
  sender_id~ : String,
  sender_name~ : String,
  content~ : String,
  timestamp~ : Int64,
) -> UnifiedMessage {
  {
    id,
    chat_id,
    sender_id,
    sender_name,
    content,
    timestamp,
    reply_to: None,
    metadata: {},
  }
}

///|
/// Create a unified message with reply
pub fn UnifiedMessage::with_reply(
  id~ : String,
  chat_id~ : String,
  sender_id~ : String,
  sender_name~ : String,
  content~ : String,
  timestamp~ : Int64,
  reply_to~ : String,
) -> UnifiedMessage {
  {
    id,
    chat_id,
    sender_id,
    sender_name,
    content,
    timestamp,
    reply_to: Some(reply_to),
    metadata: {},
  }
}

///|
/// Convert UnifiedMessage to JSON
pub fn UnifiedMessage::to_json(self : UnifiedMessage) -> Json {
  let obj : Map[String, Json] = {
    "id": Json::string(self.id),
    "chat_id": Json::string(self.chat_id),
    "sender_id": Json::string(self.sender_id),
    "sender_name": Json::string(self.sender_name),
    "content": Json::string(self.content),
    "timestamp": Json::number(self.timestamp.to_double()),
  }
  match self.reply_to {
    Some(r) => obj["reply_to"] = Json::string(r)
    None => ()
  }
  if self.metadata.length() > 0 {
    obj["metadata"] = Json::object(self.metadata)
  }
  Json::object(obj)
}

///|
/// Trait for messaging plugins with buffered message receiving
/// Extends ConnectablePlugin with message-specific operations
pub(open) trait MessagingPlugin {
  /// Get plugin name
  name(Self) -> String

  /// Get API base URL
  api_base_url(Self) -> String

  /// Build API endpoint URL
  api_endpoint(Self, String) -> String

  /// Receive next message from buffer (FIFO)
  receive(Self) -> UnifiedMessage?

  /// Get count of pending messages in buffer
  pending_count(Self) -> Int
}

///|
/// Common status handler for messaging plugins
/// Builds standard status response with connection state and extra fields
pub fn[P : MessagingPlugin + ConnectablePlugin] messaging_status_response(
  plugin : P,
  extra : Map[String, Json],
  request_id : Int?,
) -> JsonRpcResponse {
  let fields : Map[String, Json] = {
    "name": Json::string(plugin.name()),
    "pending_messages": Json::number(plugin.pending_count().to_double()),
    "api_base_url": Json::string(plugin.api_base_url()),
  }
  for k, v in extra {
    fields[k] = v
  }
  rpc_status_response(plugin.is_connected(), fields, request_id)
}

///|
/// Common receive handler for messaging plugins
/// Returns message or null result
pub fn[P : MessagingPlugin] messaging_receive_response(
  plugin : P,
  request_id : Int?,
) -> JsonRpcResponse {
  match plugin.receive() {
    Some(msg) => {
      let result : Map[String, Json] = { "message": msg.to_json() }
      JsonRpcResponse::success(result=Json::object(result), id=request_id)
    }
    None => rpc_null_result("message", request_id)
  }
}
