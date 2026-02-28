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
