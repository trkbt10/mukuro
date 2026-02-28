///|
/// 全ツール定義を取得
pub fn get_all_tool_definitions() -> Array[@types.ToolDefinition] {
  [
    datetime_tool_definition(),
    memory_tool_definition(),
    message_tool_definition(),
    spawn_tool_definition(),
    web_tool_definition(),
    shell_tool_definition(),
    filesystem_tool_definition(),
  ]
}

///|
/// ツール名で定義を取得
pub fn get_tool_definition(name : String) -> @types.ToolDefinition? {
  for tool in get_all_tool_definitions() {
    if tool.name == name {
      return Some(tool)
    }
  }
  None
}
