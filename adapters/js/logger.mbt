///|
/// JavaScript Logger 実装
/// console.log等を使用したブラウザ/Node.js向けロガー

///|
extern "js" fn js_console_log(message : String) -> Unit =
  #|(message) => { console.log(message); }

///|
extern "js" fn js_console_warn(message : String) -> Unit =
  #|(message) => { console.warn(message); }

///|
extern "js" fn js_console_error(message : String) -> Unit =
  #|(message) => { console.error(message); }

///|
extern "js" fn js_console_debug(message : String) -> Unit =
  #|(message) => { console.debug(message); }

///|
extern "js" fn js_date_now_iso() -> String =
  #|() => { return new Date().toISOString(); }

///|
fn js_output(level : @interfaces.LogLevel, message : String) -> Unit {
  match level {
    @interfaces.LogLevel::Debug => js_console_debug(message)
    @interfaces.LogLevel::Info => js_console_log(message)
    @interfaces.LogLevel::Warn => js_console_warn(message)
    @interfaces.LogLevel::Error => js_console_error(message)
  }
}

///|
pub struct JsLogger {
  min_level : @interfaces.LogLevel
  include_timestamp : Bool
}

///|
pub fn JsLogger::new(
  min_level~ : @interfaces.LogLevel,
  include_timestamp~ : Bool,
) -> JsLogger {
  { min_level, include_timestamp }
}

///|
pub fn JsLogger::default() -> JsLogger {
  { min_level: @interfaces.LogLevel::Info, include_timestamp: true }
}

///|
fn JsLogger::log(
  self : JsLogger,
  level : @interfaces.LogLevel,
  message : String,
) -> Unit {
  if @logging.level_to_int(level) < @logging.level_to_int(self.min_level) {
    return
  }
  let formatted = if self.include_timestamp {
    let ts = js_date_now_iso()
    "[\{ts}] [\{@logging.level_to_string(level)}] \{message}"
  } else {
    "[\{@logging.level_to_string(level)}] \{message}"
  }
  js_output(level, formatted)
}

///|
pub impl @interfaces.Logger for JsLogger with debug(self, message~) {
  self.log(@interfaces.LogLevel::Debug, message)
}

///|
pub impl @interfaces.Logger for JsLogger with info(self, message~) {
  self.log(@interfaces.LogLevel::Info, message)
}

///|
pub impl @interfaces.Logger for JsLogger with warn(self, message~) {
  self.log(@interfaces.LogLevel::Warn, message)
}

///|
pub impl @interfaces.Logger for JsLogger with error(self, message~) {
  self.log(@interfaces.LogLevel::Error, message)
}

///|
pub struct JsStructuredLogger {
  min_level : @interfaces.LogLevel
  format : @interfaces.LogFormat
  context : @interfaces.LogContext
  component_levels : Array[@interfaces.ComponentLogLevel]
}

///|
pub fn JsStructuredLogger::new(
  min_level~ : @interfaces.LogLevel,
  format~ : @interfaces.LogFormat,
) -> JsStructuredLogger {
  {
    min_level,
    format,
    context: @interfaces.LogContext::empty(),
    component_levels: [],
  }
}

///|
pub fn JsStructuredLogger::default() -> JsStructuredLogger {
  {
    min_level: @interfaces.LogLevel::Info,
    format: @interfaces.LogFormat::Json,
    context: @interfaces.LogContext::empty(),
    component_levels: [],
  }
}

///|
pub fn JsStructuredLogger::add_component_level(
  self : JsStructuredLogger,
  component~ : String,
  level~ : @interfaces.LogLevel,
) -> JsStructuredLogger {
  let new_levels = self.component_levels.copy()
  new_levels.push({ component, min_level: level })
  {
    min_level: self.min_level,
    format: self.format,
    context: self.context,
    component_levels: new_levels,
  }
}

///|
fn JsStructuredLogger::output_log(
  self : JsStructuredLogger,
  level : @interfaces.LogLevel,
  message : String,
  context : @interfaces.LogContext,
) -> Unit {
  ignore(self)
  let ts = js_date_now_iso()
  let line = match self.format {
    @interfaces.LogFormat::Json | @interfaces.LogFormat::JsonCompact =>
      @logging.build_json_log(ts, level, message, context)
    @interfaces.LogFormat::Plain =>
      @logging.build_plain_log(ts, level, message, context)
  }
  js_output(level, line)
}

///|
pub impl @interfaces.StructuredLogger for JsStructuredLogger with log_structured(
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
pub impl @interfaces.StructuredLogger for JsStructuredLogger with with_context(
  self,
  context~,
) {
  {
    min_level: self.min_level,
    format: self.format,
    context,
    component_levels: self.component_levels,
  }
}

///|
pub impl @interfaces.StructuredLogger for JsStructuredLogger with with_request_id(
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
    format: self.format,
    context: new_context,
    component_levels: self.component_levels,
  }
}

///|
pub impl @interfaces.StructuredLogger for JsStructuredLogger with with_component(
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
    format: self.format,
    context: new_context,
    component_levels: self.component_levels,
  }
}

///|
pub impl @interfaces.Logger for JsStructuredLogger with debug(self, message~) {
  self.log_structured(
    level=@interfaces.LogLevel::Debug,
    message~,
    context=self.context,
  )
}

///|
pub impl @interfaces.Logger for JsStructuredLogger with info(self, message~) {
  self.log_structured(
    level=@interfaces.LogLevel::Info,
    message~,
    context=self.context,
  )
}

///|
pub impl @interfaces.Logger for JsStructuredLogger with warn(self, message~) {
  self.log_structured(
    level=@interfaces.LogLevel::Warn,
    message~,
    context=self.context,
  )
}

///|
pub impl @interfaces.Logger for JsStructuredLogger with error(self, message~) {
  self.log_structured(
    level=@interfaces.LogLevel::Error,
    message~,
    context=self.context,
  )
}
