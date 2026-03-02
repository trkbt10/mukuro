///|
/// シェルツール - コマンド実行
/// 定義と実装を統合

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn shell_tool() -> @types.ToolDefinition {
  make_tool_definition(
    name="shell",
    description="Execute shell commands",
    parameters=object_schema(
      {
        "command": string_param("Command to execute"),
        "cwd": string_param("Working directory"),
        "timeout": integer_param("Timeout in milliseconds"),
        "env": { "type": "object", "description": "Environment variables" },
      },
      ["command"],
    ),
  )
}

// =============================================================================
// Common Helpers
// =============================================================================

///|
/// 危険なコマンドかどうかをチェック
pub fn is_dangerous_command(command : String) -> Bool {
  let dangerous_patterns = [
    "rm -rf", "rm -r /", "dd if=", "mkfs", "> /dev/", "chmod -R 777", ":(){ :|:& };:",
  ]
  for pattern in dangerous_patterns {
    if command.contains(pattern) {
      return true
    }
  }
  false
}

///|
/// シングルクォートをエスケープ
fn escape_single_quote(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if c == '\'' {
      buf.write_string("'\\''")
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

// =============================================================================
// Tool Implementation Entry Point
// =============================================================================

///|
/// シェルツールを実行（プラットフォーム固有実装を呼び出す）
pub fn execute_shell(args : Json) -> ToolExecutionResult {
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
  // プラットフォーム固有実装を呼び出す
  execute_shell_platform(cmd_with_stderr)
}
