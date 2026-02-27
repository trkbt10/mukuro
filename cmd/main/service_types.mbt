///|
/// Service Types
/// Platform-specific service configuration types

///|
/// Service identifier
pub let service_name : String = "com.mukuro.gateway"

///|
/// Service display name
pub let service_display_name : String = "Mukuro Gateway"

///|
/// Supported platforms
pub(all) enum ServicePlatform {
  MacOS
  Linux
  Windows
  Unknown
}

///|
/// Detect current platform
pub fn detect_platform() -> ServicePlatform {
  // In native builds, we can detect via compile-time flags
  // For now, use a simple heuristic based on available paths
  ServicePlatform::Unknown
}

///|
/// Service configuration
pub(all) struct ServiceConfig {
  /// Service name (launchd label / systemd unit name)
  name : String
  /// Display name
  display_name : String
  /// Path to executable
  executable : String
  /// Arguments
  args : Array[String]
  /// Working directory
  working_dir : String
  /// Config file path
  config_path : String?
  /// User-level or system-level
  user_level : Bool
  /// Auto-start on boot
  auto_start : Bool
  /// Standard output log path
  stdout_log : String?
  /// Standard error log path
  stderr_log : String?
}

///|
/// Create default service config
pub fn ServiceConfig::default(exe_path : String, config_path : String?) -> ServiceConfig {
  {
    name: service_name,
    display_name: service_display_name,
    executable: exe_path,
    args: ["gateway", "--control-api"],
    working_dir: "/tmp",
    config_path,
    user_level: true,
    auto_start: true,
    stdout_log: None,
    stderr_log: None,
  }
}

///|
/// Service status
pub(all) struct ServiceStatus {
  /// Is installed
  installed : Bool
  /// Is running
  running : Bool
  /// PID if running
  pid : Int?
  /// Status message
  message : String
}

///|
/// Convert ServiceStatus to JSON
pub fn ServiceStatus::to_json(self : ServiceStatus) -> Json {
  let obj : Map[String, Json] = {}
  obj["installed"] = Json::boolean(self.installed)
  obj["running"] = Json::boolean(self.running)
  match self.pid {
    Some(p) => obj["pid"] = Json::number(p.to_double())
    None => obj["pid"] = Json::null()
  }
  obj["message"] = Json::string(self.message)
  Json::object(obj)
}
