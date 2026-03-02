///|
/// Native JSONL 履歴レコーダー / リーダー
/// ファイルシステムに JSONL 形式で会話・ツール実行ログを蓄積・読み取りする

// ============================================================
// NativeHistoryRecorder — セッション単位で JSONL ファイルに追記
// ============================================================

///|
pub struct NativeHistoryRecorder {
  base_dir : String
  /// ファイルハンドル（0 = 未オープン）
  mut current_file_handle : Int64
  mut current_file_path : String
  mut session_id : String
  mut initialized : Bool
  /// メタデータストア（オプション）
  metadata_store : &@interfaces.HistoryMetadataStore?
  /// 最初のユーザーメッセージかどうか
  mut is_first_user_message : Bool
}

///|
pub fn NativeHistoryRecorder::new(base_dir~ : String) -> NativeHistoryRecorder {
  {
    base_dir,
    current_file_handle: 0L,
    current_file_path: "",
    session_id: "",
    initialized: false,
    metadata_store: None,
    is_first_user_message: true,
  }
}

///|
/// メタデータストア付きでレコーダーを作成
pub fn NativeHistoryRecorder::new_with_metadata_store(
  base_dir~ : String,
  metadata_store~ : &@interfaces.HistoryMetadataStore,
) -> NativeHistoryRecorder {
  {
    base_dir,
    current_file_handle: 0L,
    current_file_path: "",
    session_id: "",
    initialized: false,
    metadata_store: Some(metadata_store),
    is_first_user_message: true,
  }
}

///|
pub impl @interfaces.HistoryRecorder for NativeHistoryRecorder with open_session(
  self,
  session_id~,
  timestamp~,
) -> Bool raise @interfaces.HistoryError {
  // 既存セッションがあればクローズ
  if self.initialized && self.current_file_handle != 0L {
    let _ = c_fclose_handle(self.current_file_handle)
    self.current_file_handle = 0L
  }
  self.session_id = session_id
  let epoch_secs = timestamp / 1000L
  let (year, month, day) = native_epoch_to_date(epoch_secs) catch {
    FileSystemError::IoError(msg) =>
      raise @interfaces.HistoryError::IoError(msg)
    _ => raise @interfaces.HistoryError::IoError("Failed to get date")
  }
  let dir_path = @history.history_dir_for_date(self.base_dir, year, month, day)
  if c_mkdir_recursive_bytes(string_to_utf8_cstring(dir_path), dir_permission) !=
    0 {
    raise @interfaces.HistoryError::DirectoryCreationFailed(dir_path)
  }
  let (channel, chat_id) = @history.split_session_id(session_id)
  let safe_channel = @history.sanitize_path_segment(channel)
  let safe_chat_id = @history.sanitize_path_segment(chat_id)
  let file_prefix = "\{safe_channel}-\{safe_chat_id}-"
  // 既存のセッションファイルがあれば追記、なければ新規作成
  let (file_path, is_new_session) = match
    native_find_file_with_prefix(dir_path, file_prefix, ".jsonl") {
    Some(existing) => (existing, false)
    None =>
      (
        @history.history_file_path(
          self.base_dir,
          channel,
          chat_id,
          year,
          month,
          day,
          epoch_secs,
        ),
        true,
      )
  }
  let handle = c_fopen_handle(
    string_to_utf8_cstring(file_path),
    string_to_utf8_cstring("a"),
  )
  if handle == 0L {
    // errno をチェックしてより具体的なエラーを返す
    let errno_val = c_get_errno()
    let reason = match errno_val {
      13 => "permission denied"
      2 => "no such file or directory"
      28 => "no space left on device"
      24 => "too many open files"
      _ => "errno=\{errno_val}"
    }
    raise @interfaces.HistoryError::FileOpenFailed(path=file_path, reason~)
  }
  self.current_file_handle = handle
  self.current_file_path = file_path
  self.initialized = true
  self.is_first_user_message = true
  // メタデータストアがあれば登録
  match self.metadata_store {
    Some(store) => {
      let metadata = @interfaces.SessionMetadata::{
        session_id,
        channel,
        chat_id,
        title: None,
        first_message: None,
        message_count: 0,
        user_message_count: 0,
        assistant_message_count: 0,
        tool_call_count: 0,
        created_at: timestamp,
        updated_at: timestamp,
        file_path,
        model_name: None,
      }
      store.upsert(metadata~) catch {
        _ => ()
      } // メタデータ更新失敗は無視
    }
    None => ()
  }
  is_new_session
}

///|
pub impl @interfaces.HistoryRecorder for NativeHistoryRecorder with record(
  self,
  record~,
) -> Unit raise @interfaces.HistoryError {
  if self.current_file_handle == 0L {
    raise @interfaces.HistoryError::NotInitialized
  }
  let data = @utf8.encode(@history.record_to_json_line(record) + "\n")
  let written = c_fwrite_handle(
    data,
    1,
    data.length(),
    self.current_file_handle,
  )
  if written != data.length() {
    raise @interfaces.HistoryError::WriteFailed(
      expected=data.length(),
      actual=written,
    )
  }
  let _ = c_fflush_handle(self.current_file_handle)
  // メタデータストアがあればカウント更新
  match self.metadata_store {
    Some(store) =>
      update_metadata_for_record(store, self.session_id, record, self)
    None => ()
  }
}

///|
/// レコードタイプに応じてメタデータを更新
fn update_metadata_for_record(
  store : &@interfaces.HistoryMetadataStore,
  session_id : String,
  record : @interfaces.HistoryRecord,
  recorder : NativeHistoryRecorder,
) -> Unit {
  match record.record_type {
    @interfaces.HistoryRecordType::UserMessage => {
      store.increment_counts(session_id~, user=1, assistant=0, tool=0) catch {
        _ => ()
      }
      // 最初のユーザーメッセージなら first_message を設定
      if recorder.is_first_user_message {
        recorder.is_first_user_message = false
        // payloadからcontentを抽出
        let content = extract_message_content(record.payload)
        if content.length() > 0 {
          // 最大100文字でトリム
          let trimmed = if content.length() > 100 {
            trim_string(content, 100)
          } else {
            content
          }
          store.set_first_message(session_id~, message=trimmed) catch {
            _ => ()
          }
        }
      }
    }
    @interfaces.HistoryRecordType::AssistantMessage =>
      store.increment_counts(session_id~, user=0, assistant=1, tool=0) catch {
        _ => ()
      }
    @interfaces.HistoryRecordType::ToolCall =>
      store.increment_counts(session_id~, user=0, assistant=0, tool=1) catch {
        _ => ()
      }
    @interfaces.HistoryRecordType::SessionMeta => {
      // SessionMeta から model_name を抽出して SQLite に保存
      let model = extract_model_from_payload(record.payload)
      if model.length() > 0 {
        store.update_model_name(session_id~, model_name=model) catch {
          _ => ()
        }
      }
    }
    _ => () // ToolResult, Error は無視
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

///|
/// JSONペイロードからメッセージ内容を抽出
fn extract_message_content(payload : Json) -> String {
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
/// 文字列を指定長で切り詰める
fn trim_string(s : String, max_len : Int) -> String {
  let sb = StringBuilder::new()
  let mut count = 0
  for i = 0; i < s.length() && count < max_len; i = i + 1 {
    sb.write_char(s[i].to_int().unsafe_to_char())
    count = count + 1
  }
  sb.to_string()
}

///|
pub impl @interfaces.HistoryRecorder for NativeHistoryRecorder with close(self) -> Unit raise @interfaces.HistoryError {
  if self.current_file_handle != 0L {
    let _ = c_fclose_handle(self.current_file_handle)
    self.current_file_handle = 0L
    self.initialized = false
  }
}

// ============================================================
// NativeHistoryReader — ファイルシステムから JSONL 履歴を読み取る
// ============================================================

///|
pub struct NativeHistoryReader {
  base_dir : String
  /// メタデータストア（オプション）
  metadata_store : &@interfaces.HistoryMetadataStore?
}

///|
pub fn NativeHistoryReader::new(base_dir~ : String) -> NativeHistoryReader {
  { base_dir, metadata_store: None }
}

///|
/// メタデータストア付きでリーダーを作成
pub fn NativeHistoryReader::new_with_metadata_store(
  base_dir~ : String,
  metadata_store~ : &@interfaces.HistoryMetadataStore,
) -> NativeHistoryReader {
  { base_dir, metadata_store: Some(metadata_store) }
}

///|
pub impl @interfaces.HistoryReader for NativeHistoryReader with read_session(
  self,
  session_id~,
) -> Array[@interfaces.HistoryRecord] raise @interfaces.HistoryError {
  // メタデータストアがあれば、file_pathから直接読み取り
  match self.metadata_store {
    Some(store) => {
      let metadata = store.get(session_id~) catch { _ => None }
      match metadata {
        Some(meta) => {
          let records : Array[@interfaces.HistoryRecord] = []
          let content = native_read_file_text(meta.file_path) catch { _ => "" }
          if content.length() > 0 {
            parse_jsonl_records(content, records)
          }
          return records
        }
        None => () // フォールバックして従来の検索を使う
      }
    }
    None => ()
  }
  // 従来の検索方式（メタデータがない場合）
  let (channel, chat_id) = @history.split_session_id(session_id)
  let safe_channel = @history.sanitize_path_segment(channel)
  let safe_chat_id = @history.sanitize_path_segment(chat_id)
  let file_prefix = "\{safe_channel}-\{safe_chat_id}-"
  let records : Array[@interfaces.HistoryRecord] = []
  let history_root = "\{self.base_dir}/history"
  for year_name in native_list_dir_entries(history_root) {
    let year_path = "\{history_root}/\{year_name}"
    for month_name in native_list_dir_entries(year_path) {
      let month_path = "\{year_path}/\{month_name}"
      for day_name in native_list_dir_entries(month_path) {
        let day_path = "\{month_path}/\{day_name}"
        for file_name in native_list_dir_entries(day_path) {
          if file_name.has_prefix(file_prefix) && file_name.has_suffix(".jsonl") {
            let content = native_read_file_text("\{day_path}/\{file_name}") catch {
              _ => continue
            }
            parse_jsonl_records(content, records)
          }
        }
      }
    }
  }
  records
}

///|
pub impl @interfaces.HistoryReader for NativeHistoryReader with list_sessions(
  self,
  year~,
  month~,
  day~,
) -> Array[String] raise @interfaces.HistoryError {
  let dir_path = @history.history_dir_for_date(self.base_dir, year, month, day)
  let sessions : Array[String] = []
  for name in native_list_dir_entries(dir_path) {
    if name.has_suffix(".jsonl") {
      sessions.push(name)
    }
  }
  sessions
}

///|
pub impl @interfaces.HistoryReader for NativeHistoryReader with list_dates(self) -> Array[
  (Int, Int, Int),
] raise @interfaces.HistoryError {
  let dates : Array[(Int, Int, Int)] = []
  let history_root = "\{self.base_dir}/history"
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
        let mut has_files = false
        for file_name in native_list_dir_entries(day_path) {
          if file_name.has_suffix(".jsonl") {
            has_files = true
            break
          }
        }
        if has_files {
          dates.push((year, month, day))
        }
      }
    }
  }
  dates
}

// ============================================================
// History固有ヘルパー
// ============================================================

///|
/// JSONL テキストをパースして records 配列に追加する
fn parse_jsonl_records(
  content : String,
  records : Array[@interfaces.HistoryRecord],
) -> Unit {
  for line in content.split("\n") {
    let s = line.to_string()
    if s.length() > 0 {
      match @history.parse_json_to_record(s) {
        Some(record) => records.push(record)
        None => ()
      }
    }
  }
}
