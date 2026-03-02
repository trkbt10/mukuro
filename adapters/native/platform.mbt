///|
/// Native Platform 統合

///|
pub struct NativePlatform {
  clock : NativeClock
  logger : NativeLogger
  process : NativeProcessExecutor
}

///|
pub fn NativePlatform::new() -> NativePlatform {
  {
    clock: NativeClock::new(),
    logger: NativeLogger::default(),
    process: NativeProcessExecutor::default(),
  }
}

///|
pub fn NativePlatform::get_info(
  self : NativePlatform,
) -> @interfaces.PlatformInfo {
  let os_name = try {
    let result = self.process.shell("uname -s")
    @bytes.decode_utf8_or(result.stdout[:], default="Unknown")
    .split("\n")
    .collect()[0].to_string()
  } catch {
    _ => "Unknown"
  }
  let arch = try {
    let result = self.process.shell("uname -m")
    @bytes.decode_utf8_or(result.stdout[:], default="Unknown")
    .split("\n")
    .collect()[0].to_string()
  } catch {
    _ => "Unknown"
  }
  let version = try {
    let result = self.process.shell("uname -r")
    @bytes.decode_utf8_or(result.stdout[:], default="Unknown")
    .split("\n")
    .collect()[0].to_string()
  } catch {
    _ => "Unknown"
  }
  { platform_type: @interfaces.PlatformType::Native(os_name), arch, version }
}

///|
pub fn NativePlatform::log(
  self : NativePlatform,
  level : @interfaces.LogLevel,
  message : String,
) -> Unit {
  match level {
    @interfaces.LogLevel::Debug => self.logger.debug(message~)
    @interfaces.LogLevel::Info => self.logger.info(message~)
    @interfaces.LogLevel::Warn => self.logger.warn(message~)
    @interfaces.LogLevel::Error => self.logger.error(message~)
  }
}
