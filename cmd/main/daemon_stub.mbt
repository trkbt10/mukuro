///|
/// Daemonスタブ（JS/WASM用）
/// Native以外のターゲットではデーモンモードをサポートしない

///|
/// デーモンモードで起動（非nativeターゲット用スタブ）
fn execute_daemon_start(
  _opts : GatewayStartOptions,
  _config : @interfaces.GatewayConfig,
) -> CliResult {
  CliResult::Error(
    "Daemon mode is only supported on native target.\nPlease build with: moon build --target native",
  )
}

///|
/// デーモン状態を取得（非native用スタブ）
/// 常にStoppedを返す（PIDファイルチェック不可）
pub fn get_daemon_status(pid_path~ : String) -> @control.DaemonStatus {
  ignore(pid_path)
  @control.DaemonStatus::Stopped
}

///|
/// デーモンを停止（非native用スタブ）
pub fn stop_daemon(pid_path~ : String) -> CliResult {
  ignore(pid_path)
  CliResult::Error(
    "Daemon control is only supported on native target.\nPlease build with: moon build --target native",
  )
}

///|
/// デーモン子プロセス起動（非native用スタブ）
pub fn execute_daemon_child(pid_path : String) -> CliResult {
  ignore(pid_path)
  CliResult::Error(
    "Daemon child mode is only supported on native target.\nPlease build with: moon build --target native",
  )
}
