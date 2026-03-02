///|
/// Native エントリーポイント
/// mukuro CLI for native environments

///|
/// PlatformType を文字列に変換
fn platform_type_to_string(pt : @interfaces.PlatformType) -> String {
  match pt {
    @interfaces.PlatformType::Browser => "Browser"
    @interfaces.PlatformType::NodeJS => "NodeJS"
    @interfaces.PlatformType::Native(os) => "Native(\{os})"
    @interfaces.PlatformType::Unknown => "Unknown"
  }
}

///|
fn main {
  // Initialize native platform
  let platform = @adapter_native.NativePlatform::new()

  // Print startup message
  platform.log(@interfaces.LogLevel::Info, "mukuro native runtime starting...")

  // Get platform info
  let info = platform.get_info()
  let pt_str = platform_type_to_string(info.platform_type)
  platform.log(
    @interfaces.LogLevel::Info,
    "Platform: \{pt_str}, Arch: \{info.arch}, Version: \{info.version}",
  )

  // Demo: list available tools
  let tools = @tools.all_tool_definitions()
  platform.log(@interfaces.LogLevel::Info, "Available tools: \{tools.length()}")
  for tool in tools {
    platform.log(
      @interfaces.LogLevel::Debug,
      "  - \{tool.name}: \{tool.description}",
    )
  }

  // Demo: test datetime tool
  let datetime_result = @tools.execute_datetime({ "action": "now" })
  match datetime_result.status {
    @tools.ToolResultStatus::Success =>
      platform.log(
        @interfaces.LogLevel::Info,
        "Current time: \{datetime_result.data}",
      )
    @tools.ToolResultStatus::Error =>
      match datetime_result.error_message {
        Some(msg) =>
          platform.log(@interfaces.LogLevel::Error, "Datetime error: \{msg}")
        None =>
          platform.log(@interfaces.LogLevel::Error, "Datetime error: unknown")
      }
    _ => ()
  }
  platform.log(@interfaces.LogLevel::Info, "mukuro native runtime ready")
}
