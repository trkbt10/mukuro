///|
/// 共通ログフォーマットユーティリティ

///|
/// ログレベルを数値に変換（フィルタリング用）
pub fn level_to_int(level : @interfaces.LogLevel) -> Int {
  match level {
    @interfaces.LogLevel::Debug => 0
    @interfaces.LogLevel::Info => 1
    @interfaces.LogLevel::Warn => 2
    @interfaces.LogLevel::Error => 3
  }
}

///|
/// ログレベルを大文字文字列に変換（プレーンテキスト出力用）
pub fn level_to_string(level : @interfaces.LogLevel) -> String {
  match level {
    @interfaces.LogLevel::Debug => "DEBUG"
    @interfaces.LogLevel::Info => "INFO"
    @interfaces.LogLevel::Warn => "WARN"
    @interfaces.LogLevel::Error => "ERROR"
  }
}

///|
/// ログレベルを小文字JSON用文字列に変換
pub fn level_to_json_string(level : @interfaces.LogLevel) -> String {
  match level {
    @interfaces.LogLevel::Debug => "debug"
    @interfaces.LogLevel::Info => "info"
    @interfaces.LogLevel::Warn => "warn"
    @interfaces.LogLevel::Error => "error"
  }
}

///|
/// 文字列をJSONエスケープ
pub fn escape_json_string(s : String) -> String {
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
/// コンポーネントの有効ログレベルを取得
pub fn get_effective_level(
  component_levels : Array[@interfaces.ComponentLogLevel],
  default_level : @interfaces.LogLevel,
  component : String?,
) -> @interfaces.LogLevel {
  match component {
    Some(comp) => {
      for cl in component_levels {
        if cl.component == comp {
          return cl.min_level
        }
      }
      default_level
    }
    None => default_level
  }
}

///|
/// JSON形式のログ行を構築
pub fn build_json_log(
  timestamp : String,
  level : @interfaces.LogLevel,
  message : String,
  context : @interfaces.LogContext,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{")
  buf.write_string("\"timestamp\":\"\{escape_json_string(timestamp)}\",")
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
  buf.to_string()
}

///|
/// プレーンテキスト形式のログ行を構築
pub fn build_plain_log(
  timestamp : String,
  level : @interfaces.LogLevel,
  message : String,
  context : @interfaces.LogContext,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("[\{timestamp}] [\{level_to_string(level)}]")
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
  buf.to_string()
}
