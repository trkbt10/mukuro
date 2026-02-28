///|
/// メッセージツール - メッセージの操作・送信

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
) -> @defs.ToolExecutionResult {
  let action = match @defs.get_string_arg(args, "action") {
    Some(a) => a
    None => return @defs.ToolExecutionResult::error("Missing action argument")
  }
  match action {
    "send" => {
      let channel = match @defs.get_string_arg(args, "channel") {
        Some(c) => c
        None =>
          return @defs.ToolExecutionResult::error("Missing channel argument")
      }
      let chat_id = match @defs.get_string_arg(args, "chat_id") {
        Some(c) => c
        None =>
          return @defs.ToolExecutionResult::error("Missing chat_id argument")
      }
      let content = match @defs.get_string_arg(args, "content") {
        Some(c) => c
        None =>
          return @defs.ToolExecutionResult::error("Missing content argument")
      }
      let message = build_outbound_message(channel, chat_id, content, None)
      send_fn(message)
      @defs.ToolExecutionResult::success({
        "sent": true,
        "channel": channel,
        "chat_id": chat_id,
      })
    }
    "reply" => {
      let channel = match @defs.get_string_arg(args, "channel") {
        Some(c) => c
        None =>
          return @defs.ToolExecutionResult::error("Missing channel argument")
      }
      let chat_id = match @defs.get_string_arg(args, "chat_id") {
        Some(c) => c
        None =>
          return @defs.ToolExecutionResult::error("Missing chat_id argument")
      }
      let content = match @defs.get_string_arg(args, "content") {
        Some(c) => c
        None =>
          return @defs.ToolExecutionResult::error("Missing content argument")
      }
      let reply_to = @defs.get_string_arg(args, "message_id")
      let message = build_outbound_message(channel, chat_id, content, reply_to)
      send_fn(message)
      @defs.ToolExecutionResult::success({
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
      @defs.ToolExecutionResult::error(
        "Edit action requires channel-specific implementation",
      )
    "delete" =>
      // 削除は各チャネル固有のAPIを使用する必要がある
      @defs.ToolExecutionResult::error(
        "Delete action requires channel-specific implementation",
      )
    "react" =>
      // リアクションは各チャネル固有のAPIを使用する必要がある
      @defs.ToolExecutionResult::error(
        "React action requires channel-specific implementation",
      )
    _ => @defs.ToolExecutionResult::error("Unknown action: \{action}")
  }
}
