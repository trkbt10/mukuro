///|
/// History Metadata Store — mizchi/sqlite を利用した実装
/// セッションメタデータをSQLiteで管理する

// ============================================================
// NativeHistoryMetadataStore
// ============================================================

///|
/// SQLiteベースの履歴メタデータストア
pub struct NativeHistoryMetadataStore {
  db_path : String
  mut db : @sqlite.Database?
}

///|
/// メタデータストアを作成
pub fn NativeHistoryMetadataStore::new(
  db_path : String,
) -> NativeHistoryMetadataStore {
  NativeHistoryMetadataStore::{ db_path, db: None }
}

///|
/// デフォルトのデータベースパスを取得
pub fn default_metadata_db_path() -> String {
  let data_dir = @config.data_dir()
  "\{data_dir}/history/metadata.db"
}

// ============================================================
// スキーマ定義
// ============================================================

///|
/// スキーマ作成SQL
fn create_schema_sql() -> String {
  let sql =
    #|CREATE TABLE IF NOT EXISTS session_metadata (
    #|  session_id TEXT PRIMARY KEY,
    #|  channel TEXT NOT NULL,
    #|  chat_id TEXT NOT NULL,
    #|  title TEXT,
    #|  first_message TEXT,
    #|  message_count INTEGER DEFAULT 0,
    #|  user_message_count INTEGER DEFAULT 0,
    #|  assistant_message_count INTEGER DEFAULT 0,
    #|  tool_call_count INTEGER DEFAULT 0,
    #|  created_at INTEGER NOT NULL,
    #|  updated_at INTEGER NOT NULL,
    #|  file_path TEXT NOT NULL,
    #|  model_name TEXT
    #|);
    #|CREATE INDEX IF NOT EXISTS idx_session_created ON session_metadata(created_at DESC);
    #|CREATE INDEX IF NOT EXISTS idx_session_channel ON session_metadata(channel);
    #|CREATE INDEX IF NOT EXISTS idx_session_updated ON session_metadata(updated_at DESC);
  sql
}

// ============================================================
// HistoryMetadataStore 実装
// ============================================================

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with open(
  self,
) -> Unit raise @interfaces.MetadataStoreError {
  // ディレクトリが存在しない場合は作成
  let dir = get_parent_dir(self.db_path)
  if dir.length() > 0 {
    let _ = c_mkdir_recursive_bytes(string_to_utf8_cstring(dir), dir_permission)
  }
  // データベースを開く
  let db = match @sqlite.Database::open(self.db_path) {
    Some(d) => d
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to open metadata database: \{self.db_path}",
      )
  }
  self.db = Some(db)
  // スキーマを作成
  if not(db.exec(create_schema_sql())) {
    raise @interfaces.MetadataStoreError::DatabaseError(
      "Failed to create schema",
    )
  }
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with upsert(
  self,
  metadata~,
) -> Unit raise @interfaces.MetadataStoreError {
  let db = self.get_db() catch { e => raise e }
  let sql =
    #|INSERT INTO session_metadata (
    #|  session_id, channel, chat_id, title, first_message,
    #|  message_count, user_message_count, assistant_message_count, tool_call_count,
    #|  created_at, updated_at, file_path, model_name
    #|) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    #|ON CONFLICT(session_id) DO UPDATE SET
    #|  title = COALESCE(excluded.title, session_metadata.title),
    #|  first_message = COALESCE(session_metadata.first_message, excluded.first_message),
    #|  message_count = excluded.message_count,
    #|  user_message_count = excluded.user_message_count,
    #|  assistant_message_count = excluded.assistant_message_count,
    #|  tool_call_count = excluded.tool_call_count,
    #|  updated_at = excluded.updated_at,
    #|  file_path = excluded.file_path,
    #|  model_name = COALESCE(excluded.model_name, session_metadata.model_name)
  let stmt = match db.prepare(sql) {
    Some(s) => s
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to prepare upsert statement",
      )
  }
  // バインド
  let values : Array[@sqlite.SqlValue] = [
    text_value(metadata.session_id),
    text_value(metadata.channel),
    text_value(metadata.chat_id),
    text_or_null(metadata.title),
    text_or_null(metadata.first_message),
    @sqlite.SqlValue::Int64(metadata.message_count.to_int64()),
    @sqlite.SqlValue::Int64(metadata.user_message_count.to_int64()),
    @sqlite.SqlValue::Int64(metadata.assistant_message_count.to_int64()),
    @sqlite.SqlValue::Int64(metadata.tool_call_count.to_int64()),
    @sqlite.SqlValue::Int64(metadata.created_at),
    @sqlite.SqlValue::Int64(metadata.updated_at),
    text_value(metadata.file_path),
    text_or_null(metadata.model_name),
  ]
  if not(stmt.bind_all(values)) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError("Failed to bind values")
  }
  if not(stmt.execute()) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError(
      "Failed to execute upsert",
    )
  }
  stmt.finalize()
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with get(
  self,
  session_id~,
) -> @interfaces.SessionMetadata? raise @interfaces.MetadataStoreError {
  let db = self.get_db() catch { e => raise e }
  let sql =
    #|SELECT session_id, channel, chat_id, title, first_message,
    #|       message_count, user_message_count, assistant_message_count, tool_call_count,
    #|       created_at, updated_at, file_path, model_name
    #|FROM session_metadata WHERE session_id = ?
  let stmt = match db.prepare(sql) {
    Some(s) => s
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to prepare get statement",
      )
  }
  if not(stmt.bind(1, text_value(session_id))) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError(
      "Failed to bind session_id",
    )
  }
  if stmt.step() {
    let metadata = read_session_metadata(stmt)
    stmt.finalize()
    Some(metadata)
  } else {
    stmt.finalize()
    None
  }
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with increment_counts(
  self,
  session_id~,
  user~,
  assistant~,
  tool~,
) -> Unit raise @interfaces.MetadataStoreError {
  let db = self.get_db() catch { e => raise e }
  let sql =
    #|UPDATE session_metadata SET
    #|  message_count = message_count + ?,
    #|  user_message_count = user_message_count + ?,
    #|  assistant_message_count = assistant_message_count + ?,
    #|  tool_call_count = tool_call_count + ?,
    #|  updated_at = ?
    #|WHERE session_id = ?
  let stmt = match db.prepare(sql) {
    Some(s) => s
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to prepare increment statement",
      )
  }
  let total = user + assistant + tool
  let values : Array[@sqlite.SqlValue] = [
    @sqlite.SqlValue::Int64(total.to_int64()),
    @sqlite.SqlValue::Int64(user.to_int64()),
    @sqlite.SqlValue::Int64(assistant.to_int64()),
    @sqlite.SqlValue::Int64(tool.to_int64()),
    @sqlite.SqlValue::Int64(current_timestamp_ms()),
    text_value(session_id),
  ]
  if not(stmt.bind_all(values)) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError("Failed to bind values")
  }
  if not(stmt.execute()) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError(
      "Failed to execute increment",
    )
  }
  stmt.finalize()
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with update_title(
  self,
  session_id~,
  title~,
) -> Unit raise @interfaces.MetadataStoreError {
  let db = self.get_db() catch { e => raise e }
  let sql =
    #|UPDATE session_metadata SET title = ?, updated_at = ? WHERE session_id = ?
  let stmt = match db.prepare(sql) {
    Some(s) => s
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to prepare update_title statement",
      )
  }
  let values : Array[@sqlite.SqlValue] = [
    text_value(title),
    @sqlite.SqlValue::Int64(current_timestamp_ms()),
    text_value(session_id),
  ]
  if not(stmt.bind_all(values)) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError("Failed to bind values")
  }
  if not(stmt.execute()) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError(
      "Failed to execute update_title",
    )
  }
  stmt.finalize()
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with set_first_message(
  self,
  session_id~,
  message~,
) -> Unit raise @interfaces.MetadataStoreError {
  let db = self.get_db() catch { e => raise e }
  // first_message が NULL の場合のみ更新
  let sql =
    #|UPDATE session_metadata SET first_message = ?, updated_at = ?
    #|WHERE session_id = ? AND first_message IS NULL
  let stmt = match db.prepare(sql) {
    Some(s) => s
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to prepare set_first_message statement",
      )
  }
  let values : Array[@sqlite.SqlValue] = [
    text_value(message),
    @sqlite.SqlValue::Int64(current_timestamp_ms()),
    text_value(session_id),
  ]
  if not(stmt.bind_all(values)) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError("Failed to bind values")
  }
  if not(stmt.execute()) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError(
      "Failed to execute set_first_message",
    )
  }
  stmt.finalize()
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with list_by_date(
  self,
  year~,
  month~,
  day~,
) -> Array[@interfaces.SessionMetadata] raise @interfaces.MetadataStoreError {
  let db = self.get_db() catch { e => raise e }
  // 指定日の0:00:00から23:59:59.999までのタイムスタンプ範囲を計算
  let (start_ts, end_ts) = date_to_timestamp_range(year, month, day)
  let sql =
    #|SELECT session_id, channel, chat_id, title, first_message,
    #|       message_count, user_message_count, assistant_message_count, tool_call_count,
    #|       created_at, updated_at, file_path, model_name
    #|FROM session_metadata
    #|WHERE created_at >= ? AND created_at < ?
    #|ORDER BY created_at DESC
  let stmt = match db.prepare(sql) {
    Some(s) => s
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to prepare list_by_date statement",
      )
  }
  let values : Array[@sqlite.SqlValue] = [
    @sqlite.SqlValue::Int64(start_ts),
    @sqlite.SqlValue::Int64(end_ts),
  ]
  if not(stmt.bind_all(values)) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError("Failed to bind values")
  }
  let results : Array[@interfaces.SessionMetadata] = []
  while stmt.step() {
    results.push(read_session_metadata(stmt))
  }
  stmt.finalize()
  results
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with list_recent(
  self,
  limit~,
  offset~,
) -> Array[@interfaces.SessionMetadata] raise @interfaces.MetadataStoreError {
  let db = self.get_db() catch { e => raise e }
  let sql =
    #|SELECT session_id, channel, chat_id, title, first_message,
    #|       message_count, user_message_count, assistant_message_count, tool_call_count,
    #|       created_at, updated_at, file_path, model_name
    #|FROM session_metadata
    #|ORDER BY updated_at DESC
    #|LIMIT ? OFFSET ?
  let stmt = match db.prepare(sql) {
    Some(s) => s
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to prepare list_recent statement",
      )
  }
  let values : Array[@sqlite.SqlValue] = [
    @sqlite.SqlValue::Int64(limit.to_int64()),
    @sqlite.SqlValue::Int64(offset.to_int64()),
  ]
  if not(stmt.bind_all(values)) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError("Failed to bind values")
  }
  let results : Array[@interfaces.SessionMetadata] = []
  while stmt.step() {
    results.push(read_session_metadata(stmt))
  }
  stmt.finalize()
  results
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with search(
  self,
  query~,
  limit~,
) -> Array[@interfaces.SessionMetadata] raise @interfaces.MetadataStoreError {
  let db = self.get_db() catch { e => raise e }
  // シンプルなLIKE検索（title, first_message, session_id）
  let sql =
    #|SELECT session_id, channel, chat_id, title, first_message,
    #|       message_count, user_message_count, assistant_message_count, tool_call_count,
    #|       created_at, updated_at, file_path, model_name
    #|FROM session_metadata
    #|WHERE title LIKE ? OR first_message LIKE ? OR session_id LIKE ?
    #|ORDER BY updated_at DESC
    #|LIMIT ?
  let stmt = match db.prepare(sql) {
    Some(s) => s
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to prepare search statement",
      )
  }
  let pattern = "%\{query}%"
  let values : Array[@sqlite.SqlValue] = [
    text_value(pattern),
    text_value(pattern),
    text_value(pattern),
    @sqlite.SqlValue::Int64(limit.to_int64()),
  ]
  if not(stmt.bind_all(values)) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError("Failed to bind values")
  }
  let results : Array[@interfaces.SessionMetadata] = []
  while stmt.step() {
    results.push(read_session_metadata(stmt))
  }
  stmt.finalize()
  results
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with delete(
  self,
  session_id~,
) -> Unit raise @interfaces.MetadataStoreError {
  let db = self.get_db() catch { e => raise e }
  let sql =
    #|DELETE FROM session_metadata WHERE session_id = ?
  let stmt = match db.prepare(sql) {
    Some(s) => s
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Failed to prepare delete statement",
      )
  }
  if not(stmt.bind(1, text_value(session_id))) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError(
      "Failed to bind session_id",
    )
  }
  if not(stmt.execute()) {
    stmt.finalize()
    raise @interfaces.MetadataStoreError::DatabaseError(
      "Failed to execute delete",
    )
  }
  stmt.finalize()
}

///|
pub impl @interfaces.HistoryMetadataStore for NativeHistoryMetadataStore with close(
  self,
) -> Unit {
  match self.db {
    Some(db) => {
      db.close()
      self.db = None
    }
    None => ()
  }
}

// ============================================================
// 内部ヘルパー関数
// ============================================================

///|
/// DBハンドルを取得（初期化チェック付き）
fn NativeHistoryMetadataStore::get_db(
  self : NativeHistoryMetadataStore,
) -> @sqlite.Database raise @interfaces.MetadataStoreError {
  match self.db {
    Some(db) => db
    None =>
      raise @interfaces.MetadataStoreError::DatabaseError(
        "Database not opened. Call open() first.",
      )
  }
}

///|
/// 文字列をSqlValue::Textに変換
fn text_value(s : String) -> @sqlite.SqlValue {
  @sqlite.SqlValue::Text(@utf8.encode(s))
}

///|
/// 文字列?をSqlValue (TextまたはNull)に変換
fn text_or_null(s : String?) -> @sqlite.SqlValue {
  match s {
    Some(v) => @sqlite.SqlValue::Text(@utf8.encode(v))
    None => @sqlite.SqlValue::Null
  }
}

///|
/// BytesをStringに変換
fn bytes_to_string(b : Bytes) -> String {
  @bytes.decode_utf8_or(b.view(), default="")
}

///|
/// SqlValueからString?を取得
fn get_text_or_none(value : @sqlite.SqlValue) -> String? {
  match value {
    @sqlite.SqlValue::Text(b) => Some(bytes_to_string(b))
    _ => None
  }
}

///|
/// SqlValueからStringを取得
fn get_text(value : @sqlite.SqlValue) -> String {
  match value {
    @sqlite.SqlValue::Text(b) => bytes_to_string(b)
    _ => ""
  }
}

///|
/// SqlValueからInt64を取得
fn get_int64(value : @sqlite.SqlValue) -> Int64 {
  match value {
    @sqlite.SqlValue::Int64(v) => v
    @sqlite.SqlValue::Int(v) => v.to_int64()
    _ => 0L
  }
}

///|
/// 結果行からSessionMetadataを読み取る
fn read_session_metadata(
  stmt : @sqlite.Statement,
) -> @interfaces.SessionMetadata {
  @interfaces.SessionMetadata::{
    session_id: get_text(stmt.column(0)),
    channel: get_text(stmt.column(1)),
    chat_id: get_text(stmt.column(2)),
    title: get_text_or_none(stmt.column(3)),
    first_message: get_text_or_none(stmt.column(4)),
    message_count: get_int64(stmt.column(5)).to_int(),
    user_message_count: get_int64(stmt.column(6)).to_int(),
    assistant_message_count: get_int64(stmt.column(7)).to_int(),
    tool_call_count: get_int64(stmt.column(8)).to_int(),
    created_at: get_int64(stmt.column(9)),
    updated_at: get_int64(stmt.column(10)),
    file_path: get_text(stmt.column(11)),
    model_name: get_text_or_none(stmt.column(12)),
  }
}

///|
/// パスから親ディレクトリを取得
fn get_parent_dir(path : String) -> String {
  let mut last_slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '/' {
      last_slash = i
    }
  }
  if last_slash > 0 {
    // Use StringBuilder to avoid raising slice operations
    let sb = StringBuilder::new()
    for i = 0; i < last_slash; i = i + 1 {
      sb.write_char(path[i].to_int().unsafe_to_char())
    }
    sb.to_string()
  } else {
    ""
  }
}

///|
/// 現在時刻をミリ秒で取得
fn current_timestamp_ms() -> Int64 {
  // c_time() は秒単位なので1000倍
  c_time() * 1000L
}

///|
/// 日付からタイムスタンプ範囲を計算（UTC）
/// 戻り値: (start_ms, end_ms) — start <= ts < end
fn date_to_timestamp_range(
  year : Int,
  month : Int,
  day : Int,
) -> (Int64, Int64) {
  // 簡易計算: 各月の日数を考慮した経過日数からタイムスタンプを算出
  // 1970-01-01 00:00:00 UTC = 0
  let days_since_epoch = days_from_epoch(year, month, day)
  let start_ms = days_since_epoch * 86400L * 1000L
  let end_ms = (days_since_epoch + 1L) * 86400L * 1000L
  (start_ms, end_ms)
}

///|
/// 1970-01-01からの経過日数を計算
fn days_from_epoch(year : Int, month : Int, day : Int) -> Int64 {
  // 簡易実装: 閏年を考慮
  let mut days = 0L
  // 年の計算
  for y = 1970; y < year; y = y + 1 {
    let year_days = if is_leap_year(y) { 366L } else { 365L }
    days = days + year_days
  }
  // 月の計算
  let days_in_month : FixedArray[Int] = [
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
  ]
  for m = 1; m < month; m = m + 1 {
    let d = days_in_month[m - 1]
    days = days + d.to_int64()
    if m == 2 && is_leap_year(year) {
      days = days + 1L
    }
  }
  // 日の計算
  days = days + (day - 1).to_int64()
  days
}

///|
/// 閏年判定
fn is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

// ============================================================
// Migration: Rebuild metadata from JSONL files
// ============================================================

///|
/// 既存のJSONLファイルからメタデータを再構築
/// 戻り値: 処理したセッション数
pub fn rebuild_metadata_from_jsonl(
  store : &@interfaces.HistoryMetadataStore,
  base_dir : String,
) -> Int {
  let history_root = "\{base_dir}/history"
  let mut count = 0
  // Traverse year/month/day directories
  for year_name in native_list_dir_entries(history_root) {
    let year = match @history.parse_int_string(year_name) {
      Some(y) => y
      None => continue
    }
    let year_path = "\{history_root}/\{year_name}"
    for month_name in native_list_dir_entries(year_path) {
      let month = match @history.parse_int_string(month_name) {
        Some(m) => m
        None => continue
      }
      let month_path = "\{year_path}/\{month_name}"
      for day_name in native_list_dir_entries(month_path) {
        let day = match @history.parse_int_string(day_name) {
          Some(d) => d
          None => continue
        }
        let day_path = "\{month_path}/\{day_name}"
        for filename in native_list_dir_entries(day_path) {
          if filename.has_suffix(".jsonl") {
            let file_path = "\{day_path}/\{filename}"
            if process_jsonl_for_migration(
                store, file_path, filename, year, month, day,
              ) {
              count = count + 1
            }
          }
        }
      }
    }
  }
  count
}

///|
/// 単一のJSONLファイルを処理してメタデータを抽出
fn process_jsonl_for_migration(
  store : &@interfaces.HistoryMetadataStore,
  file_path : String,
  filename : String,
  _year : Int,
  _month : Int,
  _day : Int,
) -> Bool {
  // ファイル名をパース: {channel}-{chat_id}-{epoch}.jsonl
  let parsed = @history.parse_history_filename(filename)
  let (channel, chat_id, epoch_secs) = match parsed {
    Some((c, id, ts)) => (c, id, ts)
    None => return false
  }
  let session_id = "\{channel}:\{chat_id}"
  // ファイル内容を読み取り
  let content = native_read_file_text(file_path) catch { _ => return false }
  // レコードをカウント
  let mut user_count = 0
  let mut assistant_count = 0
  let mut tool_count = 0
  let mut first_message : String? = None
  let mut model_name : String? = None
  for line in content.split("\n") {
    let s = line.to_string()
    if s.length() > 0 {
      match @history.parse_json_to_record(s) {
        Some(record) =>
          match record.record_type {
            @interfaces.HistoryRecordType::UserMessage => {
              user_count = user_count + 1
              if first_message is None {
                let msg = extract_content_from_payload(record.payload)
                if msg.length() > 0 {
                  first_message = Some(
                    if msg.length() > 100 {
                      trim_string(msg, 100)
                    } else {
                      msg
                    },
                  )
                }
              }
            }
            @interfaces.HistoryRecordType::AssistantMessage =>
              assistant_count = assistant_count + 1
            @interfaces.HistoryRecordType::ToolCall =>
              tool_count = tool_count + 1
            @interfaces.HistoryRecordType::SessionMeta => {
              // SessionMetaからmodel_nameを抽出
              let m = extract_model_from_payload(record.payload)
              if m.length() > 0 {
                model_name = Some(m)
              }
            }
            _ => ()
          }
        None => ()
      }
    }
  }
  let total = user_count + assistant_count + tool_count
  let created_at = epoch_secs * 1000L
  // メタデータを作成してupsert
  let metadata = @interfaces.SessionMetadata::{
    session_id,
    channel,
    chat_id,
    title: None,
    first_message,
    message_count: total,
    user_message_count: user_count,
    assistant_message_count: assistant_count,
    tool_call_count: tool_count,
    created_at,
    updated_at: created_at,
    file_path,
    model_name,
  }
  store.upsert(metadata~) catch {
    _ => return false
  }
  true
}

///|
/// PayloadからcontentフィールドのString値を抽出
fn extract_content_from_payload(payload : Json) -> String {
  match payload {
    Object(obj) =>
      match obj.get("content") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
}

///|
/// PayloadからmodelフィールドのString値を抽出
fn extract_model_from_payload(payload : Json) -> String {
  match payload {
    Object(obj) =>
      match obj.get("model") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
}
