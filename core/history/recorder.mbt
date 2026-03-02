///|
/// 履歴レコードのシリアライズ・デシリアライズとパス計算
/// I/O を含まない純粋ロジック

///|
/// HistoryRecordType を JSONL type 文字列に変換
pub fn record_type_to_string(rt : @interfaces.HistoryRecordType) -> String {
  match rt {
    SessionMeta => "session_meta"
    UserMessage => "user_message"
    AssistantMessage => "assistant_message"
    ToolCall => "tool_call"
    ToolResult => "tool_result"
    Error => "error"
  }
}

///|
/// JSONL type 文字列から HistoryRecordType に変換
pub fn string_to_record_type(s : String) -> @interfaces.HistoryRecordType? {
  match s {
    "session_meta" => Some(@interfaces.HistoryRecordType::SessionMeta)
    "user_message" => Some(@interfaces.HistoryRecordType::UserMessage)
    "assistant_message" => Some(@interfaces.HistoryRecordType::AssistantMessage)
    "tool_call" => Some(@interfaces.HistoryRecordType::ToolCall)
    "tool_result" => Some(@interfaces.HistoryRecordType::ToolResult)
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
/// returns: e.g. "{base_dir}/history/2026/02/28"
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
/// returns: e.g. "{base_dir}/history/2026/02/28/web_chat-abc123-1709164800.jsonl"
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

///|
/// session_id (channel:chat_id) を分離する
/// "web_chat:abc-123" → ("web_chat", "abc-123")
/// コロンなしの場合は ("default", session_id) を返す
pub fn split_session_id(session_id : String) -> (String, String) {
  let channel_buf = StringBuilder::new()
  let chat_id_buf = StringBuilder::new()
  let mut found_colon = false
  for c in session_id {
    if !found_colon && c == ':' {
      found_colon = true
    } else if found_colon {
      chat_id_buf.write_char(c)
    } else {
      channel_buf.write_char(c)
    }
  }
  if found_colon {
    (channel_buf.to_string(), chat_id_buf.to_string())
  } else {
    ("default", session_id)
  }
}

///|
/// 文字列を非負整数にパース、失敗時は None を返す
/// 数字以外の文字を含む場合も None
pub fn parse_int_string(s : String) -> Int? {
  let mut result = 0
  if s.length() == 0 {
    return None
  }
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  Some(result)
}

///|
/// 履歴ファイル名をパースして (channel, chat_id, epoch_secs) を返す
/// e.g. "web_chat-abc-1709164800.jsonl" → Some(("web_chat", "abc", 1709164800L))
pub fn parse_history_filename(filename : String) -> (String, String, Int64)? {
  // .jsonl を除去
  if not(filename.has_suffix(".jsonl")) {
    return None
  }
  // .jsonl を除去 — StringBuilder で安全に切り出す
  let name_buf = StringBuilder::new()
  let fn_chars = filename.to_array()
  for i in 0..<(fn_chars.length() - 6) {
    name_buf.write_char(fn_chars[i])
  }
  let name = name_buf.to_string()
  // 最後の '-' で epoch_secs を分離
  let mut last_dash = -1
  let chars = name.to_array()
  for i in 0..<chars.length() {
    if chars[i] == '-' {
      last_dash = i
    }
  }
  if last_dash <= 0 {
    return None
  }
  let epoch_buf = StringBuilder::new()
  for i in (last_dash + 1)..<chars.length() {
    epoch_buf.write_char(chars[i])
  }
  let epoch_str = epoch_buf.to_string()
  let prefix_buf = StringBuilder::new()
  for i in 0..<last_dash {
    prefix_buf.write_char(chars[i])
  }
  let prefix = prefix_buf.to_string()
  // epoch_secs をパース
  let epoch_secs = @strconv.parse_int64(epoch_str) catch { _ => return None }
  // prefix の最初の '-' で channel と chat_id を分離
  let mut first_dash = -1
  let prefix_chars = prefix.to_array()
  for i in 0..<prefix_chars.length() {
    if prefix_chars[i] == '-' {
      first_dash = i
      break
    }
  }
  if first_dash <= 0 {
    return None
  }
  let ch_buf = StringBuilder::new()
  for i in 0..<first_dash {
    ch_buf.write_char(prefix_chars[i])
  }
  let channel = ch_buf.to_string()
  let ci_buf = StringBuilder::new()
  for i in (first_dash + 1)..<prefix_chars.length() {
    ci_buf.write_char(prefix_chars[i])
  }
  let chat_id = ci_buf.to_string()
  if channel.length() == 0 || chat_id.length() == 0 {
    return None
  }
  Some((channel, chat_id, epoch_secs))
}
