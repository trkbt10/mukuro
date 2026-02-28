///|
/// Webツール定義
pub fn web_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="web",
    description="Fetch web content or perform web searches",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([Json::string("fetch"), Json::string("search")]),
          "description": "Action: fetch (get URL content) or search (web search)",
        },
        "url": string_param("URL to fetch (for fetch action)", false),
        "query": string_param("Search query (for search action)", false),
        "method": {
          "type": "string",
          "enum": Json::array([Json::string("GET"), Json::string("POST")]),
          "description": "HTTP method (default: GET)",
        },
        "headers": { "type": "object", "description": "HTTP headers" },
        "body": string_param("Request body (for POST)", false),
      },
      ["action"],
    ),
  )
}
