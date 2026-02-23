///|
/// ビルトインツールレジストリ - WASM向けスタブ
/// Native/JSと同様のツール定義を返す

///|
/// WASM向け全ツール定義を取得
pub fn get_all_tool_definitions() -> Array[@types.ToolDefinition] {
  [
    datetime_tool_definition(),
    memory_tool_definition(),
    message_tool_definition(),
    spawn_tool_definition(),
  ]
}

///|
/// 非同期ツールを実行 - WASM向け
/// 注: 現在のWASM実装では非同期ツールはサポートしない
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
/// ツールが存在するか - WASM向け
pub fn has_tool(tool_name : String) -> Bool {
  match tool_name {
    "datetime" | "memory" | "spawn" | "message" => true
    _ => false
  }
}
