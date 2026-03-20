///|
/// MCP (Model Context Protocol) クライアント
/// JSON-RPC 2.0 over stdio でMCPサーバーと通信

///|
pub(all) suberror McpError {
  ConnectionFailed(String)
  ProtocolError(String)
  ToolNotFound(String)
}

///|
/// MCP クライアント（stdio transport を使用）
pub struct McpClient {
  /// サーバー設定
  config : McpServerConfig
  /// サーバーから取得したツール一覧（キャッシュ）
  tools : Array[McpToolDef]
  /// 初期化済みフラグ
  initialized : Bool
}

///|
pub fn McpClient::new(config : McpServerConfig) -> McpClient {
  { config, tools: [], initialized: false }
}

///|
/// MCP initialize リクエストを構築
fn build_initialize_request(request_id : Int) -> @interfaces.JsonRpcRequest {
  @interfaces.JsonRpcRequest::new(
    rpc_method="initialize",
    params=Some(
      {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": { "name": "mukuro", "version": "0.1.0" },
      },
    ),
    id=Some(request_id),
  )
}

///|
/// MCP tools/list リクエストを構築
fn build_tools_list_request(request_id : Int) -> @interfaces.JsonRpcRequest {
  @interfaces.JsonRpcRequest::new(
    rpc_method="tools/list",
    params=None,
    id=Some(request_id),
  )
}

///|
/// MCP tools/call リクエストを構築
fn build_tools_call_request(
  request_id : Int,
  tool_name : String,
  arguments : Json,
) -> @interfaces.JsonRpcRequest {
  @interfaces.JsonRpcRequest::new(
    rpc_method="tools/call",
    params=Some({ "name": tool_name, "arguments": arguments }),
    id=Some(request_id),
  )
}

///|
/// MCP initialized 通知を構築
fn build_initialized_notification() -> @interfaces.JsonRpcRequest {
  @interfaces.JsonRpcRequest::new(
    rpc_method="notifications/initialized",
    params=None,
    id=None,
  )
}

///|
/// tools/list レスポンスからツール定義を抽出
fn parse_tools_list_response(
  result : Json,
  server_name : String,
) -> Array[McpToolDef] {
  let tools : Array[McpToolDef] = []
  match result {
    { "tools": Array(tool_array), .. } =>
      for tool_json in tool_array {
        match tool_json {
          { "name": String(name), .. } => {
            let description = match tool_json {
              { "description": String(d), .. } => d
              _ => ""
            }
            let input_schema = match tool_json {
              { "inputSchema": schema, .. } => schema
              _ => { "type": "object", "properties": {} }
            }
            tools.push({ name, description, input_schema, server_name })
          }
          _ => ()
        }
      }
    _ => ()
  }
  tools
}

///|
/// tools/call レスポンスからコンテンツを抽出
pub fn parse_tool_call_result(result : Json) -> String {
  match result {
    { "content": Array(contents), .. } => {
      let buf = StringBuilder::new()
      for content in contents {
        match content {
          { "type": String("text"), "text": String(text), .. } => {
            if buf.to_string().length() > 0 {
              buf.write_char('\n')
            }
            buf.write_string(text)
          }
          _ => ()
        }
      }
      buf.to_string()
    }
    _ => result.stringify()
  }
}

///|
/// キャッシュ済みツール一覧を取得
pub fn McpClient::get_tools(self : McpClient) -> Array[McpToolDef] {
  self.tools
}

///|
/// ツール定義を llm_interop 形式に変換
pub fn McpClient::get_tool_definitions(
  self : McpClient,
) -> Array[@llm_types.ToolDefinition] {
  self.tools.map(fn(t) { t.to_tool_definition() })
}

///|
/// MCP ツール名からサーバーのツール名を解決
/// "mcp_servername_toolname" → "toolname"
pub fn resolve_mcp_tool_name(
  full_name : String,
  server_name : String,
) -> String? {
  let prefix = "mcp_\{server_name}_"
  if full_name.starts_with(prefix) {
    Some(full_name.substring(start=prefix.length()))
  } else {
    None
  }
}
