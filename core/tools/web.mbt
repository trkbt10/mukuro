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
    description="Fetch content from URLs via HTTP requests. Use for: retrieving web pages, calling REST APIs, downloading data. Supports GET/POST methods with custom headers. Note: 'search' action requires external API integration.",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([Json::string("fetch"), Json::string("search")]),
          "description": "Action: 'fetch' makes HTTP request to URL, 'search' performs web search (requires API setup)",
        },
        "url": string_param("Full URL including protocol (e.g., 'https://api.example.com/data')"),
        "query": string_param("Search query string (for search action)"),
        "method": {
          "type": "string",
          "enum": Json::array([Json::string("GET"), Json::string("POST")]),
          "description": "HTTP method: GET (retrieve data) or POST (send data)",
        },
        "headers": { "type": "object", "description": "Custom HTTP headers as key-value pairs (e.g., {\"Authorization\": \"Bearer token\"})" },
        "body": string_param("Request body for POST requests (JSON string or form data)"),
      },
      ["action"],
    ),
  )
}

///|
/// Web tool settings schema for UI
pub fn web_settings_schema() -> Json {
  build_settings_schema(
    title="Web Settings",
    description="Configure HTTP request behavior",
    fields=[
      number_field(
        key="timeout",
        label="Request Timeout (ms)",
        description="Timeout for HTTP requests",
        default_value=30000.0,
        min=Some(1000.0),
        max=Some(120000.0),
      ),
      text_field(
        key="user_agent",
        label="User Agent",
        description="Custom User-Agent header",
      ),
      text_field(
        key="proxy_url",
        label="Proxy URL",
        description="HTTP proxy for requests (optional)",
      ),
    ],
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
