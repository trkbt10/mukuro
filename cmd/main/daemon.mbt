///|
/// Daemon起動サポート（Native専用）
/// PIDファイル管理とバックグラウンド常駐

///|
/// デーモンモードで起動（nativeターゲット実装）
/// posix_spawn を使用して新しいプロセスを起動し、MoonBitランタイムの
/// fork安全性問題を回避する
fn execute_daemon_start(
  _opts : GatewayStartOptions,
  config : @interfaces.GatewayConfig,
) -> CliResult {
  let exe_path = @native.cstring_to_string(@native.c_get_exe_path())
  if exe_path.contains("/.moon/bin/internal/") {
    return CliResult::Error(
      "Daemon mode requires native binary execution.\nPlease run:\n  moon build cmd/main --target native\n  _build/native/debug/build/cmd/main/main.exe gateway start --daemon",
    )
  }

  let pid_path = @control.default_pid_path

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

  // posix_spawn でデーモンプロセスを起動
  // 子プロセスは --daemon-child <pid_path> 引数で起動される
  let daemon_pid = @native.c_spawn_daemon(@native.string_to_cstring(pid_path))

  if daemon_pid == -2 {
    return CliResult::Error(
      "Daemon mode requires native binary execution.\nPlease run:\n  moon build cmd/main --target native\n  _build/native/debug/build/cmd/main/main.exe gateway start --daemon",
    )
  }
  if daemon_pid < 0 {
    return CliResult::Error("Failed to spawn daemon process")
  }

  CliResult::Ok(
    "Gateway daemon started in background (PID: \{daemon_pid})\n  Host: \{config.host}\n  Port: \{config.port}\n  PID file: \{pid_path}",
  )
}

///|
/// --daemon-child 引数で起動された場合のデーモン子プロセス処理
pub fn execute_daemon_child(pid_path : String) -> CliResult {
  // デーモン子プロセスとして初期化（setsid, PIDファイル書き込み）
  let init_result = @native.c_daemon_child_init(
    @native.string_to_cstring(pid_path),
  )
  if init_result != 0 {
    // エラー時は即座に終了
    @native.c_exit(1)
    return CliResult::Exit(1)
  }

  // デーモンループを実行（シグナルを待機）
  let signal = @native.run_daemon_loop(interval_ms=1000, on_tick=fn() { true })

  // シグナル受信後のクリーンアップ
  let signal_name = match signal {
    1 => "SIGTERM"
    2 => "SIGINT"
    _ => "unknown"
  }

  // デバッグログ（stdout/stderrは閉じられているので効果なし）
  let _ = signal_name

  // PIDファイルを削除
  @native.c_remove_file(@native.string_to_cstring(pid_path)) |> ignore

  // 正常終了
  @native.c_exit(0)
  CliResult::Exit(0)
}

///|
/// Native版PidManager（FFI経由でPIDファイルを管理）
struct NativePidManager {
  pid_path : String
}

///|
fn NativePidManager::new(pid_path~ : String) -> NativePidManager {
  { pid_path, }
}

///|
fn NativePidManager::exists(self : NativePidManager) -> Bool {
  @native.c_file_exists(@native.string_to_cstring(self.pid_path)) == 1
}

///|
fn NativePidManager::read_pid(
  self : NativePidManager,
) -> Int raise @control.DaemonError {
  let pid = @native.c_read_pid_file(@native.string_to_cstring(self.pid_path))
  if pid < 0 {
    raise @control.DaemonError::PidFileReadError(
      "Failed to read PID file: \{self.pid_path}",
    )
  }
  pid
}

///|
fn NativePidManager::remove_pid(
  self : NativePidManager,
) -> Unit raise @control.DaemonError {
  let result = @native.c_remove_file(@native.string_to_cstring(self.pid_path))
  if result != 0 {
    raise @control.DaemonError::PidFileWriteError(
      "Failed to remove PID file: \{self.pid_path}",
    )
  }
}

///|
/// Native版DaemonManager（concrete型を使用）
struct NativeDaemonManager {
  pid_manager : NativePidManager
  process_checker : @native.NativeProcessChecker
}

///|
fn NativeDaemonManager::new(pid_path~ : String) -> NativeDaemonManager {
  {
    pid_manager: NativePidManager::new(pid_path~),
    process_checker: @native.NativeProcessChecker::new(),
  }
}

///|
fn NativeDaemonManager::status(
  self : NativeDaemonManager,
) -> @control.DaemonStatus {
  if !self.pid_manager.exists() {
    return @control.DaemonStatus::Stopped
  }
  let pid = self.pid_manager.read_pid() catch {
    _ => return @control.DaemonStatus::Stopped
  }
  if self.process_checker.is_running(pid) {
    @control.DaemonStatus::Running(pid)
  } else {
    @control.DaemonStatus::Stale(pid)
  }
}

///|
fn NativeDaemonManager::stop_remote(
  self : NativeDaemonManager,
) -> Unit raise @control.DaemonError {
  match self.status() {
    @control.DaemonStatus::Running(pid) =>
      if !self.process_checker.send_signal(pid, 15) {
        raise @control.DaemonError::SignalError(
          "Failed to send SIGTERM to pid \{pid}",
        )
      }
    @control.DaemonStatus::Stale(pid) => {
      self.pid_manager.remove_pid() catch {
        _ => ()
      }
      raise @control.DaemonError::ProcessNotFound(pid)
    }
    @control.DaemonStatus::Stopped =>
      raise @control.DaemonError::ProcessNotFound(0)
  }
}

///|
/// デーモン状態を取得（PIDファイル経由）
pub fn get_daemon_status(pid_path~ : String) -> @control.DaemonStatus {
  let daemon_manager = NativeDaemonManager::new(pid_path~)
  daemon_manager.status()
}

///|
/// デーモンを停止（PIDファイル経由でシグナル送信）
pub fn stop_daemon(pid_path~ : String) -> CliResult {
  let daemon_manager = NativeDaemonManager::new(pid_path~)

  daemon_manager.stop_remote() catch {
    @control.DaemonError::ProcessNotFound(0) =>
      return CliResult::Error("Gateway is not running (no PID file)")
    @control.DaemonError::ProcessNotFound(pid) =>
      return CliResult::Ok(
        "Gateway PID file found (\{pid}) but process not running (cleaned up)",
      )
    @control.DaemonError::SignalError(e) =>
      return CliResult::Error("Failed to stop gateway: \{e}")
    @control.DaemonError::AlreadyRunning(pid) =>
      return CliResult::Error("Unexpected state: running \{pid}")
    @control.DaemonError::PidFileReadError(e) =>
      return CliResult::Error("Failed to read PID file: \{e}")
    @control.DaemonError::PidFileWriteError(e) =>
      return CliResult::Error("Failed to write PID file: \{e}")
    @control.DaemonError::InitError(e) =>
      return CliResult::Error("Init error: \{e}")
  }

  CliResult::Ok("Stop signal sent to gateway daemon")
}
