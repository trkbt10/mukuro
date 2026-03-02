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
    description="Execute shell commands on the local system. Use for: running programs, checking system status (ls, pwd, df), git operations, build commands, and any terminal operations. Returns stdout, stderr, and exit code. Dangerous commands (rm -rf, dd, etc.) require confirmation.",
    parameters=object_schema(
      {
        "command": string_param(
          "Shell command to execute (e.g., 'ls -la', 'git status', 'npm install')",
        ),
        "cwd": string_param(
          "Working directory path. Command runs here instead of default directory.",
        ),
        "timeout": integer_param(
          "Timeout in milliseconds (default: 30000). Use longer for slow operations.",
        ),
        "env": {
          "type": "object",
          "description": "Environment variables as key-value pairs (e.g., {\"NODE_ENV\": \"production\"})",
        },
      },
      ["command"],
    ),
  )
}

///|
/// Shell tool settings schema for UI
pub fn shell_settings_schema() -> Json {
  build_settings_schema(
    title="Shell Settings",
    description="Configure shell command execution behavior",
    fields=[
      number_field(
        key="default_timeout",
        label="Default Timeout (ms)",
        description="Default timeout for command execution in milliseconds",
        default_value=30000.0,
        min=Some(1000.0),
        max=Some(300000.0),
      ),
      select_field(
        key="default_shell",
        label="Default Shell",
        description="Shell to use for command execution",
        default_value="/bin/bash",
        options=[
          ("/bin/bash", "Bash"),
          ("/bin/zsh", "Zsh"),
          ("/bin/sh", "POSIX sh"),
        ],
      ),
      toggle_field(
        key="allow_dangerous",
        label="Allow Dangerous Commands",
        description="Skip safety checks for potentially destructive commands (not recommended)",
        default_value=false,
      ),
    ],
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
