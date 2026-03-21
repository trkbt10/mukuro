///|
/// MCP サーバー管理 — config.json からMCPサーバーを起動しツールを登録
/// NativeStdioClient を使って MCP プロトコル (JSON-RPC 2.0) で通信

///|
/// グローバル MCP クライアント管理
let mcp_clients : Array[(@plugin.McpClient, @plugin_runtime.NativeStdioClient)] = []

///|
/// config.json から MCP サーバー設定を読み込み、初期化してツールを登録
pub fn initialize_mcp_servers(config_json : Json) -> Unit {
  let servers = match config_json {
    { "mcp_servers": Object(servers), .. } => servers
    _ => return // mcp_servers セクションなし
  }
  for name, server_json in servers {
    let config = match @plugin.McpServerConfig::from_json(name, server_json) {
      Some(c) => c
      None => continue
    }
    let stdio_client = @plugin_runtime.NativeStdioClient::new(
      command=config.command,
      args=config.args,
      cwd=config.cwd,
      env=config.env,
    )
    let mcp_client = @plugin.McpClient::new(config)
    // 1. initialize ハンドシェイク
    let init_req = @interfaces.JsonRpcRequest::new(
      rpc_method="initialize",
      params=Some(
        {
          "protocolVersion": "2024-11-05",
          "capabilities": {},
          "clientInfo": { "name": "mukuro", "version": "0.1.0" },
        },
      ),
      id=Some(1),
    )
    let init_response = stdio_client.send_request(init_req) catch { _ => continue }
    ignore(init_response)
    // 2. initialized 通知
    let notif = @interfaces.JsonRpcRequest::new(
      rpc_method="notifications/initialized",
      params=None,
      id=None,
    )
    ignore(stdio_client.send_request(notif)) catch { _ => () }
    // 3. tools/list でツール一覧取得
    let list_req = @interfaces.JsonRpcRequest::new(
      rpc_method="tools/list",
      params=None,
      id=Some(2),
    )
    let list_response = stdio_client.send_request(list_req) catch { _ => continue }
    let tools_json = match list_response.result {
      Some(r) => r
      None => continue
    }
    // ツール定義をパースして動的レジストリに登録
    let tools = parse_mcp_tools(tools_json, name)
    for tool in tools {
      let tool_def = tool.to_tool_definition()
      let server_name = name
      let tool_name = tool.name
      // クロージャで stdio_client をキャプチャ
      let captured_client = stdio_client
      let entry : @tools.ToolEntry = {
        name: tool_def.name,
        definition: tool_def,
        settings_schema: None,
        execute: fn(_, args) {
          execute_mcp_tool(captured_client, server_name, tool_name, args)
        },
      }
      @tools.register_external_tool(entry)
    }
    mcp_clients.push((mcp_client, stdio_client))
  }
}

///|
/// MCP tools/list レスポンスからツール定義を抽出
fn parse_mcp_tools(
  result : Json,
  server_name : String,
) -> Array[@plugin.McpToolDef] {
  @plugin.parse_tools_list_response(result, server_name)
}

///|
/// MCP ツールを実行
fn execute_mcp_tool(
  client : @plugin_runtime.NativeStdioClient,
  server_name : String,
  tool_name : String,
  args : Json,
) -> @tools.ToolExecutionResult {
  let req = @interfaces.JsonRpcRequest::new(
    rpc_method="tools/call",
    params=Some({ "name": tool_name, "arguments": args }),
    id=Some(3),
  )
  let response = client.send_request(req) catch {
    _ =>
      return @tools.ToolExecutionResult::error(
        "MCP tool call failed: \{server_name}/\{tool_name}",
      )
  }
  match response.error {
    Some(err) =>
      return @tools.ToolExecutionResult::error(
        "MCP error: \{err.message}",
      )
    None => ()
  }
  match response.result {
    Some(result) => {
      let content = @plugin.parse_tool_call_result(result)
      @tools.ToolExecutionResult::success({ "output": content })
    }
    None => @tools.ToolExecutionResult::error("MCP tool returned no result")
  }
}
