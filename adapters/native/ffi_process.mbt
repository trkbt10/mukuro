///|
/// Native C FFI - プロセス実行
/// Process execution and daemon management

// ============================================================
// ファイルハンドル操作
// ============================================================

///|
/// コマンドを実行（popen）- UTF-8 Bytes版
/// command と mode は null終端されたUTF-8バイト列
/// 戻り値はハンドル（Int64）、0は失敗
#borrow(command, mode)
pub extern "C" fn c_popen_handle(command : Bytes, mode : Bytes) -> Int64 = "moonbit_popen_bytes"

///|
/// pclose - ハンドル版
pub extern "C" fn c_pclose_handle(handle : Int64) -> Int = "moonbit_pclose_handle"

///|
/// fread - ハンドル版
#borrow(buffer)
pub extern "C" fn c_fread_handle(
  buffer : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fread_handle"

///|
/// fclose - ハンドル版
pub extern "C" fn c_fclose_handle(handle : Int64) -> Int = "moonbit_fclose_handle"

///|
/// ファイルを開く（fopen）- UTF-8 Bytes版、ハンドル返却
#borrow(path, mode)
pub extern "C" fn c_fopen_handle(path : Bytes, mode : Bytes) -> Int64 = "moonbit_fopen_bytes"

///|
/// ファイルに書き込み - ハンドル版
#borrow(data)
pub extern "C" fn c_fwrite_handle(
  data : Bytes,
  size : Int,
  nmemb : Int,
  handle : Int64,
) -> Int = "moonbit_fwrite_handle"

///|
/// ファイルをフラッシュ - ハンドル版
pub extern "C" fn c_fflush_handle(handle : Int64) -> Int = "moonbit_fflush_handle"

// ============================================================
// system コマンド
// ============================================================

///|
/// system コマンド実行 (内部で UTF-16LE → UTF-8 変換)
#borrow(command)
pub extern "C" fn c_system(command : CString) -> Int = "moonbit_system"

///|
/// system - UTF-8 Bytes版
#borrow(command)
pub extern "C" fn c_system_bytes(command : Bytes) -> Int = "moonbit_system_bytes"

// ============================================================
// posix_spawn ベースのデーモン起動
// ============================================================

///|
/// posix_spawn でデーモンプロセスを起動
/// fork() の代わりに新しいプロセスを起動することで、MoonBitランタイムの
/// fork安全性問題を回避する
/// returns: 成功時は子プロセスのPID、エラー時は-1
#borrow(pid_path)
pub extern "C" fn c_spawn_daemon(pid_path : CString) -> Int = "moonbit_spawn_daemon"

///|
/// デーモン子プロセスとして初期化（--daemon-child 引数で起動時）
/// returns: 0 on success, -1 on error
#borrow(pid_path)
pub extern "C" fn c_daemon_child_init(pid_path : CString) -> Int = "moonbit_daemon_child_init"

///|
/// spawn_daemon - UTF-8 Bytes版
#borrow(pid_path)
pub extern "C" fn c_spawn_daemon_bytes(pid_path : Bytes) -> Int = "moonbit_spawn_daemon_bytes"

///|
/// daemon_child_init - UTF-8 Bytes版
#borrow(pid_path)
pub extern "C" fn c_daemon_child_init_bytes(pid_path : Bytes) -> Int = "moonbit_daemon_child_init_bytes"

///|
/// 実行ファイルの絶対パスを取得
pub extern "C" fn c_get_exe_path() -> CString = "moonbit_get_exe_path"
