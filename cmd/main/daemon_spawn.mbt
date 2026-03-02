///|
/// Daemon Spawn
/// Process spawning for daemon mode

///|
/// デーモンモードで起動（nativeターゲット実装）
/// posix_spawn を使用して新しいプロセスを起動し、MoonBitランタイムの
/// fork安全性問題を回避する
fn execute_daemon_start(
  opts : GatewayStartOptions,
  config : @interfaces.GatewayConfig,
) -> CliResult {
  let exe_path = @native.cstring_to_string(@native.c_get_exe_path())
  if exe_path.contains("/.moon/bin/internal/") {
    return CliResult::Error(
      "Daemon mode requires native binary execution.\nPlease run:\n  moon build cmd/main --target native\n  _build/native/debug/build/cmd/main/main.exe gateway start --daemon",
    )
  }

  let pid_path = @control.default_pid_path()
  let socket_path = @control.default_ipc_socket_path()

  // 既存のデーモンをチェック
  let daemon_manager = NativeDaemonManager::new(pid_path~)
  match daemon_manager.status() {
    @control.DaemonStatus::Running(pid) =>
      return CliResult::Error("Gateway already running (PID: \{pid})")
    @control.DaemonStatus::Stale(_) =>
      daemon_manager.pid_manager.remove_pid() catch {
        _ => ()
      }
    @control.DaemonStatus::Stopped => ()
  }

  if !write_daemon_startup_config(opts, config) {
    return CliResult::Error("Failed to persist daemon startup configuration")
  }

  // posix_spawn でデーモンプロセスを起動
  // 子プロセスは --daemon-child <pid_path> 引数で起動される
  let daemon_pid = @native.c_spawn_daemon_bytes(
    @native.string_to_utf8_cstring(pid_path),
  )

  if daemon_pid == -2 {
    return CliResult::Error(
      "Daemon mode requires native binary execution.\nPlease run:\n  moon build cmd/main --target native\n  _build/native/debug/build/cmd/main/main.exe gateway start --daemon",
    )
  }
  if daemon_pid < 0 {
    return CliResult::Error("Failed to spawn daemon process")
  }

  CliResult::Ok(
    "Gateway daemon started in background (PID: \{daemon_pid})\n  Host: \{config.host}\n  Port: \{config.port}\n  PID file: \{pid_path}\n  IPC socket: \{socket_path}",
  )
}
