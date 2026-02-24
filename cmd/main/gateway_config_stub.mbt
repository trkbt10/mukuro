///|
/// gateway --config 読み込みスタブ（JS/WASM）

///|
pub fn load_gateway_config_impl(
  config_path : String,
) -> @interfaces.GatewayConfig raise @interfaces.ControlError {
  raise @interfaces.ControlError::ConfigError(
    "Config file loading is only available on native target: \{config_path}",
  )
}
