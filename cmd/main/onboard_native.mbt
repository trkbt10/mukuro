///|
/// Onboard実装（Native専用）

///|
fn resolve_onboard_output_path(path : String) -> String {
  path
}

///|
pub fn execute_onboard_impl(
  provider : String,
  api_key : String,
  default_model : String,
  output_path : String,
  config_json : String,
) -> CliResult {
  ignore(api_key)
  let resolved_output_path = resolve_onboard_output_path(output_path)
  if @native.c_write_text_file_bytes(
      @native.string_to_utf8_cstring(resolved_output_path),
      @native.string_to_utf8_cstring(config_json),
    ) !=
    0 {
    return CliResult::Error("Failed to write configuration file")
  }
  CliResult::Ok(
    "Configuration written:\n  Provider: \{provider}\n  Model: \{default_model}\n  Output: \{resolved_output_path}\n\nConfig JSON:\n\{config_json}",
  )
}
