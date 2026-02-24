///|
/// Native Daemon サポート
/// POSIX シグナル・プロセス管理

///|
/// Native ProcessChecker実装
pub struct NativeProcessChecker {
  /// ダミーフィールド（構造体には最低1フィールドが必要）
  _placeholder : Int
}

///|
pub fn NativeProcessChecker::new() -> NativeProcessChecker {
  { _placeholder: 0 }
}

///|
pub impl @control.ProcessChecker for NativeProcessChecker with is_running(
  self,
  pid,
) {
  ignore(self)
  // kill(pid, 0) でプロセス存在確認
  c_kill(pid, 0) == 0
}

///|
pub impl @control.ProcessChecker for NativeProcessChecker with current_pid(self) {
  ignore(self)
  c_getpid()
}

///|
pub impl @control.ProcessChecker for NativeProcessChecker with send_signal(
  self,
  pid,
  signal,
) {
  ignore(self)
  c_kill(pid, signal) == 0
}

///|
/// シグナルハンドラを設定
pub fn setup_signal_handlers() -> Bool {
  c_setup_signal_handlers() == 0
}

///|
/// シグナル受信状態を取得
/// 0: 未受信, 1: SIGTERM, 2: SIGINT
pub fn get_signal_received() -> Int {
  c_get_signal_received()
}

///|
/// シグナル受信フラグをリセット
pub fn reset_signal_received() -> Unit {
  c_reset_signal_received()
}

///|
/// 指定ミリ秒スリープ
pub fn sleep_ms(ms : Int) -> Unit {
  c_sleep_ms(ms)
}

///|
/// シグナルを受信したか確認
pub fn has_received_signal() -> Bool {
  c_get_signal_received() != 0
}

///|
/// デーモンイベントループを実行
/// シグナルを受信するまでスリープを繰り返す
/// on_tick: 定期的に呼び出されるコールバック（trueを返すと継続）
pub fn run_daemon_loop(interval_ms~ : Int, on_tick~ : () -> Bool) -> Int {
  // シグナルハンドラを設定
  if !setup_signal_handlers() {
    return -1
  }
  // ループ
  while !has_received_signal() {
    if !on_tick() {
      break
    }
    sleep_ms(interval_ms)
  }
  // 受信したシグナルを返す
  get_signal_received()
}
