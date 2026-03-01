///|
/// Native C FFI - シグナル・プロセス管理
/// Signal handling and process management

// ============================================================
// シグナルハンドラ
// ============================================================

///|
/// シグナルハンドラを設定（SIGTERM/SIGINT）
/// returns: 0 on success, -1 on error
pub extern "C" fn c_setup_signal_handlers() -> Int = "moonbit_setup_signal_handlers"

///|
/// シグナル受信状態を取得
/// returns: 0=未受信, 1=SIGTERM, 2=SIGINT
pub extern "C" fn c_get_signal_received() -> Int = "moonbit_get_signal_received"

///|
/// シグナル受信フラグをリセット
pub extern "C" fn c_reset_signal_received() -> Unit = "moonbit_reset_signal_received"

// ============================================================
// プロセス管理
// ============================================================

///|
/// 現在のプロセスIDを取得
pub extern "C" fn c_getpid() -> Int = "moonbit_getpid"

///|
/// プロセスにシグナルを送信
/// sig=0でプロセス存在確認
/// returns: 0 on success, -1 on error
pub extern "C" fn c_kill(pid : Int, sig : Int) -> Int = "moonbit_kill"

///|
/// 指定ミリ秒スリープ
pub extern "C" fn c_sleep_ms(ms : Int) -> Unit = "moonbit_sleep_ms"

///|
/// プロセスを終了
pub extern "C" fn c_exit(status : Int) -> Unit = "exit"

// ============================================================
// シグナル定数
// ============================================================

///|
/// SIGTERM（終了要求）
pub let sigterm : Int = 15

///|
/// SIGINT（割り込み）
pub let sigint : Int = 2
