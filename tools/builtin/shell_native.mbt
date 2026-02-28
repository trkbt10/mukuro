///|
/// シェルツール - Native実装（popen使用）

///|
/// シェルツールを実行（Native同期版）
pub fn execute_shell_tool_native(args : Json) -> ToolExecutionResult {
  let command = match get_string_arg(args, "command") {
    Some(c) => c
    None => return ToolExecutionResult::error("Missing command argument")
  }
  // 危険なコマンドをチェック
  if is_dangerous_command(command) {
    return ToolExecutionResult::requires_confirmation({
      "command": command,
      "warning": "This command may be destructive. Please confirm execution.",
    })
  }
  let cwd = get_string_arg(args, "cwd")
  // コマンドを構築
  let full_cmd = match cwd {
    Some(dir) => {
      let escaped_dir = escape_single_quote(dir)
      "cd '\{escaped_dir}' && \{command}"
    }
    None => command
  }
  // 標準エラー出力もキャプチャ
  let cmd_with_stderr = full_cmd + " 2>&1"
  let (stdout, exit_code) = exec_popen(cmd_with_stderr)
  ToolExecutionResult::success({
    "stdout": stdout,
    "stderr": "",
    "exit_code": exit_code,
  })
}
