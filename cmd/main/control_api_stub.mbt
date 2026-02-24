///|
/// Control API (JS/WASM stub)

///|
pub fn run_control_api_server_blocking(
  _gateway : @control.Gateway,
  _host : String,
  _port : Int,
) -> Unit raise {
  abort("Control API server is available only on native target")
}

///|
pub fn run_control_api_server_with_tick_blocking(
  _gateway : @control.Gateway,
  _host : String,
  _port : Int,
  _on_tick : () -> Bool,
) -> Unit raise {
  abort("Control API server is available only on native target")
}

///|
pub fn control_api_healthcheck_message() -> String {
  "control-api-stub"
}
