///|
/// エージェント内部ツールディスパッチ - Native向け

///|
/// エージェント内部ツールを同期実行
pub fn execute_builtin_tool(
  ctx : BuiltinToolContext,
  tool_name : String,
  args : Json,
) -> @defs.ToolExecutionResult? {
  match tool_name {
    "datetime" => Some(execute_datetime_tool(args))
    "memory" => Some(execute_memory_tool(ctx.memory, args))
    "spawn" => Some(execute_spawn_tool(ctx.agent_manager, args))
    "message" => Some(execute_message_tool(args, ctx.send_message))
    _ => None
  }
}

///|
/// エージェント内部ツールが存在するか
pub fn has_builtin_tool(tool_name : String) -> Bool {
  match tool_name {
    "datetime" | "memory" | "spawn" | "message" => true
    _ => false
  }
}

///|
/// エージェント内部ツールが同期実行可能か
pub fn is_sync_builtin_tool(tool_name : String) -> Bool {
  match tool_name {
    "datetime" | "memory" | "spawn" | "message" => true
    _ => false
  }
}

///|
/// 非同期ツールを実行 - エージェント内部ツールは全て同期のため常にfalse
pub fn execute_builtin_tool_async(
  _ctx : BuiltinToolContext,
  tool_name : String,
  _args : Json,
  _on_result : (@defs.ToolExecutionResult) -> Unit,
) -> Bool {
  ignore(tool_name)
  false
}
