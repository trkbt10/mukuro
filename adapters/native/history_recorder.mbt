///|
/// Native JSONL 履歴レコーダー
/// ファイルシステムに JSONL 形式で会話・ツール実行ログを蓄積する

///|
/// NativeHistoryRecorder
/// セッション単位で JSONL ファイルに追記する
pub struct NativeHistoryRecorder {
  /// ベースディレクトリ（@config.data_dir() で解決）
  base_dir : String
  /// 現在のファイルハンドル
  mut current_file : CFile?
  /// 現在のファイルパス
  mut current_file_path : String
  /// セッションID
  mut session_id : String
  /// 初期化済みフラグ
  mut initialized : Bool
}

///|
pub fn NativeHistoryRecorder::new(base_dir~ : String) -> NativeHistoryRecorder {
  {
    base_dir,
    current_file: None,
    current_file_path: "",
    session_id: "",
    initialized: false,
  }
}

///|
/// c_gmtime の出力バッファから年月日を読み取る
fn read_gmtime_result(buf : Bytes) -> (Int, Int, Int) {
  // リトルエンディアン int32 を読み取る
  let year = buf[0].to_int() |
    (buf[1].to_int() << 8) |
    (buf[2].to_int() << 16) |
    (buf[3].to_int() << 24)
  let month = buf[4].to_int() |
    (buf[5].to_int() << 8) |
    (buf[6].to_int() << 16) |
    (buf[7].to_int() << 24)
  let day = buf[8].to_int() |
    (buf[9].to_int() << 8) |
    (buf[10].to_int() << 16) |
    (buf[11].to_int() << 24)
  (year, month, day)
}

///|
pub impl @interfaces.HistoryRecorder for NativeHistoryRecorder with init_session(
  self,
  session_id~,
  timestamp~,
) -> Unit raise @interfaces.HistoryError {
  // 既存セッションがあればフラッシュ
  if self.initialized {
    match self.current_file {
      Some(file) => {
        let _ = c_fclose(file)
        self.current_file = None
      }
      None => ()
    }
  }
  self.session_id = session_id
  // timestamp（ミリ秒）からepoch秒を取得
  let epoch_secs = timestamp / 1000L
  // gmtime で年月日を取得
  let date_buf = Bytes::new(12)
  let gmtime_result = c_gmtime(epoch_secs, date_buf)
  if gmtime_result != 0 {
    raise @interfaces.HistoryError::IoError("Failed to get date from timestamp")
  }
  let (year, month, day) = read_gmtime_result(date_buf)
  // ディレクトリパスを構築
  let dir_path = @history.history_dir_for_date(self.base_dir, year, month, day)
  // 再帰的にディレクトリ作成
  let mkdir_result = c_mkdir_recursive(string_to_cstring(dir_path), 493) // 0o755
  if mkdir_result != 0 {
    raise @interfaces.HistoryError::DirectoryCreationFailed(dir_path)
  }
  // channel と chat_id を session_id から分離
  let (channel, chat_id) = split_session_id(session_id)
  // ファイルパスを構築
  let file_path = @history.history_file_path(
    self.base_dir,
    channel,
    chat_id,
    year,
    month,
    day,
    epoch_secs,
  )
  // 追記モードでファイルオープン
  match c_fopen(string_to_cstring(file_path), string_to_cstring("a")) {
    Some(f) => {
      self.current_file = Some(f)
      self.current_file_path = file_path
      self.initialized = true
    }
    None =>
      raise @interfaces.HistoryError::IoError(
        "Cannot open history file: \{file_path}",
      )
  }
}

///|
pub impl @interfaces.HistoryRecorder for NativeHistoryRecorder with record(
  self,
  record~,
) -> Unit raise @interfaces.HistoryError {
  match self.current_file {
    Some(file) => {
      let line = @history.record_to_json_line(record)
      let line_with_newline = line + "\n"
      let data = @utf8.encode(line_with_newline)
      let written = c_fwrite(data, 1, data.length(), file)
      if written != data.length() {
        raise @interfaces.HistoryError::IoError(
          "Write failed: wrote \{written}/\{data.length()} bytes",
        )
      }
    }
    None =>
      raise @interfaces.HistoryError::IoError(
        "History recorder not initialized",
      )
  }
}

///|
pub impl @interfaces.HistoryRecorder for NativeHistoryRecorder with flush(self) -> Unit raise @interfaces.HistoryError {
  match self.current_file {
    Some(file) => {
      let _ = c_fclose(file)
      self.current_file = None
      self.initialized = false
    }
    None => ()
  }
}

///|
/// session_id (channel:chat_id) を分離する
fn split_session_id(session_id : String) -> (String, String) {
  // "channel:chat_id" 形式を想定
  let channel_buf = StringBuilder::new()
  let chat_id_buf = StringBuilder::new()
  let mut found_colon = false
  for c in session_id {
    if not(found_colon) && c == ':' {
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
/// ディレクトリ内のエントリ名一覧を取得する（c_list_dir のラッパー）
fn list_dir_entries(dir_path : String) -> Array[String] {
  if c_access(string_to_cstring(dir_path), f_ok) != 0 {
    return []
  }
  let buffer = Bytes::new(65536)
  let bytes_read = c_list_dir(
    string_to_cstring(dir_path),
    buffer,
    buffer.length(),
  )
  if bytes_read <= 0 {
    return []
  }
  // UTF-16LE の改行区切りをパース
  let entries : Array[String] = []
  let current = StringBuilder::new()
  let mut i = 0
  while i + 1 < bytes_read {
    let lo = buffer[i].to_int()
    let hi = buffer[i + 1].to_int()
    let ch = (lo | (hi << 8)).unsafe_to_char()
    if ch == '\n' {
      let name = current.to_string()
      if name.length() > 0 {
        entries.push(name)
      }
      current.reset()
    } else {
      current.write_char(ch)
    }
    i = i + 2
  }
  let last = current.to_string()
  if last.length() > 0 {
    entries.push(last)
  }
  entries
}

///|
/// ファイルの全内容をUTF-8文字列として読み取る（チャンク読み込み対応）
fn read_file_text(file_path : String) -> String raise @interfaces.HistoryError {
  match c_fopen(string_to_cstring(file_path), string_to_cstring("rb")) {
    Some(file) => {
      let chunk_size = 65536
      let chunk = Bytes::new(chunk_size)
      let buf = StringBuilder::new()
      while true {
        let bytes_read = c_fread(chunk, 1, chunk_size, file)
        if bytes_read <= 0 {
          break
        }
        // UTF-8 バイト列を文字列に変換して追加
        buf.write_string(
          Bytes::from_iter(chunk[:bytes_read].iter()).to_unchecked_string(),
        )
        if bytes_read < chunk_size {
          break
        }
      }
      let _ = c_fclose(file)
      buf.to_string()
    }
    None =>
      raise @interfaces.HistoryError::IoError("Cannot open file: \{file_path}")
  }
}

///|
/// NativeHistoryReader
/// ファイルシステムから JSONL 履歴を読み取る
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
  let (channel, chat_id) = split_session_id(session_id)
  let safe_channel = @history.sanitize_path_segment(channel)
  let safe_chat_id = @history.sanitize_path_segment(chat_id)
  let file_prefix = "\{safe_channel}-\{safe_chat_id}-"
  let records : Array[@interfaces.HistoryRecord] = []
  let history_root = "\{self.base_dir}/history"
  // base_dir/history/ の年ディレクトリを走査
  for year_name in list_dir_entries(history_root) {
    let year_path = "\{history_root}/\{year_name}"
    // 月ディレクトリを走査
    for month_name in list_dir_entries(year_path) {
      let month_path = "\{year_path}/\{month_name}"
      // 日ディレクトリを走査
      for day_name in list_dir_entries(month_path) {
        let day_path = "\{month_path}/\{day_name}"
        // ファイル一覧からセッションIDに合致するものを探す
        for file_name in list_dir_entries(day_path) {
          if file_name.has_prefix(file_prefix) && file_name.has_suffix(".jsonl") {
            let file_path = "\{day_path}/\{file_name}"
            let content = read_file_text(file_path) catch { _ => continue }
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
  for name in list_dir_entries(dir_path) {
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
  for year_name in list_dir_entries(history_root) {
    let year = match @history.parse_int_string(year_name) {
      Some(y) => y
      None => continue
    }
    let year_path = "\{history_root}/\{year_name}"
    for month_name in list_dir_entries(year_path) {
      let month = match @history.parse_int_string(month_name) {
        Some(m) => m
        None => continue
      }
      let month_path = "\{year_path}/\{month_name}"
      for day_name in list_dir_entries(month_path) {
        let day = match @history.parse_int_string(day_name) {
          Some(d) => d
          None => continue
        }
        // 実際にJSONLファイルがあるか確認
        let day_path = "\{month_path}/\{day_name}"
        let mut has_files = false
        for file_name in list_dir_entries(day_path) {
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
