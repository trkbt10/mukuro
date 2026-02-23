///|
/// 日時ツール - 現在時刻の取得やフォーマット

///|
/// 現在時刻を秒で取得
pub fn get_current_time_seconds() -> Int64 {
  get_current_time_ms() / 1000L
}

///|
/// DateTimeツール定義
pub fn datetime_tool_definition() -> @types.ToolDefinition {
  make_tool_definition(
    name="datetime",
    description="Get current date and time information",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([
            Json::string("now"),
            Json::string("timestamp"),
            Json::string("format"),
          ]),
          "description": "Action to perform: now (current datetime), timestamp (unix timestamp), format (formatted string)",
        },
        "format": string_param("Date format pattern (for format action)", false),
        "timezone": string_param("Timezone (e.g., UTC, JST)", false),
      },
      ["action"],
    ),
  )
}

///|
/// DateTimeツールを実行
pub fn execute_datetime_tool(args : Json) -> ToolExecutionResult {
  let action = match get_string_arg(args, "action") {
    Some(a) => a
    None => return ToolExecutionResult::error("Missing action argument")
  }
  match action {
    "now" => {
      let timestamp = get_current_time_ms()
      ToolExecutionResult::success({
        "timestamp_ms": timestamp.to_int(),
        "timestamp_seconds": (timestamp / 1000L).to_int(),
        "iso8601": format_iso8601(timestamp),
      })
    }
    "timestamp" => {
      let timestamp = get_current_time_ms()
      ToolExecutionResult::success({ "timestamp": timestamp.to_int() })
    }
    "format" => {
      let timestamp = get_current_time_ms()
      let format_str = get_string_arg(args, "format").unwrap_or("ISO8601")
      ToolExecutionResult::success({
        "formatted": format_timestamp(timestamp, format_str),
      })
    }
    _ => ToolExecutionResult::error("Unknown action: \{action}")
  }
}

///|
/// タイムスタンプをISO8601形式にフォーマット
fn format_iso8601(timestamp_ms : Int64) -> String {
  // 簡易実装（実際にはJSのDate APIを使うべき）
  let seconds = timestamp_ms / 1000L
  let ms = timestamp_ms % 1000L
  // Unix epoch からの経過時間を日時に変換
  let days_since_epoch = seconds / 86400L
  let time_of_day = seconds % 86400L
  let hours = time_of_day / 3600L
  let minutes = time_of_day % 3600L / 60L
  let secs = time_of_day % 60L
  // 年月日の計算（簡易版、うるう年は未考慮）
  let year = 1970L + days_since_epoch / 365L
  let day_of_year = days_since_epoch % 365L + 1L
  let month = day_of_year / 30L + 1L
  let day = day_of_year % 30L + 1L
  "\{year}-\{pad_zero(month.to_int())}-\{pad_zero(day.to_int())}T\{pad_zero(hours.to_int())}:\{pad_zero(minutes.to_int())}:\{pad_zero(secs.to_int())}.\{ms}Z"
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
/// タイムスタンプをフォーマット
fn format_timestamp(timestamp_ms : Int64, format : String) -> String {
  // 簡易実装
  match format {
    "ISO8601" => format_iso8601(timestamp_ms)
    "UNIX" => (timestamp_ms / 1000L).to_string()
    "UNIX_MS" => timestamp_ms.to_string()
    _ => format_iso8601(timestamp_ms)
  }
}
