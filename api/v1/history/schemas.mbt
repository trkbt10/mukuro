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
} derive(Show, Eq)

///|
pub impl ToJson for HistorySessionSummary with to_json(self) {
  {
    "session_id": self.session_id.to_json(),
    "channel": self.channel.to_json(),
    "chat_id": self.chat_id.to_json(),
    "filename": self.filename.to_json(),
    "started_at": self.started_at.to_double().to_json(),
    "record_count": self.record_count.to_json(),
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
