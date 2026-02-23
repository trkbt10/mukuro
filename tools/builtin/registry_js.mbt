///|
/// ビルトインツールレジストリ - JS向け拡張

///|
/// JS向け全ツール定義を取得
pub fn get_all_tool_definitions() -> Array[@types.ToolDefinition] {
  [
    datetime_tool_definition(),
    memory_tool_definition(),
    message_tool_definition(),
    spawn_tool_definition(),
    web_tool_definition(),
    shell_tool_definition(),
    filesystem_tool_definition(),
  ]
}

///|
/// 非同期ツールを実行 - JS向け
pub fn execute_async_tool(
  _ctx : BuiltinToolContext,
  tool_name : String,
  args : Json,
  on_result : (ToolExecutionResult) -> Unit,
) -> Bool {
  match tool_name {
    "web" => {
      execute_web_tool(args, on_result)
      true
    }
    "shell" => {
      execute_shell_tool(args, on_result)
      true
    }
    "filesystem" => {
      execute_filesystem_tool(args, on_result)
      true
    }
    _ => false
  }
}

///|
/// ツールが存在するか - JS向け
pub fn has_tool(tool_name : String) -> Bool {
  match tool_name {
    "datetime"
    | "memory"
    | "spawn"
    | "message"
    | "web"
    | "shell"
    | "filesystem" => true
    _ => false
  }
}
