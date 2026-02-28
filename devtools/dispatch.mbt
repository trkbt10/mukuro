///|
/// ビルド支援ツールディスパッチ - Native向け

///|
/// ビルド支援ツールを同期実行（Native同期版）
pub fn execute_devtool(
  tool_name : String,
  args : Json,
) -> @defs.ToolExecutionResult? {
  match tool_name {
    "web" => Some(execute_web_tool_native(args))
    "shell" => Some(execute_shell_tool_native(args))
    "filesystem" => Some(execute_filesystem_tool_native(args))
    _ => None
  }
}

///|
/// ビルド支援ツールが存在するか
pub fn has_devtool(tool_name : String) -> Bool {
  match tool_name {
    "web" | "shell" | "filesystem" => true
    _ => false
  }
}

///|
/// ビルド支援ツールが同期実行可能か
pub fn is_sync_devtool(tool_name : String) -> Bool {
  match tool_name {
    "web" | "shell" | "filesystem" => true
    _ => false
  }
}

///|
/// 非同期ツールを実行 - Native向け（全ツール同期のため常にfalse）
pub fn execute_devtool_async(
  tool_name : String,
  _args : Json,
  _on_result : (@defs.ToolExecutionResult) -> Unit,
) -> Bool {
  ignore(tool_name)
  false
}
