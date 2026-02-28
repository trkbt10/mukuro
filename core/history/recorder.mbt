///|
/// 履歴レコードのシリアライズ・デシリアライズとパス計算
/// I/O を含まない純粋ロジック

///|
/// HistoryRecordType を JSONL type 文字列に変換
pub fn record_type_to_string(rt : @interfaces.HistoryRecordType) -> String {
  match rt {
    SessionStart => "session_start"
    UserMessage => "user_message"
    AssistantMessage => "assistant_message"
    ToolCall => "tool_call"
    ToolResult => "tool_result"
    SessionEnd => "session_end"
    Error => "error"
  }
}

///|
/// JSONL type 文字列から HistoryRecordType に変換
pub fn string_to_record_type(s : String) -> @interfaces.HistoryRecordType? {
  match s {
    "session_start" => Some(@interfaces.HistoryRecordType::SessionStart)
    "user_message" => Some(@interfaces.HistoryRecordType::UserMessage)
    "assistant_message" => Some(@interfaces.HistoryRecordType::AssistantMessage)
    "tool_call" => Some(@interfaces.HistoryRecordType::ToolCall)
    "tool_result" => Some(@interfaces.HistoryRecordType::ToolResult)
    "session_end" => Some(@interfaces.HistoryRecordType::SessionEnd)
    "error" => Some(@interfaces.HistoryRecordType::Error)
    _ => None
  }
}

///|
/// HistoryRecord を JSON 1行文字列に変換（JSONL用、末尾改行なし）
pub fn record_to_json_line(record : @interfaces.HistoryRecord) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\"ts\":")
  buf.write_string(record.timestamp.to_string())
  buf.write_string(",\"sid\":\"")
  buf.write_string(@logging.escape_json_string(record.session_id))
  buf.write_string("\",\"type\":\"")
  buf.write_string(record_type_to_string(record.record_type))
  buf.write_string("\",\"payload\":")
  buf.write_string(record.payload.stringify())
  buf.write_string("}")
  buf.to_string()
}

///|
/// JSON 1行文字列から HistoryRecord にパース
pub fn parse_json_to_record(line : String) -> @interfaces.HistoryRecord? {
  let json : Json = @json.parse(line) catch { _ => return None }
  let obj = match json {
    Object(obj) => obj
    _ => return None
  }
  let timestamp = match obj.get("ts") {
    Some(Number(n, ..)) => n.to_int64()
    _ => return None
  }
  let session_id = match obj.get("sid") {
    Some(String(s)) => s
    _ => return None
  }
  let record_type = match obj.get("type") {
    Some(String(s)) =>
      match string_to_record_type(s) {
        Some(rt) => rt
        None => return None
      }
    _ => return None
  }
  let payload = match obj.get("payload") {
    Some(p) => p
    None => return None
  }
  Some({ timestamp, session_id, record_type, payload })
}

///|
/// 日付パーツから履歴ディレクトリパスを構築
/// returns: e.g. ".mukuro/history/2026/02/28"
pub fn history_dir_for_date(
  base_dir : String,
  year : Int,
  month : Int,
  day : Int,
) -> String {
  let y = year.to_string()
  let m = zero_pad2(month)
  let d = zero_pad2(day)
  "\{base_dir}/history/\{y}/\{m}/\{d}"
}

///|
/// 履歴ファイルのフルパスを構築
/// returns: e.g. ".mukuro/history/2026/02/28/web_chat-abc123-1709164800.jsonl"
pub fn history_file_path(
  base_dir : String,
  channel : String,
  chat_id : String,
  year : Int,
  month : Int,
  day : Int,
  epoch_secs : Int64,
) -> String {
  let dir = history_dir_for_date(base_dir, year, month, day)
  let safe_channel = sanitize_path_segment(channel)
  let safe_chat_id = sanitize_path_segment(chat_id)
  "\{dir}/\{safe_channel}-\{safe_chat_id}-\{epoch_secs}.jsonl"
}

///|
/// パスセグメントとして安全な文字列に変換（/や..を除去）
pub fn sanitize_path_segment(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '/' | '\\' | '\u0000' => buf.write_char('_')
      '.' =>
        // ".." を防ぐため、連続ドットは置換
        buf.write_char('.')
      _ => buf.write_char(c)
    }
  }
  let result = buf.to_string()
  // ".." を含む場合は安全に置換
  if result.contains("..") {
    result.replace(old="..", new="__")
  } else {
    result
  }
}

///|
/// 2桁ゼロパディング
fn zero_pad2(n : Int) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    n.to_string()
  }
}
