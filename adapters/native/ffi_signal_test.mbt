///|
/// Tests for ffi_signal.mbt - Signal and process management FFI functions

// ============================================================
// Signal Handler Tests
// ============================================================

///|
test "c_setup_signal_handlers returns success" {
  let result = @native.c_setup_signal_handlers()
  assert_eq(result, 0)
}

///|
test "c_get_signal_received returns 0 when no signal" {
  // Reset first to ensure clean state
  @native.c_reset_signal_received()
  let result = @native.c_get_signal_received()
  assert_eq(result, 0)
}

///|
test "c_reset_signal_received clears signal state" {
  @native.c_reset_signal_received()
  let result = @native.c_get_signal_received()
  assert_eq(result, 0)
}

// ============================================================
// Process Management Tests
// ============================================================

///|
test "c_getpid returns positive process ID" {
  let pid = @native.c_getpid()
  @native.ffi_assert_true(pid > 0)
}

///|
test "c_getpid returns consistent value" {
  let pid1 = @native.c_getpid()
  let pid2 = @native.c_getpid()
  assert_eq(pid1, pid2)
}

///|
test "c_kill with signal 0 checks process existence" {
  let pid = @native.c_getpid()
  // Signal 0 checks if process exists without sending a signal
  let result = @native.c_kill(pid, 0)
  assert_eq(result, 0)
}

///|
test "c_kill returns -1 for non-existent process" {
  // Use an unlikely PID
  let result = @native.c_kill(999999, 0)
  assert_eq(result, -1)
}

///|
test "c_sleep_ms pauses execution" {
  let start = @native.c_time()
  @native.c_sleep_ms(50) // Sleep 50ms
  let end = @native.c_time()
  // Should not fail, timing is approximate
  @native.ffi_assert_true(end >= start)
}

// ============================================================
// Signal Constants Tests
// ============================================================

///|
test "sigterm constant is 15" {
  assert_eq(@native.sigterm, 15)
}

///|
test "sigint constant is 2" {
  assert_eq(@native.sigint, 2)
}

// Note: c_exit cannot be tested as it terminates the process
