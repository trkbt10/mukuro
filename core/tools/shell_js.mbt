///|
/// シェルツール - JS実装（未サポート）

///|
fn execute_shell_platform(_command : String) -> ToolExecutionResult {
  ToolExecutionResult::error(
    "Shell execution is not supported in JavaScript environment",
  )
}
