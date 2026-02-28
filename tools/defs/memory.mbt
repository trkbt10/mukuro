///|
/// メモリツール定義
pub fn memory_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="memory",
    description="Store and retrieve information in long-term memory",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([
            Json::string("get"),
            Json::string("set"),
            Json::string("delete"),
            Json::string("list"),
            Json::string("search"),
          ]),
          "description": "Action to perform on memory",
        },
        "key": string_param("Memory key (for get/set/delete)", false),
        "value": { "description": "Value to store (for set action)" },
        "query": string_param("Search query (for search action)", false),
      },
      ["action"],
    ),
  )
}
