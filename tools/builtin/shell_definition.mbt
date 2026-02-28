///|
/// シェルツール定義（全ターゲット共通）

///|
/// シェルツール定義
pub fn shell_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="shell",
    description="Execute shell commands",
    parameters=object_schema(
      {
        "command": string_param("Command to execute", true),
        "cwd": string_param("Working directory", false),
        "timeout": integer_param("Timeout in milliseconds"),
        "env": { "type": "object", "description": "Environment variables" },
      },
      ["command"],
    ),
  )
}

///|
/// 危険なコマンドかどうかをチェック
pub fn is_dangerous_command(command : String) -> Bool {
  let dangerous_patterns = [
    "rm -rf", "rm -r /", "dd if=", "mkfs", "> /dev/", "chmod -R 777",
    ":(){ :|:& };:",
  ]
  for pattern in dangerous_patterns {
    if command.contains(pattern) {
      return true
    }
  }
  false
}
