///|
/// Messageツール - メッセージの操作・送信
/// 定義と実装を統合

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn message_tool() -> @types.ToolDefinition {
  make_tool_definition(
    name="message",
    description="Send messages to external channels (Slack, Discord, etc.) or other chat sessions. Use for: notifying users, sending results to other channels, cross-channel communication. Note: edit/delete/react require channel-specific implementation.",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([
            Json::string("send"),
            Json::string("reply"),
            Json::string("edit"),
            Json::string("delete"),
            Json::string("react"),
          ]),
          "description": "Action: 'send' new message, 'reply' to existing, 'edit' message, 'delete' message, 'react' with emoji",
        },
        "channel": string_param("Target channel identifier (e.g., 'slack', 'discord', 'web_chat')"),
        "chat_id": string_param("Specific chat/thread/room ID within the channel"),
        "content": string_param("Message text content to send"),
        "message_id": string_param("ID of existing message (required for edit/delete/react)"),
        "reaction": string_param("Emoji reaction (for react action, e.g., ':thumbsup:')"),
      },
      ["action"],
    ),
  )
}

// =============================================================================
// Tool Implementation
// =============================================================================

///|
pub fn build_outbound_message(
  channel : String,
  chat_id : String,
  content : String,
  reply_to : String?,
) -> @types.OutboundMessage {
  { channel, chat_id, content, reply_to, attachments: None, options: None }
}

///|
pub fn execute_message(
  args : Json,
  send_fn : (@types.OutboundMessage) -> Unit,
) -> ToolExecutionResult {
  let action = match get_string_arg(args, "action") {
    Some(a) => a
    None => return ToolExecutionResult::error("Missing action argument")
  }
  match action {
    "send" => {
      let channel = match get_string_arg(args, "channel") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing channel argument")
      }
      let chat_id = match get_string_arg(args, "chat_id") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing chat_id argument")
      }
      let content = match get_string_arg(args, "content") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing content argument")
      }
      let message = build_outbound_message(channel, chat_id, content, None)
      send_fn(message)
      ToolExecutionResult::success({
        "sent": true,
        "channel": channel,
        "chat_id": chat_id,
      })
    }
    "reply" => {
      let channel = match get_string_arg(args, "channel") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing channel argument")
      }
      let chat_id = match get_string_arg(args, "chat_id") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing chat_id argument")
      }
      let content = match get_string_arg(args, "content") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing content argument")
      }
      let reply_to = get_string_arg(args, "message_id")
      let message = build_outbound_message(channel, chat_id, content, reply_to)
      send_fn(message)
      ToolExecutionResult::success({
        "sent": true,
        "channel": channel,
        "chat_id": chat_id,
        "reply_to": match reply_to {
          Some(r) => Json::string(r)
          None => Json::null()
        },
      })
    }
    "edit" =>
      ToolExecutionResult::error("Edit action requires channel-specific implementation")
    "delete" =>
      ToolExecutionResult::error("Delete action requires channel-specific implementation")
    "react" =>
      ToolExecutionResult::error("React action requires channel-specific implementation")
    _ => ToolExecutionResult::error("Unknown action: \{action}")
  }
}
