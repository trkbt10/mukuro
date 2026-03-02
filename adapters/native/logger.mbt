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
fn NativeLogger::log(
  self : NativeLogger,
  level : @interfaces.LogLevel,
  message : String,
) -> Unit {
  if @logging.level_to_int(level) < @logging.level_to_int(self.min_level) {
    return
  }
  let formatted = if self.include_timestamp {
    let ts = c_time()
    "[\{ts}] [\{@logging.level_to_string(level)}] \{message}"
  } else {
    "[\{@logging.level_to_string(level)}] \{message}"
  }
  output_line(self.output, formatted)
}

///|
fn output_line(output : LogOutput, line : String) -> Unit {
  match output {
    LogOutput::Stdout => {
      let data = @utf8.encode(line + "\n")
      let _ = c_write_stdout(data, data.length())
    }
    LogOutput::Stderr => {
      let data = @utf8.encode(line + "\n")
      let _ = c_write_stderr(data, data.length())
    }
    LogOutput::File(path) =>
      native_append_file_text(path, line + "\n") catch {
        _ => ()
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

///|
/// 構造化ロガー Native実装
pub struct NativeStructuredLogger {
  min_level : @interfaces.LogLevel
  output : LogOutput
  format : @interfaces.LogFormat
  context : @interfaces.LogContext
  component_levels : Array[@interfaces.ComponentLogLevel]
}

///|
pub fn NativeStructuredLogger::new(
  min_level~ : @interfaces.LogLevel,
  output~ : LogOutput,
  format~ : @interfaces.LogFormat,
) -> NativeStructuredLogger {
  {
    min_level,
    output,
    format,
    context: @interfaces.LogContext::empty(),
    component_levels: [],
  }
}

///|
pub fn NativeStructuredLogger::default() -> NativeStructuredLogger {
  {
    min_level: @interfaces.LogLevel::Info,
    output: LogOutput::Stderr,
    format: @interfaces.LogFormat::Json,
    context: @interfaces.LogContext::empty(),
    component_levels: [],
  }
}

///|
pub fn NativeStructuredLogger::add_component_level(
  self : NativeStructuredLogger,
  component~ : String,
  level~ : @interfaces.LogLevel,
) -> NativeStructuredLogger {
  let new_levels = self.component_levels.copy()
  new_levels.push({ component, min_level: level })
  {
    min_level: self.min_level,
    output: self.output,
    format: self.format,
    context: self.context,
    component_levels: new_levels,
  }
}

///|
fn NativeStructuredLogger::output_log(
  self : NativeStructuredLogger,
  level : @interfaces.LogLevel,
  message : String,
  context : @interfaces.LogContext,
) -> Unit {
  let ts = c_time().to_string()
  let line = match self.format {
    @interfaces.LogFormat::Json | @interfaces.LogFormat::JsonCompact =>
      @logging.build_json_log(ts, level, message, context)
    @interfaces.LogFormat::Plain =>
      @logging.build_plain_log(ts, level, message, context)
  }
  output_line(self.output, line)
}

///|
pub impl @interfaces.StructuredLogger for NativeStructuredLogger with log_structured(
  self,
  level~,
  message~,
  context~,
) {
  let effective_level = @logging.get_effective_level(
    self.component_levels,
    self.min_level,
    context.component,
  )
  if @logging.level_to_int(level) < @logging.level_to_int(effective_level) {
    return
  }
  self.output_log(level, message, context)
}

///|
pub impl @interfaces.StructuredLogger for NativeStructuredLogger with with_context(
  self,
  context~,
) {
  {
    min_level: self.min_level,
    output: self.output,
    format: self.format,
    context,
    component_levels: self.component_levels,
  }
}

///|
pub impl @interfaces.StructuredLogger for NativeStructuredLogger with with_request_id(
  self,
  request_id~,
) {
  let new_context : @interfaces.LogContext = {
    request_id: Some(request_id),
    agent_id: self.context.agent_id,
    component: self.context.component,
    extra: self.context.extra,
  }
  {
    min_level: self.min_level,
    output: self.output,
    format: self.format,
    context: new_context,
    component_levels: self.component_levels,
  }
}

///|
pub impl @interfaces.StructuredLogger for NativeStructuredLogger with with_component(
  self,
  component~,
) {
  let new_context : @interfaces.LogContext = {
    request_id: self.context.request_id,
    agent_id: self.context.agent_id,
    component: Some(component),
    extra: self.context.extra,
  }
  {
    min_level: self.min_level,
    output: self.output,
    format: self.format,
    context: new_context,
    component_levels: self.component_levels,
  }
}

///|
pub impl @interfaces.Logger for NativeStructuredLogger with debug(
  self,
  message~,
) {
  self.log_structured(
    level=@interfaces.LogLevel::Debug,
    message~,
    context=self.context,
  )
}

///|
pub impl @interfaces.Logger for NativeStructuredLogger with info(self, message~) {
  self.log_structured(
    level=@interfaces.LogLevel::Info,
    message~,
    context=self.context,
  )
}

///|
pub impl @interfaces.Logger for NativeStructuredLogger with warn(self, message~) {
  self.log_structured(
    level=@interfaces.LogLevel::Warn,
    message~,
    context=self.context,
  )
}

///|
pub impl @interfaces.Logger for NativeStructuredLogger with error(
  self,
  message~,
) {
  self.log_structured(
    level=@interfaces.LogLevel::Error,
    message~,
    context=self.context,
  )
}
