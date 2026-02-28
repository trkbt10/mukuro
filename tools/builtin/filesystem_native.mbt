///|
/// ファイルシステムツール - Native実装（C FFI使用）

///|
/// ファイルシステムツールを実行（Native同期版）
pub fn execute_filesystem_tool_native(args : Json) -> ToolExecutionResult {
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
    return ToolExecutionResult::error(
      "Path traversal not allowed: \{path}",
    )
  }
  let recursive = get_bool_arg(args, "recursive").unwrap_or(false)
  match action {
    "read" => fs_native_read(path)
    "write" => {
      let content = match get_string_arg(args, "content") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing content argument")
      }
      fs_native_write(path, content)
    }
    "append" => {
      let content = match get_string_arg(args, "content") {
        Some(c) => c
        None => return ToolExecutionResult::error("Missing content argument")
      }
      fs_native_append(path, content)
    }
    "delete" => fs_native_delete(path, recursive)
    "exists" => fs_native_exists(path)
    "list" => fs_native_list(path)
    "mkdir" => fs_native_mkdir(path)
    "stat" => fs_native_stat(path)
    _ => ToolExecutionResult::error("Unknown action: \{action}")
  }
}

///|
fn fs_native_read(path : String) -> ToolExecutionResult {
  let path_bytes = to_utf8_cstr(path)
  let mode_bytes = to_utf8_cstr("rb")
  let handle = native_fopen_handle(path_bytes, mode_bytes)
  if handle == 0L {
    return ToolExecutionResult::error("Cannot open file: \{path}")
  }
  let buffer_size = 65536
  let buffer = Bytes::new(buffer_size)
  let bytes_read = native_fread_handle(buffer, 1, buffer_size, handle)
  let _ = native_fclose_handle(handle)
  if bytes_read < 0 {
    return ToolExecutionResult::error("Read error: \{path}")
  }
  let content = if bytes_read > 0 {
    utf8_bytes_to_string(buffer, bytes_read)
  } else {
    ""
  }
  ToolExecutionResult::success({ "path": path, "content": content })
}

///|
fn fs_native_write(path : String, content : String) -> ToolExecutionResult {
  let path_bytes = to_utf8_cstr(path)
  let mode_bytes = to_utf8_cstr("wb")
  let handle = native_fopen_handle(path_bytes, mode_bytes)
  if handle == 0L {
    return ToolExecutionResult::error(
      "Cannot open file for writing: \{path}",
    )
  }
  let data = @utf8.encode(content)
  let written = native_fwrite_handle(data, 1, data.length(), handle)
  let _ = native_fclose_handle(handle)
  if written != data.length() {
    return ToolExecutionResult::error("Write error: \{path}")
  }
  ToolExecutionResult::success({ "path": path, "written": true })
}

///|
fn fs_native_append(path : String, content : String) -> ToolExecutionResult {
  let path_bytes = to_utf8_cstr(path)
  let mode_bytes = to_utf8_cstr("ab")
  let handle = native_fopen_handle(path_bytes, mode_bytes)
  if handle == 0L {
    return ToolExecutionResult::error(
      "Cannot open file for appending: \{path}",
    )
  }
  let data = @utf8.encode(content)
  let written = native_fwrite_handle(data, 1, data.length(), handle)
  let _ = native_fclose_handle(handle)
  if written != data.length() {
    return ToolExecutionResult::error("Append error: \{path}")
  }
  ToolExecutionResult::success({ "path": path, "appended": true })
}

///|
fn fs_native_delete(path : String, recursive : Bool) -> ToolExecutionResult {
  if recursive {
    // ディレクトリの再帰削除は rm -rf を使用
    let escaped = escape_single_quote(path)
    let (_, exit_code) = exec_popen("rm -rf '\{escaped}'")
    if exit_code != 0 {
      return ToolExecutionResult::error("Cannot delete: \{path}")
    }
  } else {
    let result = native_remove(to_cstring(path))
    if result != 0 {
      return ToolExecutionResult::error("Cannot delete file: \{path}")
    }
  }
  ToolExecutionResult::success({ "path": path, "deleted": true })
}

///|
fn fs_native_exists(path : String) -> ToolExecutionResult {
  let exists = native_access(to_cstring(path), native_f_ok) == 0
  ToolExecutionResult::success({ "path": path, "exists": exists })
}

///|
fn fs_native_list(path : String) -> ToolExecutionResult {
  let buffer = Bytes::new(8192)
  let bytes_written = native_list_dir(to_cstring(path), buffer, 8192)
  if bytes_written < 0 {
    return ToolExecutionResult::error("Cannot list directory: \{path}")
  }
  if bytes_written == 0 {
    return ToolExecutionResult::success({
      "path": path,
      "files": Json::array([]),
      "count": 0,
    })
  }
  let entries = @bytes.parse_utf16le_lines(buffer, bytes_written)
  let files : Array[Json] = []
  for entry in entries {
    files.push(Json::string(entry))
  }
  ToolExecutionResult::success({
    "path": path,
    "files": Json::array(files),
    "count": files.length(),
  })
}

///|
fn fs_native_mkdir(path : String) -> ToolExecutionResult {
  let result = native_mkdir_recursive(to_cstring(path), 493) // 0o755
  if result != 0 {
    return ToolExecutionResult::error("Cannot create directory: \{path}")
  }
  ToolExecutionResult::success({ "path": path, "created": true })
}

///|
fn fs_native_stat(path : String) -> ToolExecutionResult {
  // stat コマンドで情報取得（macOS/Linux互換）
  let escaped = escape_single_quote(path)
  let cmd = "stat -f '%z %Sm %Sa %SB %HT' -t '%Y-%m-%dT%H:%M:%S' '\{escaped}' 2>/dev/null || stat --format='%s %y %x %w %F' '\{escaped}' 2>/dev/null"
  let (stdout, exit_code) = exec_popen(cmd)
  if exit_code != 0 {
    return ToolExecutionResult::error("Cannot stat: \{path}")
  }
  // 基本的な情報をパース（フォーマットはOS依存）
  let trimmed = stdout.trim(chars=" \t\r\n")
  // ファイル存在確認とタイプ判定
  let is_dir_cmd = "test -d '\{escaped}' && echo dir || echo file"
  let (type_out, _) = exec_popen(is_dir_cmd)
  let file_type = type_out.trim(chars=" \t\r\n")
  ToolExecutionResult::success({
    "path": path,
    "isFile": file_type == "file",
    "isDirectory": file_type == "dir",
    "raw": trimmed,
  })
}
