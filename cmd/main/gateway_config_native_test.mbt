///|
/// gateway --config (native) テスト
///
/// NOTE: execute_gateway_start() calls run_control_api_server_with_tick_blocking()
/// which blocks forever. Unit tests should NOT call execute_gateway_start().
///
/// For config loading, use load_gateway_config_impl() directly.
/// For Gateway initialization, use global_gateway.start() directly.
///
/// IMPORTANT: Tests use /tmp/mukuro-test/ to avoid polluting user config.

///|
/// テスト用一時ディレクトリ（ユーザー設定を汚染しない）
let test_config_dir : String = "/tmp/mukuro-test"

///|
fn ensure_test_dir() -> Unit {
  ignore(@native.c_mkdir(@native.string_to_cstring(test_config_dir), 493))
}

///|
fn write_test_config(path : String, json : String) -> Bool {
  ensure_test_dir()
  let result = @native.c_write_text_file(
    @native.string_to_cstring(path),
    @native.string_to_cstring(json),
  )
  result == 0
}

///|
fn cleanup_test_file(path : String) -> Unit {
  ignore(@native.c_remove_file(@native.string_to_cstring(path)))
}

///|
test "load_gateway_config_impl loads config file correctly" {
  let path = "\{test_config_dir}/test-gateway-config.json"
  let json = "{\n  \"gateway\": {\n    \"host\": \"0.0.0.0\",\n    \"port\": 9123,\n    \"auth_token\": \"test-token\",\n    \"auto_connect_channels\": false\n  }\n}"
  assert_true(write_test_config(path, json))
  let config = load_gateway_config_impl(path) catch {
    _ => {
      cleanup_test_file(path)
      fail("Expected config to load successfully")
    }
  }
  assert_eq(config.host, "0.0.0.0")
  assert_eq(config.port, 9123)
  cleanup_test_file(path)
}

///|
test "load_gateway_config_impl returns error for missing config file" {
  let result : Result[@interfaces.GatewayConfig, @interfaces.ControlError] = Ok(
    load_gateway_config_impl("\{test_config_dir}/not-found-config.json"),
  ) catch {
    e => Err(e)
  }
  assert_true(
    match result {
      Err(@interfaces.ControlError::ConfigError(msg)) =>
        msg.contains("not found")
      _ => false
    },
  )
}
