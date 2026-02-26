///|
/// gateway --config (native) テスト

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
async test "gateway start loads config file on native" {
  ignore(execute_gateway_command(GatewayCommand::Stop))
  let path = ".mukuro/test-gateway-config.json"
  let json = "{\n  \"gateway\": {\n    \"host\": \"0.0.0.0\",\n    \"port\": 9123,\n    \"auth_token\": \"test-token\",\n    \"auto_connect_channels\": false\n  }\n}"
  assert_true(write_test_config(path, json))

  let opts : GatewayStartOptions = {
    config_path: Some(path),
    host: None,
    port: None,
    debug: false,
    daemon: false,
    control_api: false,
  }
  let result = execute_gateway_command(GatewayCommand::Start(opts))
  assert_true(
    match result {
      CliResult::Ok(msg) =>
        msg.contains("Host: 0.0.0.0") && msg.contains("Port: 9123")
      _ => false
    },
  )

  ignore(execute_gateway_command(GatewayCommand::Stop))
  cleanup_test_file(path)
}

///|
async test "gateway start returns error for missing config file on native" {
  let opts : GatewayStartOptions = {
    config_path: Some(".mukuro/not-found-config.json"),
    host: None,
    port: None,
    debug: false,
    daemon: false,
    control_api: false,
  }
  let result = execute_gateway_command(GatewayCommand::Start(opts))
  assert_true(
    match result {
      CliResult::Error(msg) =>
        msg.contains("config error") && msg.contains("not found")
      _ => false
    },
  )
}
