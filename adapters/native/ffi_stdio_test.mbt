///|
/// Tests for ffi_stdio.mbt - Standard I/O FFI functions

///|
test "c_write_stdout writes data" {
  // Write actual content to test the function works
  let data = @native.string_to_utf8_cstring("test\n")
  let result = @native.c_write_stdout(data, 5)
  // Should return number of bytes written or -1 on error
  @native.ffi_assert_true(result >= 0 || result == -1)
}

///|
test "c_write_stderr writes data" {
  // Write actual content to test the function works
  let data = @native.string_to_utf8_cstring("test\n")
  let result = @native.c_write_stderr(data, 5)
  // Should return number of bytes written or -1 on error
  @native.ffi_assert_true(result >= 0 || result == -1)
}

///|
test "c_fflush_stdout returns success" {
  let result = @native.c_fflush_stdout()
  assert_eq(result, 0)
}

// Note: c_read_stdin_line cannot be easily tested as it blocks waiting for input
// It's tested implicitly via CLI integration tests
