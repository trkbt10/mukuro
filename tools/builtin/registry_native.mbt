///|
/// ビルトインツールレジストリ - Native向け

///|
/// Native向け全ツール定義を取得
/// 注: web, shell, filesystem はJS専用のため含まない
pub fn get_all_tool_definitions() -> Array[@types.ToolDefinition] {
  [
    datetime_tool_definition(),
    memory_tool_definition(),
    message_tool_definition(),
    spawn_tool_definition(),
  ]
}

///|
/// 非同期ツールを実行 - Native向け
/// 注: 現在のNative実装では非同期ツールはサポートしない
pub fn execute_async_tool(
  _ctx : BuiltinToolContext,
  tool_name : String,
  _args : Json,
  _on_result : (ToolExecutionResult) -> Unit,
) -> Bool {
  ignore(tool_name)
  false
}

///|
/// ツールが存在するか - Native向け
pub fn has_tool(tool_name : String) -> Bool {
  match tool_name {
    "datetime" | "memory" | "spawn" | "message" => true
    _ => false
  }
}
