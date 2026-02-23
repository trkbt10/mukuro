///|
/// Native Logger 実装

///|
pub(all) enum LogOutput {
  Stdout
  Stderr
  File(String)
}

///|
pub struct NativeLogger {
  min_level : @interfaces.LogLevel
  output : LogOutput
  include_timestamp : Bool
}

///|
pub fn NativeLogger::new(
  min_level~ : @interfaces.LogLevel,
  output~ : LogOutput,
  include_timestamp~ : Bool,
) -> NativeLogger {
  { min_level, output, include_timestamp }
}

///|
pub fn NativeLogger::default() -> NativeLogger {
  {
    min_level: @interfaces.LogLevel::Info,
    output: LogOutput::Stderr,
    include_timestamp: true,
  }
}

///|
fn level_to_int(level : @interfaces.LogLevel) -> Int {
  match level {
    @interfaces.LogLevel::Debug => 0
    @interfaces.LogLevel::Info => 1
    @interfaces.LogLevel::Warn => 2
    @interfaces.LogLevel::Error => 3
  }
}

///|
fn level_to_string(level : @interfaces.LogLevel) -> String {
  match level {
    @interfaces.LogLevel::Debug => "DEBUG"
    @interfaces.LogLevel::Info => "INFO"
    @interfaces.LogLevel::Warn => "WARN"
    @interfaces.LogLevel::Error => "ERROR"
  }
}

///|
fn NativeLogger::log(
  self : NativeLogger,
  level : @interfaces.LogLevel,
  message : String,
) -> Unit {
  if level_to_int(level) < level_to_int(self.min_level) {
    return
  }
  let formatted = if self.include_timestamp {
    let ts = c_time()
    "[\{ts}] [\{level_to_string(level)}] \{message}"
  } else {
    "[\{level_to_string(level)}] \{message}"
  }
  match self.output {
    LogOutput::Stdout => {
      let _ = c_puts(string_to_cstring(formatted))

    }
    LogOutput::Stderr => {
      let stderr = c_get_stderr()
      let _ = c_fputs(string_to_cstring(formatted + "\n"), stderr)

    }
    LogOutput::File(path) =>
      match c_fopen(string_to_cstring(path), string_to_cstring("a")) {
        Some(file) => {
          let line = formatted + "\n"
          // 文字列をバイトに変換
          let bytes = Bytes::from_iter(
            line.iter().map(fn(c) { c.to_int().land(0xFF).to_byte() }),
          )
          let _ = c_fwrite(bytes, 1, bytes.length(), file)
          let _ = c_fclose(file)

        }
        None => ()
      }
  }
}

///|
pub impl @interfaces.Logger for NativeLogger with debug(self, message~) {
  self.log(@interfaces.LogLevel::Debug, message)
}

///|
pub impl @interfaces.Logger for NativeLogger with info(self, message~) {
  self.log(@interfaces.LogLevel::Info, message)
}

///|
pub impl @interfaces.Logger for NativeLogger with warn(self, message~) {
  self.log(@interfaces.LogLevel::Warn, message)
}

///|
pub impl @interfaces.Logger for NativeLogger with error(self, message~) {
  self.log(@interfaces.LogLevel::Error, message)
}
