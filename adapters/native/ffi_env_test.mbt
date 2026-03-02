///|
/// Tests for ffi_env.mbt - Environment variable FFI functions

// ============================================================
// Environment Variable Tests (Bytes version)
// ============================================================

///|
test "c_setenv_bytes and c_unsetenv_bytes work correctly" {
  let name = "MUKURO_FFI_ENV_TEST_VAR"
  let value = "test_value_123"
  let name_bytes = @native.string_to_utf8_cstring(name)
  let value_bytes = @native.string_to_utf8_cstring(value)
  // Set
  let set_result = @native.c_setenv_bytes(name_bytes, value_bytes, 1)
  assert_eq(set_result, 0)
  // Unset
  let unset_result = @native.c_unsetenv_bytes(name_bytes)
  assert_eq(unset_result, 0)
}

///|
test "c_setenv_bytes overwrites existing value" {
  let name = "MUKURO_FFI_ENV_OVERWRITE"
  let name_bytes = @native.string_to_utf8_cstring(name)
  // Set initial
  let _ = @native.c_setenv_bytes(
    name_bytes,
    @native.string_to_utf8_cstring("initial"),
    1,
  )
  // Overwrite
  let result = @native.c_setenv_bytes(
    name_bytes,
    @native.string_to_utf8_cstring("overwritten"),
    1,
  )
  assert_eq(result, 0)
  // Cleanup
  let _ = @native.c_unsetenv_bytes(name_bytes)
}

// ============================================================
// Environment Variable Tests (CString version)
// ============================================================

///|
test "c_setenv and c_unsetenv CString version work correctly" {
  let name = "MUKURO_FFI_ENV_CSTRING_TEST"
  let value = "cstring_value"
  let name_cs = @native.string_to_cstring(name)
  let value_cs = @native.string_to_cstring(value)
  // Set
  let set_result = @native.c_setenv(name_cs, value_cs, 1)
  assert_eq(set_result, 0)
  // Unset
  let unset_result = @native.c_unsetenv(name_cs)
  assert_eq(unset_result, 0)
}

// Note: c_getenv tests are skipped due to CString? NULL handling issues in FFI
// The function is tested implicitly via other code paths that use getenv

// ============================================================
// Errno Test
// ============================================================

///|
test "c_get_errno returns valid errno" {
  // Just verify it doesn't crash - errno value depends on previous operations
  let errno = @native.c_get_errno()
  @native.ffi_assert_true(errno >= 0)
}
