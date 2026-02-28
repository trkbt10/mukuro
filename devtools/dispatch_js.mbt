///|
/// ビルド支援ツールディスパッチ - JS向け

///|
/// ビルド支援ツールを同期実行 - JS向け（全ツール非同期のため常にNone）
pub fn execute_devtool(
  tool_name : String,
  _args : Json,
) -> @defs.ToolExecutionResult? {
  ignore(tool_name)
  None
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
  ignore(tool_name)
  false
}

///|
/// 非同期ツールを実行 - JS向け
pub fn execute_devtool_async(
  tool_name : String,
  args : Json,
  on_result : (@defs.ToolExecutionResult) -> Unit,
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
