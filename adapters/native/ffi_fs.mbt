///|
/// Native C FFI - ファイルシステム
/// Filesystem operations (CString and Bytes versions)

// ============================================================
// CString版 (Pattern A - レガシー、将来削除予定)
// ============================================================

///|
/// ファイルの存在確認
#borrow(path)
pub extern "C" fn c_access(path : CString, mode : Int) -> Int = "moonbit_access"

///|
/// ファイルを削除
#borrow(path)
pub extern "C" fn c_remove(path : CString) -> Int = "moonbit_remove"

///|
/// ディレクトリを作成
#borrow(path)
pub extern "C" fn c_mkdir(path : CString, mode : Int) -> Int = "moonbit_mkdir"

///|
/// ディレクトリ一覧を取得（シェル不使用、opendir/readdir使用）
/// buffer: UTF-16LE出力バッファ（エントリ名が改行区切り）
/// returns: 書き込んだバイト数、エラー時-1
#borrow(path, buffer)
pub extern "C" fn c_list_dir(
  path : CString,
  buffer : Bytes,
  buffer_len : Int,
) -> Int = "moonbit_list_dir"

///|
/// ディレクトリを再帰的に作成（mkdir -p 相当）
/// returns: 0 on success, -1 on error
#borrow(path)
pub extern "C" fn c_mkdir_recursive(path : CString, mode : Int) -> Int = "moonbit_mkdir_recursive"

///|
/// PIDファイルを書き込む（親ディレクトリも作成）
/// returns: 0 on success, -1 on error
#borrow(path)
pub extern "C" fn c_write_pid_file(path : CString, pid : Int) -> Int = "moonbit_write_pid_file"

///|
/// テキストファイルを書き込む（親ディレクトリも作成）
/// returns: 0 on success, -1 on error
#borrow(path, content)
pub extern "C" fn c_write_text_file(path : CString, content : CString) -> Int = "moonbit_write_text_file"

///|
/// テキストファイルを読み込む
/// returns: bytes read on success, -1 on error
#borrow(path, buffer)
pub extern "C" fn c_read_text_file(
  path : CString,
  buffer : Bytes,
  buffer_len : Int,
) -> Int = "moonbit_read_text_file"

///|
/// PIDファイルを読み取る
/// returns: PID on success, -1 on error
#borrow(path)
pub extern "C" fn c_read_pid_file(path : CString) -> Int = "moonbit_read_pid_file"

///|
/// ファイルが存在するか確認
/// returns: 1 if exists, 0 otherwise
#borrow(path)
pub extern "C" fn c_file_exists(path : CString) -> Int = "moonbit_file_exists"

///|
/// ファイルを削除
/// returns: 0 on success, -1 on error
#borrow(path)
pub extern "C" fn c_remove_file(path : CString) -> Int = "moonbit_remove_file"

///|
/// ファイル権限を変更
/// mode 例: 0o600 / 0o644
/// returns: 0 on success, -1 on error
#borrow(path)
pub extern "C" fn c_chmod_file(path : CString, mode : Int) -> Int = "moonbit_chmod_file"

// ============================================================
// UTF-8 Bytes版 (Pattern B - 推奨)
// ============================================================

///|
/// access - UTF-8 Bytes版
#borrow(path)
pub extern "C" fn c_access_bytes(path : Bytes, mode : Int) -> Int = "moonbit_access_bytes"

///|
/// remove - UTF-8 Bytes版
#borrow(path)
pub extern "C" fn c_remove_bytes(path : Bytes) -> Int = "moonbit_remove_bytes"

///|
/// mkdir - UTF-8 Bytes版
#borrow(path)
pub extern "C" fn c_mkdir_bytes(path : Bytes, mode : Int) -> Int = "moonbit_mkdir_bytes"

///|
/// mkdir recursive - UTF-8 Bytes版
#borrow(path)
pub extern "C" fn c_mkdir_recursive_bytes(path : Bytes, mode : Int) -> Int = "moonbit_mkdir_recursive_bytes"

///|
/// list_dir - UTF-8 Bytes版 (出力はUTF-16LE)
#borrow(path, buffer)
pub extern "C" fn c_list_dir_bytes(
  path : Bytes,
  buffer : Bytes,
  buffer_len : Int,
) -> Int = "moonbit_list_dir_bytes"

///|
/// write_pid_file - UTF-8 Bytes版
#borrow(path)
pub extern "C" fn c_write_pid_file_bytes(path : Bytes, pid : Int) -> Int = "moonbit_write_pid_file_bytes"

///|
/// write_text_file - UTF-8 Bytes版
#borrow(path, content)
pub extern "C" fn c_write_text_file_bytes(path : Bytes, content : Bytes) -> Int = "moonbit_write_text_file_bytes"

///|
/// read_text_file - UTF-8 Bytes版
#borrow(path, buffer)
pub extern "C" fn c_read_text_file_bytes(
  path : Bytes,
  buffer : Bytes,
  buffer_len : Int,
) -> Int = "moonbit_read_text_file_bytes"

///|
/// read_pid_file - UTF-8 Bytes版
#borrow(path)
pub extern "C" fn c_read_pid_file_bytes(path : Bytes) -> Int = "moonbit_read_pid_file_bytes"

///|
/// file_exists - UTF-8 Bytes版
#borrow(path)
pub extern "C" fn c_file_exists_bytes(path : Bytes) -> Int = "moonbit_file_exists_bytes"

///|
/// remove_file - UTF-8 Bytes版
#borrow(path)
pub extern "C" fn c_remove_file_bytes(path : Bytes) -> Int = "moonbit_remove_file_bytes"

///|
/// chmod_file - UTF-8 Bytes版
#borrow(path)
pub extern "C" fn c_chmod_file_bytes(path : Bytes, mode : Int) -> Int = "moonbit_chmod_file_bytes"
