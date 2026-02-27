///|
/// gateway --config (native) テスト
///
/// NOTE: These tests are DISABLED because execute_gateway_start() calls
/// run_control_api_server_with_tick_blocking() which blocks forever.
/// Gateway start testing requires either:
/// 1. Daemon mode (background process)
/// 2. Non-blocking architecture for in-process mode
/// 3. Integration tests with process management
///
/// The config loading itself is tested via load_gateway_config_impl() directly.

///|
fn write_test_config(path : String, json : String) -> Bool {
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
  let path = ".mukuro/test-gateway-config.json"
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
    load_gateway_config_impl(".mukuro/not-found-config.json"),
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
