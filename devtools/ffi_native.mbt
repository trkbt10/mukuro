///|
/// Native C FFI 宣言（ビルド支援ツール用）
/// リンク時に native_stubs.c のシンボルを解決

// ============================================================
// CString型（パス操作用）
// ============================================================

///|
#external
priv type ToolCString

///|
/// MoonBit String → CString 変換（UTF-16LE、%identity）
fn to_cstring(s : String) -> ToolCString = "%identity"

// ============================================================
// プロセス実行（Bytes版）
// ============================================================

///|
/// コマンドを実行（popen）- UTF-8 Bytes版
#borrow(command, mode)
extern "C" fn native_popen_handle(
  command : Bytes,
  mode : Bytes,
) -> Int64 = "moonbit_popen_bytes"

///|
/// pclose - ハンドル版
extern "C" fn native_pclose_handle(handle : Int64) -> Int = "moonbit_pclose_handle"

///|
/// fread - ハンドル版
#borrow(buffer)
extern "C" fn native_fread_handle(
  buffer : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fread_handle"

// ============================================================
// ファイルI/O（ハンドル版）
// ============================================================

///|
/// fopen - UTF-8 Bytes版、ハンドル返却
#borrow(path, mode)
extern "C" fn native_fopen_handle(
  path : Bytes,
  mode : Bytes,
) -> Int64 = "moonbit_fopen_bytes"

///|
/// fwrite - ハンドル版
#borrow(data)
extern "C" fn native_fwrite_handle(
  data : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fwrite_handle"

///|
/// fclose - ハンドル版
extern "C" fn native_fclose_handle(handle : Int64) -> Int = "moonbit_fclose_handle"

// ============================================================
// パス操作（CString版）
// ============================================================

///|
/// ファイルの存在確認
#borrow(path)
extern "C" fn native_access(path : ToolCString, mode : Int) -> Int = "moonbit_access"

///|
/// ファイルを削除
#borrow(path)
extern "C" fn native_remove(path : ToolCString) -> Int = "moonbit_remove"

///|
/// ディレクトリ一覧を取得（opendir/readdir使用）
/// buffer: UTF-16LE出力バッファ（エントリ名が改行区切り）
#borrow(path, buffer)
extern "C" fn native_list_dir(
  path : ToolCString,
  buffer : Bytes,
  buffer_len : Int,
) -> Int = "moonbit_list_dir"

///|
/// ディレクトリを再帰的に作成
#borrow(path)
extern "C" fn native_mkdir_recursive(
  path : ToolCString,
  mode : Int,
) -> Int = "moonbit_mkdir_recursive"

// ============================================================
// 定数
// ============================================================

///|
/// F_OK (ファイル存在確認用)
let native_f_ok : Int = 0

// ============================================================
// ヘルパー
// ============================================================

///|
/// 文字列をnull終端UTF-8バイト列に変換
fn to_utf8_cstr(s : String) -> Bytes {
  @bytes.to_utf8_cstring(s)
}

///|
/// popenでコマンドを実行し、stdout全体を文字列として返す
fn exec_popen(command : String) -> (String, Int) {
  let cmd_bytes = to_utf8_cstr(command)
  let mode_bytes = to_utf8_cstr("r")
  let handle = native_popen_handle(cmd_bytes, mode_bytes)
  if handle == 0L {
    return ("", -1)
  }
  let buffer_size = 65536
  let buffer = Bytes::new(buffer_size)
  let bytes_read = native_fread_handle(buffer, 1, buffer_size, handle)
  let exit_raw = native_pclose_handle(handle)
  let exit_code = (exit_raw.reinterpret_as_uint() >> 8)
    .land(0xFFU)
    .reinterpret_as_int()
  let stdout = if bytes_read > 0 {
    utf8_bytes_to_string(buffer, bytes_read)
  } else {
    ""
  }
  (stdout, exit_code)
}

///|
/// UTF-8バイト列をMoonBit文字列（UTF-16LE）にデコード
fn utf8_bytes_to_string(data : Bytes, len : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < len {
    let b0 = data[i].to_int()
    if b0 < 0x80 {
      buf.write_char(Int::unsafe_to_char(b0))
      i = i + 1
    } else if b0 < 0xE0 {
      if i + 1 >= len {
        break
      }
      let b1 = data[i + 1].to_int()
      let cp = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i = i + 2
    } else if b0 < 0xF0 {
      if i + 2 >= len {
        break
      }
      let b1 = data[i + 1].to_int()
      let b2 = data[i + 2].to_int()
      let cp = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i = i + 3
    } else {
      if i + 3 >= len {
        break
      }
      let b1 = data[i + 1].to_int()
      let b2 = data[i + 2].to_int()
      let b3 = data[i + 3].to_int()
      let cp = ((b0 & 0x07) << 18) | ((b1 & 0x3F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F)
      buf.write_char(Int::unsafe_to_char(cp))
      i = i + 4
    }
  }
  buf.to_string()
}

///|
/// シングルクォートをエスケープ
fn escape_single_quote(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if c == '\'' {
      buf.write_string("'\\''")
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}
