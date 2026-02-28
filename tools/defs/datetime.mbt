///|
/// DateTimeツール定義
pub fn datetime_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="datetime",
    description="Get current date and time information",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([
            Json::string("now"),
            Json::string("timestamp"),
            Json::string("format"),
          ]),
          "description": "Action to perform: now (current datetime), timestamp (unix timestamp), format (formatted string)",
        },
        "format": string_param("Date format pattern (for format action)", false),
        "timezone": string_param("Timezone (e.g., UTC, JST)", false),
      },
      ["action"],
    ),
  )
}
