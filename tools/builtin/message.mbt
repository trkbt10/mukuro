///|
/// メッセージツール - メッセージの操作・送信

///|
/// メッセージツール定義
pub fn message_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="message",
    description="Send messages to channels or manipulate message content",
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
          "description": "Action to perform on message",
        },
        "channel": string_param("Target channel name", false),
        "chat_id": string_param("Target chat/thread ID", false),
        "content": string_param("Message content", false),
        "message_id": string_param("Message ID (for edit/delete/react)", false),
        "reaction": string_param("Reaction emoji (for react action)", false),
      },
      ["action"],
    ),
  )
}

///|
/// 送信メッセージを構築
pub fn build_outbound_message(
  channel : String,
  chat_id : String,
  content : String,
  reply_to : String?,
) -> @types.OutboundMessage {
  { channel, chat_id, content, reply_to, attachments: None, options: None }
}

///|
/// メッセージツールを実行
pub fn execute_message_tool(
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
      // 編集は各チャネル固有のAPIを使用する必要がある
      ToolExecutionResult::error(
        "Edit action requires channel-specific implementation",
      )
    "delete" =>
      // 削除は各チャネル固有のAPIを使用する必要がある
      ToolExecutionResult::error(
        "Delete action requires channel-specific implementation",
      )
    "react" =>
      // リアクションは各チャネル固有のAPIを使用する必要がある
      ToolExecutionResult::error(
        "React action requires channel-specific implementation",
      )
    _ => ToolExecutionResult::error("Unknown action: \{action}")
  }
}
