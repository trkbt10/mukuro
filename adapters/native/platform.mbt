///|
/// Native Platform 統合

///|
pub struct NativePlatform {
  clock : NativeClock
  logger : NativeLogger
  filesystem : NativeFileStore
  http_client : NativeHttpClient
  process : NativeProcessExecutor
  timer : NativeTimer
  crypto : NativeCrypto
  random : NativeRandom
}

///|
pub fn NativePlatform::new() -> NativePlatform {
  {
    clock: NativeClock::new(),
    logger: NativeLogger::default(),
    filesystem: NativeFileStore::default(),
    http_client: NativeHttpClient::default(),
    process: NativeProcessExecutor::default(),
    timer: NativeTimer::new(),
    crypto: NativeCrypto::new(),
    random: NativeRandom::new(),
  }
}

///|
pub fn NativePlatform::with_config(
  log_level~ : @interfaces.LogLevel,
  log_output~ : LogOutput,
  base_dir~ : String?,
  http_timeout~ : Int,
  user_agent~ : String,
) -> NativePlatform {
  {
    clock: NativeClock::new(),
    logger: NativeLogger::new(
      min_level=log_level,
      output=log_output,
      include_timestamp=true,
    ),
    filesystem: NativeFileStore::new(base_dir~),
    http_client: NativeHttpClient::new(
      timeout_seconds=http_timeout,
      user_agent~,
    ),
    process: NativeProcessExecutor::default(),
    timer: NativeTimer::new(),
    crypto: NativeCrypto::new(),
    random: NativeRandom::new(),
  }
}

///|
pub fn NativePlatform::get_info(
  self : NativePlatform,
) -> @interfaces.PlatformInfo {
  let os_name = try {
    let result = self.process.shell("uname -s")
    result.stdout.to_unchecked_string().split("\n").collect()[0].to_string()
  } catch {
    _ => "Unknown"
  }
  let arch = try {
    let result = self.process.shell("uname -m")
    result.stdout.to_unchecked_string().split("\n").collect()[0].to_string()
  } catch {
    _ => "Unknown"
  }
  let version = try {
    let result = self.process.shell("uname -r")
    result.stdout.to_unchecked_string().split("\n").collect()[0].to_string()
  } catch {
    _ => "Unknown"
  }
  { platform_type: @interfaces.PlatformType::Native(os_name), arch, version }
}

///|
pub fn NativePlatform::now(self : NativePlatform) -> Int64 {
  self.clock.now_ms()
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

///|
pub fn NativePlatform::read_file(
  self : NativePlatform,
  path : String,
) -> Bytes raise FileSystemError {
  // Call implementation directly to avoid trait error type mismatch
  let resolved = self.filesystem.resolve_path(path)
  let cpath = string_to_cstring(resolved)
  match c_fopen(cpath, string_to_cstring("rb")) {
    Some(file) => {
      let buffer_size = 65536
      let buffer = Bytes::new(buffer_size)
      let bytes_read = c_fread(buffer, 1, buffer_size, file)
      let _ = c_fclose(file)
      if bytes_read < 0 {
        raise FileSystemError::IoError("Read error: \{resolved}")
      }
      if bytes_read < buffer_size {
        Bytes::from_iter(buffer.sub(end=bytes_read).iter())
      } else {
        buffer
      }
    }
    None => raise FileSystemError::FileNotFound(resolved)
  }
}

///|
pub fn NativePlatform::write_file(
  self : NativePlatform,
  path : String,
  data : Bytes,
) -> Unit raise FileSystemError {
  // Call implementation directly to avoid trait error type mismatch
  let resolved = self.filesystem.resolve_path(path)
  let cpath = string_to_cstring(resolved)
  match c_fopen(cpath, string_to_cstring("wb")) {
    Some(file) => {
      let bytes_written = c_fwrite(data, 1, data.length(), file)
      let _ = c_fclose(file)
      if bytes_written != data.length() {
        raise FileSystemError::IoError("Write error: \{resolved}")
      }
    }
    None =>
      raise FileSystemError::IoError(
        "Cannot open file for writing: \{resolved}",
      )
  }
}

///|
pub fn NativePlatform::http_request(
  self : NativePlatform,
  request : @interfaces.HttpRequest,
) -> @interfaces.HttpResponse raise HttpError {
  // Call the NativeHttpClient.request implementation directly
  let cmd = self.http_client.build_curl_command(request)
  let result = self.process.shell(cmd) catch {
    _ => raise HttpError::ConnectionFailed("Failed to execute curl")
  }
  if result.exit_code != 0 {
    raise HttpError::ConnectionFailed(
      "curl failed with exit code: \{result.exit_code}",
    )
  }
  parse_curl_response(result.stdout)
}

///|
pub fn NativePlatform::exec(
  self : NativePlatform,
  command : String,
  args : Array[String],
) -> @interfaces.ProcessResult raise ProcessError {
  // Call implementation directly to avoid trait error type mismatch
  let cmd = build_command(command, args, @interfaces.ProcessOptions::default())
  match c_popen(string_to_cstring(cmd), string_to_cstring("r")) {
    Some(pipe) => {
      let buffer = Bytes::new(65536)
      let bytes_read = c_fread(buffer, 1, 65536, pipe)
      let exit_code = c_pclose(pipe)
      let stdout = if bytes_read > 0 {
        Bytes::from_iter(buffer.sub(end=bytes_read).iter())
      } else {
        Bytes::new(0)
      }
      let actual_exit_code = (exit_code.reinterpret_as_uint() >> 8)
        .land(0xFFU)
        .reinterpret_as_int()
      { exit_code: actual_exit_code, stdout, stderr: Bytes::new(0) }
    }
    None => raise ProcessError::ExecutionFailed("Failed to execute: \{command}")
  }
}

///|
pub fn NativePlatform::set_timeout(
  self : NativePlatform,
  delay_ms : Int64,
  callback : () -> Unit,
) -> String {
  self.timer.set_timeout(delay_ms~, callback~)
}

///|
pub fn NativePlatform::set_interval(
  self : NativePlatform,
  interval_ms : Int64,
  callback : () -> Unit,
) -> String {
  self.timer.set_interval(interval_ms~, callback~)
}

///|
pub fn NativePlatform::cancel_timer(
  self : NativePlatform,
  timer_id : String,
) -> Unit {
  self.timer.cancel(timer_id~)
}

///|
pub fn NativePlatform::tick(self : NativePlatform) -> Unit {
  self.timer.tick()
}

///|
pub fn NativePlatform::uuid(self : NativePlatform) -> String {
  self.random.uuid_v4()
}

///|
pub fn NativePlatform::get_env(self : NativePlatform, name : String) -> String? {
  ignore(self)
  match c_getenv(string_to_cstring(name)) {
    Some(value) => Some(cstring_to_string(value))
    None => None
  }
}

///|
pub fn NativePlatform::set_env(
  self : NativePlatform,
  name : String,
  value : String,
) -> Bool {
  ignore(self)
  c_setenv(string_to_cstring(name), string_to_cstring(value), 1) == 0
}
