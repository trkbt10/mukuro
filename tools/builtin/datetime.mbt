///|
/// 日時ツール - 現在時刻の取得やフォーマット

///|
/// 現在時刻を秒で取得
pub fn get_current_time_seconds() -> Int64 {
  get_current_time_ms() / 1000L
}

///|
/// DateTimeツールを実行
pub fn execute_datetime_tool(args : Json) -> @defs.ToolExecutionResult {
  let action = match @defs.get_string_arg(args, "action") {
    Some(a) => a
    None => return @defs.ToolExecutionResult::error("Missing action argument")
  }
  match action {
    "now" => {
      let timestamp = get_current_time_ms()
      @defs.ToolExecutionResult::success({
        "timestamp_ms": Json::number(timestamp.to_double()),
        "timestamp_seconds": Json::number((timestamp / 1000L).to_double()),
        "iso8601": format_iso8601(timestamp),
      })
    }
    "timestamp" => {
      let timestamp = get_current_time_ms()
      @defs.ToolExecutionResult::success({
        "timestamp": Json::number(timestamp.to_double()),
      })
    }
    "format" => {
      let timestamp = get_current_time_ms()
      let format_str = @defs.get_string_arg(args, "format").unwrap_or("ISO8601")
      @defs.ToolExecutionResult::success({
        "formatted": format_timestamp(timestamp, format_str),
      })
    }
    _ => @defs.ToolExecutionResult::error("Unknown action: \{action}")
  }
}

///|
/// タイムスタンプをISO8601形式にフォーマット
fn format_iso8601(timestamp_ms : Int64) -> String {
  let seconds = timestamp_ms / 1000L
  let millis = (timestamp_ms % 1000L + 1000L) % 1000L
  let datetime = @xtime.unix(
    seconds,
    nanosecond=(millis * 1000000L).to_int(),
    zone=@xtime.utc_zone,
  ) catch {
    _ => return timestamp_ms.to_string()
  }
  "\{datetime.year()}-\{pad_zero(datetime.month())}-\{pad_zero(datetime.day())}T\{pad_zero(datetime.hour())}:\{pad_zero(datetime.minute())}:\{pad_zero(datetime.second())}.\{pad_millis(millis.to_int())}Z"
}

///|
/// 数値を2桁にゼロパディング
fn pad_zero(n : Int) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    n.to_string()
  }
}

///|
fn pad_millis(n : Int) -> String {
  if n < 10 {
    "00\{n}"
  } else if n < 100 {
    "0\{n}"
  } else {
    n.to_string()
  }
}

///|
/// タイムスタンプをフォーマット
fn format_timestamp(timestamp_ms : Int64, format : String) -> String {
  match format {
    "ISO8601" => format_iso8601(timestamp_ms)
    "UNIX" => (timestamp_ms / 1000L).to_string()
    "UNIX_MS" => timestamp_ms.to_string()
    _ => format_iso8601(timestamp_ms)
  }
}
