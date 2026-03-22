///|
/// ファイルシステムツール - ファイル操作
/// 定義と実装を統合

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn filesystem_tool() -> @llm_types.ToolDefinition {
  make_tool_definition(
    name="filesystem",
    description="Read, write, and manage files and directories. Use for: reading file contents, creating/editing files, checking file existence, listing directory contents, creating directories, and getting file metadata. Safer than shell for file operations.",
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
          "description": "Operation: 'read' file content, 'write' new file, 'append' to file, 'delete' file/dir, 'exists' check, 'list' directory, 'mkdir' create dir, 'stat' get metadata",
        },
        "path": string_param(
          "Absolute or relative file/directory path. Path traversal (..) is blocked for security.",
        ),
        "content": string_param("Text content for write/append actions"),
        "encoding": string_param("File encoding (default: utf8)"),
        "recursive": boolean_param(
          "For mkdir: create parent dirs. For delete: remove non-empty dirs.",
        ),
      },
      ["action", "path"],
    ),
  )
}

///|
/// Filesystem tool settings schema for UI
pub fn filesystem_settings_schema() -> Json {
  build_settings_schema(
    title="Filesystem Settings",
    description="Configure file system access behavior",
    fields=[
      text_field(
        key="base_path",
        label="Base Path",
        description="Restrict file operations to this directory (leave empty for no restriction)",
      ),
      number_field(
        key="max_file_size",
        label="Max File Size (bytes)",
        description="Maximum file size that can be read or written",
        default_value=10485760.0, // 10MB
        min=Some(1024.0),
        max=Some(104857600.0), // 100MB
      ),
      toggle_field(
        key="follow_symlinks",
        label="Follow Symlinks",
        description="Allow following symbolic links",
        default_value=true,
      ),
    ],
  )
}

// =============================================================================
// Tool Implementation Entry Point
// =============================================================================

///|
/// Filesystemツールエントリ
pub fn filesystem_entry() -> ToolEntry {
  {
    name: "filesystem",
    definition: filesystem_tool(),
    settings_schema: Some(filesystem_settings_schema()),
    execute: fn(ctx, args) {
      execute_filesystem(args, workspace_dir=ctx.workspace_dir)
    },
  }
}

///|
/// ファイルシステムツールを実行
fn execute_filesystem(
  args : Json,
  workspace_dir? : String? = None,
) -> ToolExecutionResult {
  let action = match get_string_arg(args, "action") {
    Some(a) => a
    None => return ToolExecutionResult::error("Missing action argument")
  }
  let path = match get_string_arg(args, "path") {
    Some(p) => p
    None => return ToolExecutionResult::error("Missing path argument")
  }
  // パストラバーサル + ワークスペース境界チェック
  match validate_workspace_path(path, workspace_dir) {
    Some(err) => return ToolExecutionResult::error(err)
    None => ()
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
