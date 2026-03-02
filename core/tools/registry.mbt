///|
/// ツールレジストリ - すべてのツール定義を集約
/// core/tools パッケージが唯一のツール定義のソース

// =============================================================================
// Tool Registry
// =============================================================================

///|
/// すべてのビルトインツール定義を返す
pub fn all_tool_definitions() -> Array[@types.ToolDefinition] {
  [
    datetime_tool(),
    memory_tool(),
    message_tool(),
    spawn_tool(),
    shell_tool(),
    filesystem_tool(),
    web_tool(),
  ]
}

///|
/// ツール名から定義を取得
pub fn get_tool_definition(name : String) -> @types.ToolDefinition? {
  for def in all_tool_definitions() {
    if def.name == name {
      return Some(def)
    }
  }
  None
}

///|
/// ツールが存在するかチェック
pub fn has_tool(name : String) -> Bool {
  match get_tool_definition(name) {
    Some(_) => true
    None => false
  }
}

///|
/// ツール名一覧を返す
pub fn all_tool_names() -> Array[String] {
  all_tool_definitions().map(fn(def) { def.name })
}
