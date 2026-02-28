///|
/// ファイルシステムツール定義（全ターゲット共通）

///|
/// ファイルシステムツール定義
pub fn filesystem_tool_definition() -> @types.ToolDefinition {
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
        "path": string_param("File or directory path", true),
        "content": string_param("Content to write (for write/append)", false),
        "encoding": string_param("File encoding (default: utf8)", false),
        "recursive": boolean_param("Recursive operation (for mkdir/delete)"),
      },
      ["action", "path"],
    ),
  )
}
