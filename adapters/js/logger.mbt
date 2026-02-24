///|
/// JavaScript Logger 実装
/// console.log等を使用したブラウザ/Node.js向けロガー

///|
/// JavaScript console ログ関数
extern "js" fn js_console_log(message : String) -> Unit =
  #|(message) => { console.log(message); }

///|
/// JavaScript console 警告関数
extern "js" fn js_console_warn(message : String) -> Unit =
  #|(message) => { console.warn(message); }

///|
/// JavaScript console エラー関数
extern "js" fn js_console_error(message : String) -> Unit =
  #|(message) => { console.error(message); }

///|
/// JavaScript console デバッグ関数
extern "js" fn js_console_debug(message : String) -> Unit =
  #|(message) => { console.debug(message); }

///|
/// JavaScript 現在時刻取得（ISO形式）
extern "js" fn js_date_now_iso() -> String =
  #|() => { return new Date().toISOString(); }

///|
/// JS Logger実装
pub struct JsLogger {
  /// 最小ログレベル
  min_level : @interfaces.LogLevel
  /// タイムスタンプを含めるか
  include_timestamp : Bool
}

///|
/// JsLoggerを新規作成
pub fn JsLogger::new(
  min_level~ : @interfaces.LogLevel,
  include_timestamp~ : Bool,
) -> JsLogger {
  { min_level, include_timestamp }
}

///|
/// デフォルト設定で作成
pub fn JsLogger::default() -> JsLogger {
  { min_level: @interfaces.LogLevel::Info, include_timestamp: true }
}

///|
/// ログレベルを数値に変換
fn js_level_to_int(level : @interfaces.LogLevel) -> Int {
  match level {
    @interfaces.LogLevel::Debug => 0
    @interfaces.LogLevel::Info => 1
    @interfaces.LogLevel::Warn => 2
    @interfaces.LogLevel::Error => 3
  }
}

///|
/// ログレベルを文字列に変換
fn js_level_to_string(level : @interfaces.LogLevel) -> String {
  match level {
    @interfaces.LogLevel::Debug => "DEBUG"
    @interfaces.LogLevel::Info => "INFO"
    @interfaces.LogLevel::Warn => "WARN"
    @interfaces.LogLevel::Error => "ERROR"
  }
}

///|
/// ログを出力
fn JsLogger::log(
  self : JsLogger,
  level : @interfaces.LogLevel,
  message : String,
) -> Unit {
  if js_level_to_int(level) < js_level_to_int(self.min_level) {
    return
  }
  let formatted = if self.include_timestamp {
    let ts = js_date_now_iso()
    "[\{ts}] [\{js_level_to_string(level)}] \{message}"
  } else {
    "[\{js_level_to_string(level)}] \{message}"
  }
  match level {
    @interfaces.LogLevel::Debug => js_console_debug(formatted)
    @interfaces.LogLevel::Info => js_console_log(formatted)
    @interfaces.LogLevel::Warn => js_console_warn(formatted)
    @interfaces.LogLevel::Error => js_console_error(formatted)
  }
}

///|
/// Logger trait実装
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
/// 構造化ロガー JS実装
pub struct JsStructuredLogger {
  /// 最小ログレベル
  min_level : @interfaces.LogLevel
  /// 出力フォーマット
  format : @interfaces.LogFormat
  /// 現在のコンテキスト
  context : @interfaces.LogContext
  /// コンポーネント別ログレベル
  component_levels : Array[@interfaces.ComponentLogLevel]
}

///|
/// JsStructuredLoggerを新規作成
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
/// デフォルト設定で作成
pub fn JsStructuredLogger::default() -> JsStructuredLogger {
  {
    min_level: @interfaces.LogLevel::Info,
    format: @interfaces.LogFormat::Json,
    context: @interfaces.LogContext::empty(),
    component_levels: [],
  }
}

///|
/// コンポーネント別ログレベルを追加
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
/// コンポーネントの有効ログレベルを取得
fn JsStructuredLogger::get_effective_level(
  self : JsStructuredLogger,
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
fn js_level_to_json_string(level : @interfaces.LogLevel) -> String {
  match level {
    @interfaces.LogLevel::Debug => "debug"
    @interfaces.LogLevel::Info => "info"
    @interfaces.LogLevel::Warn => "warn"
    @interfaces.LogLevel::Error => "error"
  }
}

///|
/// 文字列をJSONエスケープ
fn js_escape_json_string(s : String) -> String {
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
fn JsStructuredLogger::output_json(
  self : JsStructuredLogger,
  level : @interfaces.LogLevel,
  message : String,
  context : @interfaces.LogContext,
) -> Unit {
  let ts = js_date_now_iso()
  let buf = StringBuilder::new()
  buf.write_string("{")
  buf.write_string("\"timestamp\":\"\{js_escape_json_string(ts)}\",")
  buf.write_string("\"level\":\"\{js_level_to_json_string(level)}\",")
  buf.write_string("\"message\":\"\{js_escape_json_string(message)}\"")
  // コンテキスト情報を追加
  match context.request_id {
    Some(rid) =>
      buf.write_string(",\"request_id\":\"\{js_escape_json_string(rid)}\"")
    None => ()
  }
  match context.agent_id {
    Some(aid) =>
      buf.write_string(",\"agent_id\":\"\{js_escape_json_string(aid)}\"")
    None => ()
  }
  match context.component {
    Some(comp) =>
      buf.write_string(",\"component\":\"\{js_escape_json_string(comp)}\"")
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
        "\"\{js_escape_json_string(key)}\":\"\{js_escape_json_string(value)}\"",
      )
      first = false
    }
    buf.write_string("}")
  }
  buf.write_string("}")
  // console出力
  let line = buf.to_string()
  match level {
    @interfaces.LogLevel::Debug => js_console_debug(line)
    @interfaces.LogLevel::Info => js_console_log(line)
    @interfaces.LogLevel::Warn => js_console_warn(line)
    @interfaces.LogLevel::Error => js_console_error(line)
  }
}

///|
/// プレーンテキスト形式でログを出力
fn JsStructuredLogger::output_plain(
  self : JsStructuredLogger,
  level : @interfaces.LogLevel,
  message : String,
  context : @interfaces.LogContext,
) -> Unit {
  ignore(self)
  let ts = js_date_now_iso()
  let buf = StringBuilder::new()
  buf.write_string("[\{ts}] [\{js_level_to_string(level)}]")
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
  match level {
    @interfaces.LogLevel::Debug => js_console_debug(formatted)
    @interfaces.LogLevel::Info => js_console_log(formatted)
    @interfaces.LogLevel::Warn => js_console_warn(formatted)
    @interfaces.LogLevel::Error => js_console_error(formatted)
  }
}

///|
/// StructuredLogger実装
pub impl @interfaces.StructuredLogger for JsStructuredLogger with log_structured(
  self,
  level~,
  message~,
  context~,
) {
  // コンポーネントの有効ログレベルをチェック
  let effective_level = self.get_effective_level(context.component)
  if js_level_to_int(level) < js_level_to_int(effective_level) {
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
/// Logger trait実装（StructuredLoggerをシンプルLoggerとして使用）
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
