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
