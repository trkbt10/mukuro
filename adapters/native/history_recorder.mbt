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
}

///|
pub fn NativeHistoryRecorder::new(base_dir~ : String) -> NativeHistoryRecorder {
  {
    base_dir,
    current_file_handle: 0L,
    current_file_path: "",
    session_id: "",
    initialized: false,
  }
}

///|
pub impl @interfaces.HistoryRecorder for NativeHistoryRecorder with init_session(
  self,
  session_id~,
  timestamp~,
) -> Unit raise @interfaces.HistoryError {
  // 既存セッションがあればフラッシュ
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
  if c_mkdir_recursive(string_to_cstring(dir_path), dir_permission) != 0 {
    raise @interfaces.HistoryError::DirectoryCreationFailed(dir_path)
  }
  let (channel, chat_id) = @history.split_session_id(session_id)
  let safe_channel = @history.sanitize_path_segment(channel)
  let safe_chat_id = @history.sanitize_path_segment(chat_id)
  let file_prefix = "\{safe_channel}-\{safe_chat_id}-"
  // 既存のセッションファイルがあれば追記、なければ新規作成
  let file_path = match native_find_file_with_prefix(dir_path, file_prefix, ".jsonl") {
    Some(existing) => existing
    None =>
      @history.history_file_path(
        self.base_dir, channel, chat_id, year, month, day, epoch_secs,
      )
  }
  let handle = c_fopen_handle(
    string_to_utf8_cstring(file_path),
    string_to_utf8_cstring("a"),
  )
  if handle == 0L {
    raise @interfaces.HistoryError::IoError(
      "Cannot open history file: \{file_path}",
    )
  }
  self.current_file_handle = handle
  self.current_file_path = file_path
  self.initialized = true
}

///|
pub impl @interfaces.HistoryRecorder for NativeHistoryRecorder with record(
  self,
  record~,
) -> Unit raise @interfaces.HistoryError {
  if self.current_file_handle == 0L {
    raise @interfaces.HistoryError::IoError(
      "History recorder not initialized",
    )
  }
  let data = @utf8.encode(@history.record_to_json_line(record) + "\n")
  let written = c_fwrite_handle(
    data, 1, data.length(), self.current_file_handle,
  )
  if written != data.length() {
    raise @interfaces.HistoryError::IoError(
      "Write failed: wrote \{written}/\{data.length()} bytes",
    )
  }
  let _ = c_fflush_handle(self.current_file_handle)
}

///|
pub impl @interfaces.HistoryRecorder for NativeHistoryRecorder with flush(self) -> Unit raise @interfaces.HistoryError {
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
}

///|
pub fn NativeHistoryReader::new(base_dir~ : String) -> NativeHistoryReader {
  { base_dir, }
}

///|
pub impl @interfaces.HistoryReader for NativeHistoryReader with read_session(
  self,
  session_id~,
) -> Array[@interfaces.HistoryRecord] raise @interfaces.HistoryError {
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
pub impl @interfaces.HistoryReader for NativeHistoryReader with list_dates(self) -> Array[(Int, Int, Int)] raise @interfaces.HistoryError {
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
