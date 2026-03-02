///|
/// ファイルシステムツール - ファイル操作
/// 定義と実装を統合

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn filesystem_tool() -> @types.ToolDefinition {
  make_tool_definition(
    name="filesystem",
    description="Read, write, and manage files",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([
            Json::string("read"),
            Json::string("write"),
            Json::string("append"),
            Json::string("delete"),
            Json::string("exists"),
            Json::string("list"),
            Json::string("mkdir"),
            Json::string("stat"),
          ]),
          "description": "File operation to perform",
        },
        "path": string_param("File or directory path"),
        "content": string_param("Content to write (for write/append)"),
        "encoding": string_param("File encoding (default: utf8)"),
        "recursive": boolean_param("Recursive operation (for mkdir/delete)"),
      },
      ["action", "path"],
    ),
  )
}

// =============================================================================
// Tool Implementation Entry Point
// =============================================================================

///|
/// ファイルシステムツールを実行
pub fn execute_filesystem(args : Json) -> ToolExecutionResult {
  let action = match get_string_arg(args, "action") {
    Some(a) => a
    None => return ToolExecutionResult::error("Missing action argument")
  }
  let path = match get_string_arg(args, "path") {
    Some(p) => p
    None => return ToolExecutionResult::error("Missing path argument")
  }
  // パストラバーサル防止
  if path.contains("..") {
    return ToolExecutionResult::error("Path traversal not allowed: \{path}")
  }
  let recursive = get_bool_arg(args, "recursive").unwrap_or(false)
  match action {
    "read" => fs_read(path)
    "write" => {
      let content = match get_string_arg(args, "content") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing content argument")
      }
      fs_write(path, content)
    }
    "append" => {
      let content = match get_string_arg(args, "content") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing content argument")
      }
      fs_append(path, content)
    }
    "delete" => fs_delete(path, recursive)
    "exists" => fs_exists(path)
    "list" => fs_list(path)
    "mkdir" => fs_mkdir(path)
    "stat" => fs_stat(path)
    _ => ToolExecutionResult::error("Unknown action: \{action}")
  }
}
