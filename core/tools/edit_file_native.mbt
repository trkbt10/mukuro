///|
/// edit_file ツール - Native実装

///|
fn edit_file_platform(
  path : String,
  old_text : String,
  new_text : String,
  count : Int,
) -> ToolExecutionResult {
  // ファイル読み込み
  let read_result = fs_read(path)
  if read_result.status == ToolResultStatus::Error {
    return read_result
  }
  let content = match read_result.data {
    { "content": String(c), .. } => c
    _ => return ToolExecutionResult::error("Failed to read file content")
  }
  // 置換実行
  let (new_content, replacements) = replace_text(
    content, old_text, new_text, count,
  )
  if replacements == 0 {
    return ToolExecutionResult::error("old_text not found in file: \{path}")
  }
  // ファイル書き込み
  let write_result = fs_write(path, new_content)
  if write_result.status == ToolResultStatus::Error {
    return write_result
  }
  ToolExecutionResult::success({
    "path": path,
    "replacements": replacements,
    "edited": true,
  })
}
