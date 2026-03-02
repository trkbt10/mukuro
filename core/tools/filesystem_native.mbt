///|
/// ファイルシステムツール - Native実装（C FFI使用）

// =============================================================================
// Native FFI Declarations
// =============================================================================

///|
#external
priv type FsCString

///|
fn to_fs_cstring(s : String) -> FsCString = "%identity"

///|
#borrow(path, mode)
extern "C" fn fs_fopen_handle(path : Bytes, mode : Bytes) -> Int64 = "moonbit_fopen_bytes"

///|
#borrow(data)
extern "C" fn fs_fwrite_handle(
  data : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fwrite_handle"

///|
#borrow(buffer)
extern "C" fn fs_fread_handle(
  buffer : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fread_handle"

///|
extern "C" fn fs_fclose_handle(handle : Int64) -> Int = "moonbit_fclose_handle"

///|
#borrow(path)
extern "C" fn fs_access(path : FsCString, mode : Int) -> Int = "moonbit_access"

///|
#borrow(path)
extern "C" fn fs_remove(path : FsCString) -> Int = "moonbit_remove"

///|
#borrow(path, buffer)
extern "C" fn fs_list_dir(
  path : FsCString,
  buffer : Bytes,
  buffer_len : Int,
) -> Int = "moonbit_list_dir"

///|
#borrow(path)
extern "C" fn fs_mkdir_recursive(path : FsCString, mode : Int) -> Int = "moonbit_mkdir_recursive"

///|
#borrow(command, mode)
extern "C" fn fs_popen_handle(command : Bytes, mode : Bytes) -> Int64 = "moonbit_popen_bytes"

///|
extern "C" fn fs_pclose_handle(handle : Int64) -> Int = "moonbit_pclose_handle"

///|
let fs_f_ok : Int = 0

// =============================================================================
// Helpers
// =============================================================================

///|
fn to_utf8_cstr(s : String) -> Bytes {
  @bytes.to_utf8_cstring(s)
}

///|
fn fs_utf8_to_string(data : Bytes, len : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    let b0 = data[i].to_int()
    if b0 < 0x80 {
      buf.write_char(Int::unsafe_to_char(b0))
      i = i + 1
    } else if b0 < 0xE0 {
      if i + 1 >= len {
        break
      }
      let b1 = data[i + 1].to_int()
      let cp = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i = i + 2
    } else if b0 < 0xF0 {
      if i + 2 >= len {
        break
      }
      let b1 = data[i + 1].to_int()
      let b2 = data[i + 2].to_int()
      let cp = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i = i + 3
    } else {
      if i + 3 >= len {
        break
      }
      let b1 = data[i + 1].to_int()
      let b2 = data[i + 2].to_int()
      let b3 = data[i + 3].to_int()
      let cp = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i = i + 4
    }
  }
  buf.to_string()
}

///|
fn fs_exec_popen(command : String) -> (String, Int) {
  let cmd_bytes = to_utf8_cstr(command)
  let mode_bytes = to_utf8_cstr("r")
  let handle = fs_popen_handle(cmd_bytes, mode_bytes)
  if handle == 0L {
    return ("", -1)
  }
  let buffer_size = 65536
  let buffer = Bytes::new(buffer_size)
  let bytes_read = fs_fread_handle(buffer, 1, buffer_size, handle)
  let exit_raw = fs_pclose_handle(handle)
  let exit_code = (exit_raw.reinterpret_as_uint() >> 8)
    .land(0xFFU)
    .reinterpret_as_int()
  let stdout = if bytes_read > 0 {
    fs_utf8_to_string(buffer, bytes_read)
  } else {
    ""
  }
  (stdout, exit_code)
}

///|
fn fs_escape_single_quote(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if c == '\'' {
      buf.write_string("'\\''")
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

// =============================================================================
// Platform Implementations
// =============================================================================

///|
fn fs_read(path : String) -> ToolExecutionResult {
  let path_bytes = to_utf8_cstr(path)
  let mode_bytes = to_utf8_cstr("rb")
  let handle = fs_fopen_handle(path_bytes, mode_bytes)
  if handle == 0L {
    return ToolExecutionResult::error("Cannot open file: \{path}")
  }
  let buffer_size = 65536
  let buffer = Bytes::new(buffer_size)
  let bytes_read = fs_fread_handle(buffer, 1, buffer_size, handle)
  let _ = fs_fclose_handle(handle)
  if bytes_read < 0 {
    return ToolExecutionResult::error("Read error: \{path}")
  }
  let content = if bytes_read > 0 {
    fs_utf8_to_string(buffer, bytes_read)
  } else {
    ""
  }
  ToolExecutionResult::success({ "path": path, "content": content })
}

///|
fn fs_write(path : String, content : String) -> ToolExecutionResult {
  let path_bytes = to_utf8_cstr(path)
  let mode_bytes = to_utf8_cstr("wb")
  let handle = fs_fopen_handle(path_bytes, mode_bytes)
  if handle == 0L {
    return ToolExecutionResult::error("Cannot open file for writing: \{path}")
  }
  let data = @utf8.encode(content)
  let written = fs_fwrite_handle(data, 1, data.length(), handle)
  let _ = fs_fclose_handle(handle)
  if written != data.length() {
    return ToolExecutionResult::error("Write error: \{path}")
  }
  ToolExecutionResult::success({ "path": path, "written": true })
}

///|
fn fs_append(path : String, content : String) -> ToolExecutionResult {
  let path_bytes = to_utf8_cstr(path)
  let mode_bytes = to_utf8_cstr("ab")
  let handle = fs_fopen_handle(path_bytes, mode_bytes)
  if handle == 0L {
    return ToolExecutionResult::error("Cannot open file for appending: \{path}")
  }
  let data = @utf8.encode(content)
  let written = fs_fwrite_handle(data, 1, data.length(), handle)
  let _ = fs_fclose_handle(handle)
  if written != data.length() {
    return ToolExecutionResult::error("Append error: \{path}")
  }
  ToolExecutionResult::success({ "path": path, "appended": true })
}

///|
fn fs_delete(path : String, recursive : Bool) -> ToolExecutionResult {
  if recursive {
    // ディレクトリの再帰削除は rm -rf を使用
    let escaped = fs_escape_single_quote(path)
    let (_, exit_code) = fs_exec_popen("rm -rf '\{escaped}'")
    if exit_code != 0 {
      return ToolExecutionResult::error("Cannot delete: \{path}")
    }
  } else {
    let result = fs_remove(to_fs_cstring(path))
    if result != 0 {
      return ToolExecutionResult::error("Cannot delete file: \{path}")
    }
  }
  ToolExecutionResult::success({ "path": path, "deleted": true })
}

///|
fn fs_exists(path : String) -> ToolExecutionResult {
  let exists = fs_access(to_fs_cstring(path), fs_f_ok) == 0
  ToolExecutionResult::success({ "path": path, "exists": exists })
}

///|
fn fs_list(path : String) -> ToolExecutionResult {
  let buffer = Bytes::new(8192)
  let bytes_written = fs_list_dir(to_fs_cstring(path), buffer, 8192)
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
fn fs_mkdir(path : String) -> ToolExecutionResult {
  let result = fs_mkdir_recursive(to_fs_cstring(path), 493) // 0o755
  if result != 0 {
    return ToolExecutionResult::error("Cannot create directory: \{path}")
  }
  ToolExecutionResult::success({ "path": path, "created": true })
}

///|
fn fs_stat(path : String) -> ToolExecutionResult {
  // stat コマンドで情報取得（macOS/Linux互換）
  let escaped = fs_escape_single_quote(path)
  let cmd = "stat -f '%z %Sm %Sa %SB %HT' -t '%Y-%m-%dT%H:%M:%S' '\{escaped}' 2>/dev/null || stat --format='%s %y %x %w %F' '\{escaped}' 2>/dev/null"
  let (stdout, exit_code) = fs_exec_popen(cmd)
  if exit_code != 0 {
    return ToolExecutionResult::error("Cannot stat: \{path}")
  }
  // 基本的な情報をパース（フォーマットはOS依存）
  let trimmed = stdout.trim(chars=" \t\r\n")
  // ファイル存在確認とタイプ判定
  let is_dir_cmd = "test -d '\{escaped}' && echo dir || echo file"
  let (type_out, _) = fs_exec_popen(is_dir_cmd)
  let file_type = type_out.trim(chars=" \t\r\n")
  ToolExecutionResult::success({
    "path": path,
    "isFile": file_type == "file",
    "isDirectory": file_type == "dir",
    "raw": trimmed,
  })
}
