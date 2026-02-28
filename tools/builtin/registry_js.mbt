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
/// 同期ツールを実行 - JS向け
pub fn execute_sync_tool(
  ctx : BuiltinToolContext,
  tool_name : String,
  args : Json,
) -> ToolExecutionResult? {
  match tool_name {
    "datetime" => Some(execute_datetime_tool(args))
    "memory" => Some(execute_memory_tool(ctx.memory, args))
    "spawn" => Some(execute_spawn_tool(ctx.agent_manager, args))
    "message" => Some(execute_message_tool(args, ctx.send_message))
    _ => None
  }
}

///|
/// ツールが同期かどうか - JS向け
pub fn is_sync_tool(tool_name : String) -> Bool {
  match tool_name {
    "datetime" | "memory" | "spawn" | "message" => true
    _ => false
  }
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
