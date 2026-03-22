///|
/// gateway --config (native) テスト
///
/// IMPORTANT: Tests use OS temp dir to avoid polluting user config.

///|
/// テスト用一時ディレクトリ（ユーザー設定を汚染しない）
fn test_config_dir() -> String {
  @osenv_dirs.temp_dir() + "/mukuro-test"
}

///|
fn ensure_test_dir() -> Unit {
  ignore(
    @native.c_mkdir_bytes(
      @native.string_to_utf8_cstring(test_config_dir()),
      493,
    ),
  )
}

///|
fn write_test_config(path : String, json : String) -> Bool {
  ensure_test_dir()
  let result = @native.c_write_text_file_bytes(
    @native.string_to_utf8_cstring(path),
    @native.string_to_utf8_cstring(json),
  )
  result == 0
}

///|
fn cleanup_test_file(path : String) -> Unit {
  ignore(@native.c_remove_file_bytes(@native.string_to_utf8_cstring(path)))
}

///|
test "load_gateway_config_impl loads config file correctly" {
  let path = "\{test_config_dir()}/test-gateway-config.json"
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
    load_gateway_config_impl("\{test_config_dir()}/not-found-config.json"),
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
