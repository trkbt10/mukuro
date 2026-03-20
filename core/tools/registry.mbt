///|
/// ツールレジストリ - すべてのツールエントリを集約
/// 新しいツールを追加するときは all_tool_entries() に1行追加するだけ

// =============================================================================
// Tool Registry
// =============================================================================

///|
/// すべてのビルトインツールエントリを返す
/// 新しいツールを追加するときはここに追加
pub fn all_tool_entries() -> Array[ToolEntry] {
  [
    datetime_entry(),
    memory_entry(),
    trace_entry(),
    message_entry(),
    spawn_entry(),
    shell_entry(),
    filesystem_entry(),
    edit_file_entry(),
    web_entry(),
  ]
}

///|
/// ツール名からエントリを取得
pub fn get_tool_entry(name : String) -> ToolEntry? {
  for entry in all_tool_entries() {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
/// すべてのビルトインツール定義を返す
pub fn all_tool_definitions() -> Array[@llm_types.ToolDefinition] {
  all_tool_entries().map(fn(entry) { entry.definition })
}

///|
/// ツール名から定義を取得
pub fn get_tool_definition(name : String) -> @llm_types.ToolDefinition? {
  match get_tool_entry(name) {
    Some(entry) => Some(entry.definition)
    None => None
  }
}

///|
/// ツールが存在するかチェック
pub fn has_tool(name : String) -> Bool {
  not(get_tool_entry(name) is None)
}

///|
/// ツール名一覧を返す
pub fn all_tool_names() -> Array[String] {
  all_tool_entries().map(fn(entry) { entry.name })
}

///|
/// ツール名から設定スキーマを取得
pub fn get_settings_schema(name : String) -> Json? {
  match get_tool_entry(name) {
    Some(entry) => entry.settings_schema
    None => None
  }
}
