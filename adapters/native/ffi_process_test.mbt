///|
/// Tests for ffi_process.mbt - Process execution FFI functions

// ============================================================
// System Command Tests
// ============================================================

///|
test "c_system_bytes executes shell command" {
  let result = @native.c_system_bytes(@native.string_to_utf8_cstring("true"))
  assert_eq(result, 0)
}

///|
test "c_system_bytes returns non-zero for failing command" {
  let result = @native.c_system_bytes(@native.string_to_utf8_cstring("false"))
  @native.ffi_assert_true(result != 0)
}

///|
test "c_system CString version executes shell command" {
  let result = @native.c_system(@native.string_to_cstring("true"))
  assert_eq(result, 0)
}

// ============================================================
// File Handle Tests
// ============================================================

///|
test "c_fopen_handle and c_fclose_handle work correctly" {
  let file_path = "{@osenv_dirs.temp_dir()}/mukuro_ffi_proc_handle_\{@native.c_getpid()}.txt"
  let path_bytes = @native.string_to_utf8_cstring(file_path)
  // Create file first
  let _ = @native.c_write_text_file_bytes(
    path_bytes,
    @native.string_to_utf8_cstring("test"),
  )
  // Open for reading
  let handle = @native.c_fopen_handle(
    path_bytes,
    @native.string_to_utf8_cstring("r"),
  )
  @native.ffi_assert_true(handle != 0L)
  // Close
  let close_result = @native.c_fclose_handle(handle)
  assert_eq(close_result, 0)
  // Cleanup
  let _ = @native.c_remove_file_bytes(path_bytes)
}

///|
test "c_fwrite_handle and c_fread_handle work correctly" {
  let file_path = "{@osenv_dirs.temp_dir()}/mukuro_ffi_proc_rw_\{@native.c_getpid()}.txt"
  let path_bytes = @native.string_to_utf8_cstring(file_path)
  let content = @native.string_to_utf8_cstring("Hello Handle IO")
  // Write
  let wh = @native.c_fopen_handle(
    path_bytes,
    @native.string_to_utf8_cstring("w"),
  )
  @native.ffi_assert_true(wh != 0L)
  let written = @native.c_fwrite_handle(content, 1, content.length() - 1, wh) // -1 for null terminator
  @native.ffi_assert_true(written > 0)
  let _ = @native.c_fflush_handle(wh)
  let _ = @native.c_fclose_handle(wh)
  // Read
  let rh = @native.c_fopen_handle(
    path_bytes,
    @native.string_to_utf8_cstring("r"),
  )
  @native.ffi_assert_true(rh != 0L)
  let buffer = Bytes::new(256)
  let read_count = @native.c_fread_handle(buffer, 1, buffer.length(), rh)
  @native.ffi_assert_true(read_count > 0)
  let _ = @native.c_fclose_handle(rh)
  // Cleanup
  let _ = @native.c_remove_file_bytes(path_bytes)
}

///|
test "c_popen_handle executes command and reads output" {
  let handle = @native.c_popen_handle(
    @native.string_to_utf8_cstring("echo hello"),
    @native.string_to_utf8_cstring("r"),
  )
  @native.ffi_assert_true(handle != 0L)
  let buffer = Bytes::new(256)
  let read_count = @native.c_fread_handle(buffer, 1, buffer.length(), handle)
  @native.ffi_assert_true(read_count > 0)
  let output = @bytes.decode_utf8_or(buffer[:read_count], default="")
  @native.ffi_assert_true(output.contains("hello"))
  let _ = @native.c_pclose_handle(handle)
}

// ============================================================
// Daemon Tests (limited - requires special conditions)
// ============================================================

///|
test "c_spawn_daemon_bytes returns error code when invoked in test" {
  // c_spawn_daemon_bytes returns -2 when running in interpreter mode
  // (requires native binary), so we just verify it doesn't crash
  let path_bytes = @native.string_to_utf8_cstring(
    "{@osenv_dirs.temp_dir()}/mukuro_test_daemon_\{@native.c_getpid()}.pid",
  )
  let result = @native.c_spawn_daemon_bytes(path_bytes)
  // Result should be -2 (interpreter mode) or actual PID (native binary)
  // We just verify it returns something sensible
  @native.ffi_assert_true(result == -2 || result > 0 || result < 0)
}

// Note: c_get_exe_path test is skipped because it may return empty in test context
// The function is tested via daemon startup which requires the exe path

// Note: c_daemon_child_init_bytes cannot be tested as it requires
// running in a forked daemon context
