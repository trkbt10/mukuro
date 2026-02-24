///|
/// Onboardスタブ（JS/WASM）

///|
pub fn execute_onboard_impl(
  provider : String,
  api_key : String,
  default_model : String,
  output_path : String,
  config_json : String,
) -> CliResult {
  ignore(api_key)
  CliResult::Ok(
    "Configuration prepared:\n  Provider: \{provider}\n  Model: \{default_model}\n  Output: \{output_path}\n\nConfig JSON:\n\{config_json}\n\nNote: file persistence is available on native target.",
  )
}
