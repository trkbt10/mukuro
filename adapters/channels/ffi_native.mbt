///|
/// チャネル共有 FFI — popen/fread/pclose
/// telegram_native.mbt, discord_native.mbt 等で共有

///|
#borrow(command, mode)
extern "C" fn channel_popen_handle(command : Bytes, mode : Bytes) -> Int64 = "moonbit_popen_bytes"

///|
extern "C" fn channel_pclose_handle(handle : Int64) -> Int = "moonbit_pclose_handle"

///|
#borrow(buffer)
extern "C" fn channel_fread_handle(
  buffer : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fread_handle"

///|
/// curl でコマンドを実行し stdout と exit code を返す
fn channel_exec_curl(cmd : String) -> (String, Int) {
  let cmd_bytes = @bytes.to_utf8_cstring(cmd)
  let mode_bytes = @bytes.to_utf8_cstring("r")
  let handle = channel_popen_handle(cmd_bytes, mode_bytes)
  if handle == 0L {
    return ("", -1)
  }
  let buffer_size = 65536
  let buffer = Bytes::new(buffer_size)
  let bytes_read = channel_fread_handle(buffer, 1, buffer_size, handle)
  let exit_raw = channel_pclose_handle(handle)
  let exit_code = (exit_raw.reinterpret_as_uint() >> 8)
    .land(0xFFU)
    .reinterpret_as_int()
  let stdout = if bytes_read > 0 {
    match @bytes.decode_utf8(buffer[:bytes_read]) {
      Some(s) => s
      None => ""
    }
  } else {
    ""
  }
  (stdout, exit_code)
}
