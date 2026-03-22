///|
/// シェルツール - コマンド実行
/// 定義と実装を統合

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn shell_tool() -> @llm_types.ToolDefinition {
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
/// picoclaw の 43+ deny patterns を参考に MoonBit 向けに実装
pub fn is_dangerous_command(command : String) -> Bool {
  let cmd = command.to_lower()
  // 破壊的操作
  if cmd.contains("rm -rf") ||
    cmd.contains("rm -r /") ||
    cmd.contains("rm -fr") ||
    (cmd.contains("del ") && cmd.contains("/f")) ||
    (cmd.contains("rmdir") && cmd.contains("/s")) {
    return true
  }
  // ディスク操作
  if cmd.contains("dd if=") ||
    cmd.contains("mkfs") ||
    (cmd.contains("format ") && not(cmd.contains("printf"))) ||
    cmd.contains("diskpart") {
    return true
  }
  // デバイス書き込み (ただし /dev/null は許可)
  if cmd.contains("> /dev/sd") || cmd.contains("> /dev/nvme") {
    return true
  }
  // システム操作
  if contains_word(cmd, "shutdown") ||
    contains_word(cmd, "reboot") ||
    contains_word(cmd, "poweroff") {
    return true
  }
  // フォークボム
  if cmd.contains(":(){ :|:& };:") {
    return true
  }
  // 権限昇格
  if contains_word(cmd, "sudo") || contains_word(cmd, "chown") {
    return true
  }
  if cmd.contains("chmod -R 777") || cmd.contains("chmod 777") {
    return true
  }
  // プロセス殺害
  if contains_word(cmd, "pkill") ||
    contains_word(cmd, "killall") ||
    cmd.contains("kill -9") {
    return true
  }
  // シェルインジェクション
  if cmd.contains("| sh") || cmd.contains("| bash") || cmd.contains("| zsh") {
    return true
  }
  if cmd.contains("$(") || cmd.contains("${") {
    return true
  }
  // パイプ経由の危険コマンド
  if (cmd.contains("curl") || cmd.contains("wget")) &&
    (cmd.contains("| sh") || cmd.contains("| bash")) {
    return true
  }
  // eval
  if contains_word(cmd, "eval") {
    return true
  }
  // パッケージマネージャ (グローバルインストール)
  if cmd.contains("npm install -g") || cmd.contains("npm i -g") {
    return true
  }
  if cmd.contains("pip install") &&
    not(cmd.contains("--target")) &&
    not(cmd.contains("-t ")) {
    return true
  }
  if cmd.contains("apt install") ||
    cmd.contains("apt remove") ||
    cmd.contains("apt purge") ||
    cmd.contains("yum install") ||
    cmd.contains("yum remove") ||
    cmd.contains("dnf install") ||
    cmd.contains("dnf remove") {
    return true
  }
  // コンテナ操作
  if cmd.contains("docker run") || cmd.contains("docker exec") {
    return true
  }
  // Git 危険操作
  if cmd.contains("git push") || cmd.contains("git force") {
    return true
  }
  // SSH
  if cmd.contains("ssh ") && cmd.contains("@") {
    return true
  }
  false
}

///|
/// コマンド文字列内に単語境界付きで word が含まれるかチェック
/// 簡易実装: 前後がスペース/行頭/行末/セミコロン/パイプ等の場合に一致
fn contains_word(cmd : String, word : String) -> Bool {
  let word_len = word.length()
  let cmd_len = cmd.length()
  if cmd_len < word_len {
    return false
  }
  let mut i = 0
  while i <= cmd_len - word_len {
    if matches_at(cmd, i, word) {
      // 前の文字が境界か
      let before_ok = if i == 0 {
        true
      } else {
        is_word_boundary(char_at(cmd, i - 1))
      }
      // 後の文字が境界か
      let after_ok = if i + word_len >= cmd_len {
        true
      } else {
        is_word_boundary(char_at(cmd, i + word_len))
      }
      if before_ok && after_ok {
        return true
      }
    }
    i = i + 1
  }
  false
}

///|
fn is_word_boundary(c : Char) -> Bool {
  c == ' ' ||
  c == '\t' ||
  c == ';' ||
  c == '|' ||
  c == '&' ||
  c == '(' ||
  c == ')' ||
  c == '\n' ||
  c == '\r'
}

// =============================================================================
// Tool Implementation Entry Point
// =============================================================================

///|
/// Shellツールエントリ
pub fn shell_entry() -> ToolEntry {
  {
    name: "shell",
    definition: shell_tool(),
    settings_schema: Some(shell_settings_schema()),
    execute: async fn(ctx, args) {
      execute_shell(args, workspace_dir=ctx.workspace_dir)
    },
  }
}

///|
/// シェルツールを実行（プラットフォーム固有実装を呼び出す）
async fn execute_shell(
  args : Json,
  workspace_dir? : String? = None,
) -> ToolExecutionResult {
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
  // ワークスペース制限: cwd が指定された場合、境界チェック
  match cwd {
    Some(c) =>
      match validate_workspace_path(c, workspace_dir) {
        Some(err) => return ToolExecutionResult::error(err)
        None => ()
      }
    None => ()
  }
  // プラットフォーム固有実装を呼び出す
  execute_shell_platform(command, cwd~)
}
