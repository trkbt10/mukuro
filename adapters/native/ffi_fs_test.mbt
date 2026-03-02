///|
/// Tests for ffi_fs.mbt - Filesystem FFI functions

// ============================================================
// Access Tests
// ============================================================

///|
test "c_access_bytes detects existing directory" {
  let path = @native.string_to_utf8_cstring("/tmp")
  let result = @native.c_access_bytes(path, @native.f_ok)
  assert_eq(result, 0)
}

///|
test "c_access_bytes returns -1 for non-existent path" {
  let path = @native.string_to_utf8_cstring("/nonexistent_path_12345")
  let result = @native.c_access_bytes(path, @native.f_ok)
  @native.ffi_assert_true(result != 0)
}

///|
test "c_access CString version detects existing directory" {
  let path = @native.string_to_cstring("/tmp")
  let result = @native.c_access(path, @native.f_ok)
  assert_eq(result, 0)
}

// ============================================================
// Directory Tests
// ============================================================

///|
test "c_mkdir_bytes creates and removes directory" {
  let dir = "/tmp/mukuro_ffi_fs_test_\{@native.c_getpid()}"
  let path = @native.string_to_utf8_cstring(dir)
  // Create
  let mkdir_result = @native.c_mkdir_bytes(path, 493) // 0o755
  assert_eq(mkdir_result, 0)
  // Verify exists
  assert_eq(@native.c_access_bytes(path, @native.f_ok), 0)
  // Remove
  let rmdir_result = @native.c_remove_bytes(path)
  assert_eq(rmdir_result, 0)
}

///|
test "c_mkdir_recursive_bytes creates nested directories" {
  let base = "/tmp/mukuro_ffi_fs_nested_\{@native.c_getpid()}"
  let nested = "\{base}/a/b/c"
  let path = @native.string_to_utf8_cstring(nested)
  // Create recursive
  let result = @native.c_mkdir_recursive_bytes(path, 493)
  assert_eq(result, 0)
  // Verify exists
  assert_eq(@native.c_access_bytes(path, @native.f_ok), 0)
  // Cleanup
  let _ = @native.c_system_bytes(
    @native.string_to_utf8_cstring("rm -rf \{base}"),
  )
}

///|
test "c_list_dir_bytes lists directory entries" {
  let path = @native.string_to_utf8_cstring("/tmp")
  let buffer = Bytes::new(4096)
  let bytes_read = @native.c_list_dir_bytes(path, buffer, buffer.length())
  @native.ffi_assert_true(bytes_read > 0)
}

///|
test "c_list_dir CString version lists directory entries" {
  let path = @native.string_to_cstring("/tmp")
  let buffer = Bytes::new(4096)
  let bytes_read = @native.c_list_dir(path, buffer, buffer.length())
  @native.ffi_assert_true(bytes_read > 0)
}

// ============================================================
// File I/O Tests
// ============================================================

///|
test "c_write_text_file_bytes and c_read_text_file_bytes round-trip" {
  let file_path = "/tmp/mukuro_ffi_fs_text_\{@native.c_getpid()}.txt"
  let content = "Hello, UTF-8 Bytes!\n日本語テスト"
  // Write
  let write_result = @native.c_write_text_file_bytes(
    @native.string_to_utf8_cstring(file_path),
    @native.string_to_utf8_cstring(content),
  )
  assert_eq(write_result, 0)
  // Read
  let buffer = Bytes::new(1024)
  let bytes_read = @native.c_read_text_file_bytes(
    @native.string_to_utf8_cstring(file_path),
    buffer,
    buffer.length(),
  )
  @native.ffi_assert_true(bytes_read > 0)
  let read_content = @bytes.decode_utf8_or(buffer[:bytes_read], default="")
  assert_eq(read_content, content)
  // Cleanup
  let _ = @native.c_remove_file_bytes(@native.string_to_utf8_cstring(file_path))
}

///|
test "c_file_exists_bytes detects file presence" {
  let file_path = "/tmp/mukuro_ffi_fs_exists_\{@native.c_getpid()}.txt"
  let path_bytes = @native.string_to_utf8_cstring(file_path)
  // Should not exist
  assert_eq(@native.c_file_exists_bytes(path_bytes), 0)
  // Create file
  let _ = @native.c_write_text_file_bytes(
    path_bytes,
    @native.string_to_utf8_cstring("test"),
  )
  // Should exist
  assert_eq(@native.c_file_exists_bytes(path_bytes), 1)
  // Cleanup
  let _ = @native.c_remove_file_bytes(path_bytes)
}

///|
test "c_write_pid_file_bytes and c_read_pid_file_bytes round-trip" {
  let file_path = "/tmp/mukuro_ffi_fs_pid_\{@native.c_getpid()}.pid"
  let path_bytes = @native.string_to_utf8_cstring(file_path)
  let expected_pid = @native.c_getpid()
  // Write
  let write_result = @native.c_write_pid_file_bytes(path_bytes, expected_pid)
  assert_eq(write_result, 0)
  // Read
  let read_pid = @native.c_read_pid_file_bytes(path_bytes)
  assert_eq(read_pid, expected_pid)
  // Cleanup
  let _ = @native.c_remove_file_bytes(path_bytes)
}

///|
test "c_chmod_file_bytes changes file permissions" {
  let file_path = "/tmp/mukuro_ffi_fs_chmod_\{@native.c_getpid()}.txt"
  let path_bytes = @native.string_to_utf8_cstring(file_path)
  // Create file
  let _ = @native.c_write_text_file_bytes(
    path_bytes,
    @native.string_to_utf8_cstring("test"),
  )
  // Change permissions to 0o600
  let result = @native.c_chmod_file_bytes(path_bytes, 384) // 0o600
  assert_eq(result, 0)
  // Cleanup
  let _ = @native.c_remove_file_bytes(path_bytes)
}

///|
test "c_remove_file_bytes removes file" {
  let file_path = "/tmp/mukuro_ffi_fs_remove_\{@native.c_getpid()}.txt"
  let path_bytes = @native.string_to_utf8_cstring(file_path)
  // Create file
  let _ = @native.c_write_text_file_bytes(
    path_bytes,
    @native.string_to_utf8_cstring("test"),
  )
  assert_eq(@native.c_file_exists_bytes(path_bytes), 1)
  // Remove
  let result = @native.c_remove_file_bytes(path_bytes)
  assert_eq(result, 0)
  // Verify removed
  assert_eq(@native.c_file_exists_bytes(path_bytes), 0)
}

// ============================================================
// CString Version Tests (Pattern A - legacy)
// ============================================================

///|
test "c_write_text_file and c_read_text_file CString version round-trip" {
  let file_path = "/tmp/mukuro_ffi_fs_cstring_\{@native.c_getpid()}.txt"
  let content = "CString test"
  // Write
  let write_result = @native.c_write_text_file(
    @native.string_to_cstring(file_path),
    @native.string_to_cstring(content),
  )
  assert_eq(write_result, 0)
  // Read
  let buffer = Bytes::new(1024)
  let bytes_read = @native.c_read_text_file(
    @native.string_to_cstring(file_path),
    buffer,
    buffer.length(),
  )
  @native.ffi_assert_true(bytes_read > 0)
  // Cleanup
  let _ = @native.c_remove_file(@native.string_to_cstring(file_path))
}
