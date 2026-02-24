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

///|
/// 構造化ロガー Native実装
pub struct NativeStructuredLogger {
  /// 最小ログレベル
  min_level : @interfaces.LogLevel
  /// 出力先
  output : LogOutput
  /// 出力フォーマット
  format : @interfaces.LogFormat
  /// 現在のコンテキスト
  context : @interfaces.LogContext
  /// コンポーネント別ログレベル
  component_levels : Array[@interfaces.ComponentLogLevel]
}

///|
/// NativeStructuredLoggerを新規作成
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
/// デフォルト設定で作成
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
/// コンポーネント別ログレベルを追加
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
/// コンポーネントの有効ログレベルを取得
fn NativeStructuredLogger::get_effective_level(
  self : NativeStructuredLogger,
  component : String?,
) -> @interfaces.LogLevel {
  match component {
    Some(comp) => {
      for cl in self.component_levels {
        if cl.component == comp {
          return cl.min_level
        }
      }
      self.min_level
    }
    None => self.min_level
  }
}

///|
/// ログレベルをJSON用文字列に変換
fn level_to_json_string(level : @interfaces.LogLevel) -> String {
  match level {
    @interfaces.LogLevel::Debug => "debug"
    @interfaces.LogLevel::Info => "info"
    @interfaces.LogLevel::Warn => "warn"
    @interfaces.LogLevel::Error => "error"
  }
}

///|
/// 文字列をJSONエスケープ
fn escape_json_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ =>
        if c.to_int() < 32 {
          buf.write_string("\\u")
          let hex = c.to_int().to_string()
          for _ in 0..<(4 - hex.length()) {
            buf.write_string("0")
          }
          buf.write_string(hex)
        } else {
          buf.write_char(c)
        }
    }
  }
  buf.to_string()
}

///|
/// JSON形式でログを出力
fn NativeStructuredLogger::output_json(
  self : NativeStructuredLogger,
  level : @interfaces.LogLevel,
  message : String,
  context : @interfaces.LogContext,
) -> Unit {
  let ts = c_time()
  let buf = StringBuilder::new()
  buf.write_string("{")
  buf.write_string("\"timestamp\":\{ts},")
  buf.write_string("\"level\":\"\{level_to_json_string(level)}\",")
  buf.write_string("\"message\":\"\{escape_json_string(message)}\"")
  // コンテキスト情報を追加
  match context.request_id {
    Some(rid) =>
      buf.write_string(",\"request_id\":\"\{escape_json_string(rid)}\"")
    None => ()
  }
  match context.agent_id {
    Some(aid) =>
      buf.write_string(",\"agent_id\":\"\{escape_json_string(aid)}\"")
    None => ()
  }
  match context.component {
    Some(comp) =>
      buf.write_string(",\"component\":\"\{escape_json_string(comp)}\"")
    None => ()
  }
  // extraフィールドを追加
  if not(context.extra.is_empty()) {
    buf.write_string(",\"extra\":{")
    let mut first = true
    for key, value in context.extra {
      if not(first) {
        buf.write_string(",")
      }
      buf.write_string(
        "\"\{escape_json_string(key)}\":\"\{escape_json_string(value)}\"",
      )
      first = false
    }
    buf.write_string("}")
  }
  buf.write_string("}")
  // 出力先に書き込み
  let line = buf.to_string()
  match self.output {
    LogOutput::Stdout => {
      let _ = c_puts(string_to_cstring(line))
    }
    LogOutput::Stderr => {
      let stderr = c_get_stderr()
      let _ = c_fputs(string_to_cstring(line + "\n"), stderr)
    }
    LogOutput::File(path) =>
      match c_fopen(string_to_cstring(path), string_to_cstring("a")) {
        Some(file) => {
          let out = line + "\n"
          let bytes = Bytes::from_iter(
            out.iter().map(fn(c) { c.to_int().land(0xFF).to_byte() }),
          )
          let _ = c_fwrite(bytes, 1, bytes.length(), file)
          let _ = c_fclose(file)
        }
        None => ()
      }
  }
}

///|
/// プレーンテキスト形式でログを出力
fn NativeStructuredLogger::output_plain(
  self : NativeStructuredLogger,
  level : @interfaces.LogLevel,
  message : String,
  context : @interfaces.LogContext,
) -> Unit {
  let ts = c_time()
  let buf = StringBuilder::new()
  buf.write_string("[\{ts}] [\{level_to_string(level)}]")
  // コンテキスト情報を追加
  match context.request_id {
    Some(rid) => buf.write_string(" [req:\{rid}]")
    None => ()
  }
  match context.agent_id {
    Some(aid) => buf.write_string(" [agent:\{aid}]")
    None => ()
  }
  match context.component {
    Some(comp) => buf.write_string(" [\{comp}]")
    None => ()
  }
  buf.write_string(" \{message}")
  let formatted = buf.to_string()
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
/// StructuredLogger実装
pub impl @interfaces.StructuredLogger for NativeStructuredLogger with log_structured(
  self,
  level~,
  message~,
  context~,
) {
  // コンポーネントの有効ログレベルをチェック
  let effective_level = self.get_effective_level(context.component)
  if level_to_int(level) < level_to_int(effective_level) {
    return
  }
  // フォーマットに応じて出力
  match self.format {
    @interfaces.LogFormat::Json | @interfaces.LogFormat::JsonCompact =>
      self.output_json(level, message, context)
    @interfaces.LogFormat::Plain => self.output_plain(level, message, context)
  }
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
/// Logger trait実装（StructuredLoggerをシンプルLoggerとして使用）
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
