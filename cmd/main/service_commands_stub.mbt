///|
/// Service Commands (Stub)
/// Placeholder for non-native platforms

///|
/// Execute service command (stub)
pub fn execute_service_command(cmd : ServiceCommand) -> CliResult {
  ignore(cmd)
  CliResult::Error("Service management is not supported on this platform")
}
