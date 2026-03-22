///|
/// edit_file ツール - テキスト置換によるファイル編集
/// write_file より安全: old_text が一致しなければ編集を拒否

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn edit_file_tool() -> @llm_types.ToolDefinition {
  make_tool_definition(
    name="edit_file",
    description="Edit a file by replacing exact text matches. Safer than write_file because it requires specifying the exact text to replace, preventing accidental overwrites. The old_text must match exactly (including whitespace and indentation). If old_text is not found, the edit is rejected.",
    parameters=object_schema(
      {
        "path": string_param(
          "Absolute or relative file path to edit. Path traversal (..) is blocked.",
        ),
        "old_text": string_param(
          "The exact text to find and replace. Must match the file content exactly including whitespace.",
        ),
        "new_text": string_param(
          "The text to replace old_text with. Use empty string to delete the matched text.",
        ),
        "count": integer_param(
          "Number of occurrences to replace. Default 1. Use 0 to replace all occurrences.",
        ),
      },
      ["path", "old_text", "new_text"],
    ),
  )
}

///|
pub fn edit_file_settings_schema() -> Json {
  build_settings_schema(
    title="Edit File Settings",
    description="Configure file editing behavior",
    fields=[
      number_field(
        key="max_file_size",
        label="Max File Size (bytes)",
        description="Maximum file size that can be edited",
        default_value=10485760.0, // 10MB
        min=Some(1024.0),
        max=Some(104857600.0),
      ),
      toggle_field(
        key="create_backup",
        label="Create Backup",
        description="Create a .bak backup before editing",
        default_value=false,
      ),
    ],
  )
}

// =============================================================================
// Tool Implementation Entry Point
// =============================================================================

///|
pub fn edit_file_entry() -> ToolEntry {
  {
    name: "edit_file",
    definition: edit_file_tool(),
    settings_schema: Some(edit_file_settings_schema()),
    execute: fn(ctx, args) {
      execute_edit_file(args, workspace_dir=ctx.workspace_dir)
    },
  }
}

///|
fn execute_edit_file(
  args : Json,
  workspace_dir? : String? = None,
) -> ToolExecutionResult {
  let path = match get_string_arg(args, "path") {
    Some(p) => p
    None => return ToolExecutionResult::error("Missing path argument")
  }
  // パストラバーサル + ワークスペース境界チェック
  match validate_workspace_path(path, workspace_dir) {
    Some(err) => return ToolExecutionResult::error(err)
    None => ()
  }
  let old_text = match get_string_arg(args, "old_text") {
    Some(t) => t
    None => return ToolExecutionResult::error("Missing old_text argument")
  }
  let new_text = match get_string_arg(args, "new_text") {
    Some(t) => t
    None => return ToolExecutionResult::error("Missing new_text argument")
  }
  if old_text == new_text {
    return ToolExecutionResult::error(
      "old_text and new_text are identical, no edit needed",
    )
  }
  let count = get_int_arg(args, "count").unwrap_or(1)
  // プラットフォーム固有の読み書きを使用
  edit_file_platform(path, old_text, new_text, count)
}

// =============================================================================
// Pure Logic (platform-independent)
// =============================================================================

///|
/// テキスト置換を実行（純粋関数）
/// 戻り値: (置換後テキスト, 置換回数)
pub fn replace_text(
  content : String,
  old_text : String,
  new_text : String,
  max_count : Int,
) -> (String, Int) {
  if old_text.length() == 0 {
    return (content, 0)
  }
  let buf = StringBuilder::new()
  let old_len = old_text.length()
  let mut i = 0
  let mut replacements = 0
  let content_len = content.length()
  // 文字列を走査して old_text を検索・置換
  while i < content_len {
    if max_count > 0 && replacements >= max_count {
      // 残りをそのまま追加
      let iter = content.iter()
      let mut skip = 0
      for c in iter {
        if skip < i {
          skip = skip + 1
          continue
        }
        buf.write_char(c)
      }
      break
    }
    // i の位置から old_text と一致するかチェック
    if matches_at(content, i, old_text) {
      buf.write_string(new_text)
      i = i + old_len
      replacements = replacements + 1
    } else {
      // 1文字追加
      buf.write_char(char_at(content, i))
      i = i + 1
    }
  }
  // max_count に達しなかった場合、ループは自然終了
  (buf.to_string(), replacements)
}

///|
/// content の offset 位置から target と一致するかチェック
fn matches_at(content : String, offset : Int, target : String) -> Bool {
  let target_len = target.length()
  if offset + target_len > content.length() {
    return false
  }
  for i = 0; i < target_len; i = i + 1 {
    if char_at(content, offset + i) != char_at(target, i) {
      return false
    }
  }
  true
}

///|
/// 文字列の n 番目の文字を取得
fn char_at(s : String, n : Int) -> Char {
  let iter = s.iter()
  let mut idx = 0
  for c in iter {
    if idx == n {
      return c
    }
    idx = idx + 1
  }
  // ここには到達しないはず
  '\u0000'
}
