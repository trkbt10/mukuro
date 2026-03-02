///|
/// シェルツール - Native実装（popen使用）

// =============================================================================
// Native FFI Declarations
// =============================================================================

///|
/// コマンドを実行（popen）- UTF-8 Bytes版
#borrow(command, mode)
extern "C" fn shell_popen_handle(command : Bytes, mode : Bytes) -> Int64 = "moonbit_popen_bytes"

///|
/// pclose - ハンドル版
extern "C" fn shell_pclose_handle(handle : Int64) -> Int = "moonbit_pclose_handle"

///|
/// fread - ハンドル版
#borrow(buffer)
extern "C" fn shell_fread_handle(
  buffer : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fread_handle"

// =============================================================================
// Platform Implementation
// =============================================================================

///|
fn execute_shell_platform(command : String) -> ToolExecutionResult {
  let (stdout, exit_code) = exec_popen(command)
  ToolExecutionResult::success({
    "stdout": stdout,
    "stderr": "",
    "exit_code": exit_code,
  })
}

///|
/// popenでコマンドを実行し、stdout全体を文字列として返す
fn exec_popen(command : String) -> (String, Int) {
  let cmd_bytes = @bytes.to_utf8_cstring(command)
  let mode_bytes = @bytes.to_utf8_cstring("r")
  let handle = shell_popen_handle(cmd_bytes, mode_bytes)
  if handle == 0L {
    return ("", -1)
  }
  let buffer_size = 65536
  let buffer = Bytes::new(buffer_size)
  let bytes_read = shell_fread_handle(buffer, 1, buffer_size, handle)
  let exit_raw = shell_pclose_handle(handle)
  let exit_code = (exit_raw.reinterpret_as_uint() >> 8)
    .land(0xFFU)
    .reinterpret_as_int()
  let stdout = if bytes_read > 0 {
    utf8_bytes_to_string(buffer, bytes_read)
  } else {
    ""
  }
  (stdout, exit_code)
}

///|
/// UTF-8バイト列をMoonBit文字列にデコード
fn utf8_bytes_to_string(data : Bytes, len : Int) -> String {
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
