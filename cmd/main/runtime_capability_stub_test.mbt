///|
/// JS/WASM runtime capability tests

///|
test "gateway start returns explicit unsupported error on js/wasm" {
  let opts : GatewayStartOptions = {
    config_path: None,
    host: None,
    port: None,
    debug: false,
    daemon: false,
  }
  let result = execute_gateway_command(GatewayCommand::Start(opts))
  assert_true(
    match result {
      CliResult::Error(msg) =>
        msg.contains("not supported yet") && msg.contains("--target native")
      _ => false
    },
  )
}
