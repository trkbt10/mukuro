///|
/// Webツール - HTTP通信とWeb検索
/// 定義と実装を統合

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn web_tool() -> @types.ToolDefinition {
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
        "url": string_param("URL to fetch (for fetch action)"),
        "query": string_param("Search query (for search action)"),
        "method": {
          "type": "string",
          "enum": Json::array([Json::string("GET"), Json::string("POST")]),
          "description": "HTTP method (default: GET)",
        },
        "headers": { "type": "object", "description": "HTTP headers" },
        "body": string_param("Request body (for POST)"),
      },
      ["action"],
    ),
  )
}

// =============================================================================
// Tool Implementation Entry Point
// =============================================================================

///|
/// Webツールを実行
pub fn execute_web(args : Json) -> ToolExecutionResult {
  let action = match get_string_arg(args, "action") {
    Some(a) => a
    None => return ToolExecutionResult::error("Missing action argument")
  }
  match action {
    "fetch" => {
      let url = match get_string_arg(args, "url") {
        Some(u) => u
        None => return ToolExecutionResult::error("Missing url argument")
      }
      let http_method = get_string_arg(args, "method").unwrap_or("GET")
      let body = get_string_arg(args, "body")
      let headers = match args {
        { "headers": Object(h), .. } => Some(h)
        _ => None
      }
      web_fetch(url, http_method, headers, body)
    }
    "search" => {
      let _query = match get_string_arg(args, "query") {
        Some(q) => q
        None => return ToolExecutionResult::error("Missing query argument")
      }
      ToolExecutionResult::error("Web search requires external API integration")
    }
    _ => ToolExecutionResult::error("Unknown action: \{action}")
  }
}
