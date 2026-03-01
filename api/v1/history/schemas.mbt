///|
/// History API Schema Types

///|
/// 日付エントリ（セッション数付き）
pub(all) struct HistoryDateEntry {
  year : Int
  month : Int
  day : Int
  session_count : Int
} derive(Show, Eq)

///|
pub impl ToJson for HistoryDateEntry with to_json(self) {
  {
    "year": self.year.to_json(),
    "month": self.month.to_json(),
    "day": self.day.to_json(),
    "session_count": self.session_count.to_json(),
  }
}

///|
/// セッションサマリー
pub(all) struct HistorySessionSummary {
  session_id : String
  channel : String
  chat_id : String
  filename : String
  started_at : Int64
  record_count : Int
  /// メタデータから取得されるオプショナルフィールド
  title : String?
  first_message : String?
  message_count : Int
  user_message_count : Int
  assistant_message_count : Int
  tool_call_count : Int
  model_name : String?
} derive(Show, Eq)

///|
pub impl ToJson for HistorySessionSummary with to_json(self) {
  let obj : Map[String, Json] = {
    "session_id": self.session_id.to_json(),
    "channel": self.channel.to_json(),
    "chat_id": self.chat_id.to_json(),
    "filename": self.filename.to_json(),
    "started_at": self.started_at.to_double().to_json(),
    "record_count": self.record_count.to_json(),
    "message_count": self.message_count.to_json(),
    "user_message_count": self.user_message_count.to_json(),
    "assistant_message_count": self.assistant_message_count.to_json(),
    "tool_call_count": self.tool_call_count.to_json(),
  }
  match self.title {
    Some(t) => obj["title"] = t.to_json()
    None => ()
  }
  match self.first_message {
    Some(m) => obj["first_message"] = m.to_json()
    None => ()
  }
  match self.model_name {
    Some(m) => obj["model_name"] = m.to_json()
    None => ()
  }
  Json::object(obj)
}

///|
/// SessionMetadata から HistorySessionSummary を作成
pub fn session_summary_from_metadata(
  meta : @interfaces.SessionMetadata,
) -> HistorySessionSummary {
  {
    session_id: meta.session_id,
    channel: meta.channel,
    chat_id: meta.chat_id,
    filename: extract_filename(meta.file_path),
    started_at: meta.created_at,
    record_count: meta.message_count,
    title: meta.title,
    first_message: meta.first_message,
    message_count: meta.message_count,
    user_message_count: meta.user_message_count,
    assistant_message_count: meta.assistant_message_count,
    tool_call_count: meta.tool_call_count,
    model_name: meta.model_name,
  }
}

///|
/// ファイルパスからファイル名を抽出
fn extract_filename(path : String) -> String {
  let mut last_slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '/' {
      last_slash = i
    }
  }
  if last_slash >= 0 && last_slash < path.length() - 1 {
    let sb = StringBuilder::new()
    for i = last_slash + 1; i < path.length(); i = i + 1 {
      sb.write_char(path[i].to_int().unsafe_to_char())
    }
    sb.to_string()
  } else {
    path
  }
}

///|
/// 履歴レコードJSON表現
pub(all) struct HistoryRecordJson {
  timestamp : Int64
  record_type : String
  payload : Json
} derive(Show, Eq)

///|
pub impl ToJson for HistoryRecordJson with to_json(self) {
  {
    "timestamp": self.timestamp.to_double().to_json(),
    "record_type": self.record_type.to_json(),
    "payload": self.payload,
  }
}

///|
/// HistoryRecord → HistoryRecordJson 変換
pub fn history_record_to_json(record : @interfaces.HistoryRecord) -> HistoryRecordJson {
  {
    timestamp: record.timestamp,
    record_type: @core_history.record_type_to_string(record.record_type),
    payload: record.payload,
  }
}
