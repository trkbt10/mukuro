///|
/// Native ファイル操作ユーティリティ
/// ハンドルベースFFIによる共通ヘルパー関数群

// ============================================================
// ディレクトリ操作
// ============================================================

///|
/// ディレクトリ内のエントリ名一覧を取得する
pub fn native_list_dir_entries(dir_path : String) -> Array[String] {
  if c_access(string_to_cstring(dir_path), f_ok) != 0 {
    return []
  }
  let buffer = Bytes::new(65536)
  let bytes_read = c_list_dir(
    string_to_cstring(dir_path), buffer, buffer.length(),
  )
  if bytes_read <= 0 {
    return []
  }
  @bytes.parse_utf16le_lines(buffer, bytes_read)
}

///|
/// 指定プレフィックスとサフィックスに一致するファイルのフルパスを返す
pub fn native_find_file_with_prefix(
  dir_path : String,
  prefix : String,
  suffix : String,
) -> String? {
  for name in native_list_dir_entries(dir_path) {
    if name.has_prefix(prefix) && name.has_suffix(suffix) {
      return Some("\{dir_path}/\{name}")
    }
  }
  None
}

// ============================================================
// ファイル読み込み
// ============================================================

///|
/// ファイルの全内容をUTF-8文字列として読み取る（チャンク読み込み対応）
pub fn native_read_file_text(
  file_path : String,
) -> String raise FileSystemError {
  let handle = c_fopen_handle(
    string_to_utf8_cstring(file_path),
    string_to_utf8_cstring("rb"),
  )
  if handle == 0L {
    raise FileSystemError::FileNotFound(file_path)
  }
  let chunk_size = 65536
  let chunk = Bytes::new(chunk_size)
  let buf = StringBuilder::new()
  while true {
    let bytes_read = c_fread_handle(chunk, 1, chunk_size, handle)
    if bytes_read <= 0 {
      break
    }
    buf.write_string(@bytes.decode_utf8_or(chunk[:bytes_read], default=""))
    if bytes_read < chunk_size {
      break
    }
  }
  let _ = c_fclose_handle(handle)
  buf.to_string()
}

///|
/// ファイルの全内容をバイト列として読み取る（チャンク読み込み対応）
pub fn native_read_file_bytes(
  file_path : String,
) -> Bytes raise FileSystemError {
  let handle = c_fopen_handle(
    string_to_utf8_cstring(file_path),
    string_to_utf8_cstring("rb"),
  )
  if handle == 0L {
    raise FileSystemError::FileNotFound(file_path)
  }
  let chunk_size = 65536
  let chunk = Bytes::new(chunk_size)
  let bytes_read = c_fread_handle(chunk, 1, chunk_size, handle)
  let _ = c_fclose_handle(handle)
  if bytes_read < 0 {
    raise FileSystemError::IoError("Read error: \{file_path}")
  }
  if bytes_read < chunk_size {
    @bytes.copy_slice(chunk[:bytes_read])
  } else {
    chunk
  }
}

// ============================================================
// ファイル書き込み
// ============================================================

///|
/// テキストをファイルに書き込む（上書き）
pub fn native_write_file_text(
  file_path : String,
  content : String,
) -> Unit raise FileSystemError {
  let handle = c_fopen_handle(
    string_to_utf8_cstring(file_path),
    string_to_utf8_cstring("w"),
  )
  if handle == 0L {
    raise FileSystemError::IoError("Cannot open file for writing: \{file_path}")
  }
  let data = @utf8.encode(content)
  let written = c_fwrite_handle(data, 1, data.length(), handle)
  let _ = c_fclose_handle(handle)
  if written != data.length() {
    raise FileSystemError::IoError("Write error: \{file_path}")
  }
}

///|
/// テキストをファイルに追記する
pub fn native_append_file_text(
  file_path : String,
  content : String,
) -> Unit raise FileSystemError {
  let handle = c_fopen_handle(
    string_to_utf8_cstring(file_path),
    string_to_utf8_cstring("a"),
  )
  if handle == 0L {
    raise FileSystemError::IoError(
      "Cannot open file for appending: \{file_path}",
    )
  }
  let data = @utf8.encode(content)
  let written = c_fwrite_handle(data, 1, data.length(), handle)
  let _ = c_fclose_handle(handle)
  if written != data.length() {
    raise FileSystemError::IoError("Append error: \{file_path}")
  }
}

///|
/// バイト列をファイルに書き込む（上書き）
pub fn native_write_file_bytes(
  file_path : String,
  data : Bytes,
) -> Unit raise FileSystemError {
  let handle = c_fopen_handle(
    string_to_utf8_cstring(file_path),
    string_to_utf8_cstring("wb"),
  )
  if handle == 0L {
    raise FileSystemError::IoError("Cannot open file for writing: \{file_path}")
  }
  let written = c_fwrite_handle(data, 1, data.length(), handle)
  let _ = c_fclose_handle(handle)
  if written != data.length() {
    raise FileSystemError::IoError("Write error: \{file_path}")
  }
}

// ============================================================
// 時刻ユーティリティ
// ============================================================

///|
/// epoch秒から年月日を取得する（c_gmtimeラッパー）
pub fn native_epoch_to_date(
  epoch_secs : Int64,
) -> (Int, Int, Int) raise FileSystemError {
  let buf = Bytes::new(12)
  if c_gmtime(epoch_secs, buf) != 0 {
    raise FileSystemError::IoError("Failed to get date from timestamp")
  }
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
