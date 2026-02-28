///|
/// スポーンツール定義
pub fn spawn_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="spawn",
    description="Create a sub-agent to handle a specific task",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([
            Json::string("create"),
            Json::string("status"),
            Json::string("cancel"),
            Json::string("result"),
          ]),
          "description": "Action to perform",
        },
        "name": string_param("Sub-agent name (for create)", false),
        "system_prompt": string_param("System prompt for sub-agent", false),
        "message": string_param("Initial message/task for sub-agent", false),
        "model": string_param(
          "Model to use (default: inherit from parent)", false,
        ),
        "max_turns": integer_param("Maximum conversation turns"),
        "tools": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Tools available to sub-agent",
        },
        "agent_id": string_param("Agent ID (for status/cancel/result)", false),
      },
      ["action"],
    ),
  )
}
