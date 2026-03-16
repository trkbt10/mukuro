///|
/// シェルツール - Native実装（subprocess パッケージ使用）

///|
async fn execute_shell_platform(
  command : String,
  cwd~ : String?,
) -> ToolExecutionResult {
  let result = @subprocess.exec(command, cwd?, check=false) catch {
    _ => {
      return ToolExecutionResult::error("Failed to execute command")
    }
  }
  ToolExecutionResult::success({
    "stdout": result.stdout,
    "stderr": result.stderr,
    "exit_code": result.exit_code,
  })
}
