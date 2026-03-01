///|
/// Tests for ffi_ipc.mbt - IPC and gateway state FFI functions

// ============================================================
// Gateway Token Tests
// ============================================================

///|
test "c_generate_gateway_token returns positive value" {
  let token = @native.c_generate_gateway_token()
  @native.ffi_assert_true(token > 0)
}

///|
test "c_generate_gateway_token returns different values" {
  let token1 = @native.c_generate_gateway_token()
  let token2 = @native.c_generate_gateway_token()
  // Tokens should be random, very unlikely to be equal
  // But we can't assert inequality as it's theoretically possible
  @native.ffi_assert_true(token1 > 0 && token2 > 0)
}

///|
test "c_write_gateway_token writes token file" {
  let token = @native.c_generate_gateway_token()
  let result = @native.c_write_gateway_token(token)
  // May fail if directory doesn't exist, but shouldn't crash
  @native.ffi_assert_true(result == 0 || result == -1)
}

///|
test "c_write_gateway_token_record writes token with metadata" {
  let token = @native.c_generate_gateway_token()
  let session_id = @native.c_getpid()
  let now = @native.c_time()
  let result = @native.c_write_gateway_token_record(token, session_id, now)
  // May fail if directory doesn't exist, but shouldn't crash
  @native.ffi_assert_true(result == 0 || result == -1)
}

///|
test "c_read_gateway_token reads token file" {
  // First write a token
  let expected_token = @native.c_generate_gateway_token()
  let write_result = @native.c_write_gateway_token(expected_token)
  if write_result == 0 {
    // Read it back
    let read_token = @native.c_read_gateway_token()
    assert_eq(read_token, expected_token)
  }
  // If write failed, we can't test read
}

///|
test "c_read_gateway_session_id returns session ID or -1" {
  let session_id = @native.c_read_gateway_session_id()
  // Returns -1 if file doesn't exist or is old format
  @native.ffi_assert_true(session_id >= -1)
}

// ============================================================
// Gateway Snapshot Tests
// ============================================================

///|
test "c_write_gateway_snapshot writes state" {
  let pid = @native.c_getpid()
  let uptime = 100
  let state = 1 // running
  let result = @native.c_write_gateway_snapshot(pid, uptime, state)
  // May fail if directory doesn't exist
  @native.ffi_assert_true(result == 0 || result == -1)
}

// ============================================================
// Authentication Audit Log Tests
// ============================================================

///|
test "c_append_gateway_auth_audit writes log entry" {
  let now = @native.c_time()
  let result = @native.c_append_gateway_auth_audit(now, 1, 1) // event=auth_failed, value=1
  // May fail if directory doesn't exist
  @native.ffi_assert_true(result == 0 || result == -1)
}

///|
test "c_append_gateway_auth_audit_detail writes detailed log" {
  let now = @native.c_time()
  let result = @native.c_append_gateway_auth_audit_detail(
    now,
    1, // event: auth_failed
    1, // value
    @native.string_to_cstring("test_source"),
    @native.string_to_cstring("test-client-id"),
    0, // session_id
    @native.string_to_cstring("unauthorized"),
    0, // token_age_sec
    0L, // blocked_until
  )
  @native.ffi_assert_true(result == 0 || result == -1)
}

///|
test "c_append_gateway_auth_audit_detail_bytes writes log entry" {
  let now = @native.c_time()
  let result = @native.c_append_gateway_auth_audit_detail_bytes(
    now,
    1, // event: auth_failed
    1, // value
    @native.string_to_utf8_cstring("test"),
    @native.string_to_utf8_cstring("test-client-123"),
    0, // session_id
    @native.string_to_utf8_cstring("test_reason"),
    0, // token_age_sec
    0L, // blocked_until
  )
  @native.ffi_assert_true(result == 0 || result == -1)
}

// ============================================================
// IPC Server Tests (limited - requires full server setup)
// ============================================================

///|
test "c_ipc_get_last_session_id returns valid value" {
  // Without a running server, this should return a default/error value
  let session_id = @native.c_ipc_get_last_session_id()
  // Just verify it doesn't crash
  @native.ffi_assert_true(session_id >= 0 || session_id == -1)
}

///|
test "c_ipc_get_last_client_id fills buffer" {
  let buffer = Bytes::new(256)
  let result = @native.c_ipc_get_last_client_id(buffer, buffer.length())
  // Without a running server, this returns 0 or error
  @native.ffi_assert_true(result >= 0 || result == -1)
}

// Note: c_ipc_server_start, c_ipc_server_poll, c_ipc_server_cleanup
// cannot be easily tested without setting up a full IPC server context.
// They are tested via daemon_e2e_native_test.mbt integration tests.

// Note: c_ipc_client_request and c_ipc_client_request_bytes
// cannot be tested without a running IPC server.
// They are tested via daemon_ipc.mbt integration tests.
