///|
/// Debug test for popen using UTF-8 bytes and handle-based API

///|
fn bytes_to_string(buffer : Bytes, len : Int) -> String {
  let slice = Bytes::from_iter(buffer[:len].iter())
  @utf8.decode(slice) catch {
    _ => "<decode error>"
  }
}

///|
test "debug: simple echo command" {
  let cmd = string_to_utf8_cstring("echo hello")
  let mode = string_to_utf8_cstring("r")
  let handle = c_popen_handle(cmd, mode)
  assert_true(handle != 0L)
  let buffer = Bytes::new(1024)
  let bytes_read = c_fread_handle(buffer, 1, 1024, handle)
  let _ = c_pclose_handle(handle)
  assert_true(bytes_read > 0)
  let output = bytes_to_string(buffer, bytes_read)
  assert_true(output.contains("hello"))
}

///|
test "debug: echo with pipe" {
  let cmd = string_to_utf8_cstring("echo 'test' | cat")
  let mode = string_to_utf8_cstring("r")
  let handle = c_popen_handle(cmd, mode)
  assert_true(handle != 0L)
  let buffer = Bytes::new(1024)
  let bytes_read = c_fread_handle(buffer, 1, 1024, handle)
  let _ = c_pclose_handle(handle)
  assert_true(bytes_read > 0)
  let output = bytes_to_string(buffer, bytes_read)
  assert_true(output.contains("test"))
}

///|
test "debug: node command" {
  let cmd = string_to_utf8_cstring("node -e \"console.log('hello')\"")
  let mode = string_to_utf8_cstring("r")
  let handle = c_popen_handle(cmd, mode)
  assert_true(handle != 0L)
  let buffer = Bytes::new(1024)
  let bytes_read = c_fread_handle(buffer, 1, 1024, handle)
  let _ = c_pclose_handle(handle)
  assert_true(bytes_read > 0)
  let output = bytes_to_string(buffer, bytes_read)
  assert_true(output.contains("hello"))
}
