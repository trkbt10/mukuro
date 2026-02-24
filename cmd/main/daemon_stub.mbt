///|
/// Daemonスタブ（JS/WASM用）
/// Native以外のターゲットではデーモンモードをサポートしない

///|
/// テスト用IPCレスポンスフック
struct IpcResponseHookCell {
  mut value : ((String) -> String?)?
}

///|
let daemon_ipc_response_hook : IpcResponseHookCell = { value: None }

///|
/// テスト用: IPCレスポンスフックを設定
pub fn set_daemon_ipc_response_hook_for_test(
  hook : (String) -> String?,
) -> Unit {
  daemon_ipc_response_hook.value = Some(hook)
}

///|
/// テスト用: IPCレスポンスフックを解除
pub fn clear_daemon_ipc_response_hook_for_test() -> Unit {
  daemon_ipc_response_hook.value = None
}

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
/// デーモンへstatus要求（非native用スタブ）
pub fn query_daemon_status(pid : Int, as_json : Bool) -> CliResult {
  ignore(pid)
  ignore(as_json)
  match daemon_ipc_response_hook.value {
    Some(hook) => {
      let response = hook("status").unwrap_or("")
      if response.has_prefix("ERR unauthorized") {
        return CliResult::Error("Daemon IPC authentication failed")
      }
    }
    None => ()
  }
  CliResult::Error(
    "Daemon IPC is only supported on native target.\nPlease build with: moon build --target native",
  )
}

///|
/// デーモンへstop要求（非native用スタブ）
pub fn request_daemon_stop(pid : Int) -> CliResult {
  ignore(pid)
  match daemon_ipc_response_hook.value {
    Some(hook) => {
      let response = hook("stop").unwrap_or("")
      if response.has_prefix("ERR unauthorized") {
        return CliResult::Error("Daemon IPC authentication failed")
      }
    }
    None => ()
  }
  CliResult::Error(
    "Daemon IPC is only supported on native target.\nPlease build with: moon build --target native",
  )
}

///|
pub fn query_gateway_auth_log(
  since_seconds : Int64,
  as_json : Bool,
) -> CliResult {
  ignore(since_seconds)
  ignore(as_json)
  CliResult::Error(
    "Auth log query is only supported on native target.\nPlease build with: moon build --target native",
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
