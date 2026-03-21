///|
/// Daemon Manager
/// PID management and daemon lifecycle control

///|
/// Native版PidManager（FFI経由でPIDファイルを管理）
pub(all) struct NativePidManager {
  pid_path : String
}

///|
pub fn NativePidManager::new(pid_path~ : String) -> NativePidManager {
  { pid_path, }
}

///|
pub fn NativePidManager::exists(self : NativePidManager) -> Bool {
  @native.c_file_exists_bytes(@native.string_to_utf8_cstring(self.pid_path)) ==
  1
}

///|
pub fn NativePidManager::read_pid(
  self : NativePidManager,
) -> Int raise @control.DaemonError {
  let pid = @native.c_read_pid_file_bytes(
    @native.string_to_utf8_cstring(self.pid_path),
  )
  if pid < 0 {
    raise @control.DaemonError::PidFileReadError(
      "Failed to read PID file: \{self.pid_path}",
    )
  }
  pid
}

///|
pub fn NativePidManager::remove_pid(
  self : NativePidManager,
) -> Unit raise @control.DaemonError {
  let result = @native.c_remove_file_bytes(
    @native.string_to_utf8_cstring(self.pid_path),
  )
  if result != 0 {
    raise @control.DaemonError::PidFileWriteError(
      "Failed to remove PID file: \{self.pid_path}",
    )
  }
}

///|
/// Native版DaemonManager（concrete型を使用）
pub(all) struct NativeDaemonManager {
  pid_manager : NativePidManager
  process_checker : @native.NativeProcessChecker
}

///|
pub fn NativeDaemonManager::new(pid_path~ : String) -> NativeDaemonManager {
  {
    pid_manager: NativePidManager::new(pid_path~),
    process_checker: @native.NativeProcessChecker::new(),
  }
}

///|
pub fn NativeDaemonManager::status(
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
pub fn NativeDaemonManager::stop_remote(
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
  let status = daemon_manager.status()
  match status {
    @control.DaemonStatus::Stale(_) => {
      // stale検知時は運用アーティファクトをクリーンアップ
      @native.c_remove_file_bytes(
        @native.string_to_utf8_cstring(@control.default_ipc_socket_path()),
      )
      |> ignore
      @native.c_remove_file_bytes(
        @native.string_to_utf8_cstring(@control.default_gateway_state_path()),
      )
      |> ignore
      @native.c_remove_file_bytes(
        @native.string_to_utf8_cstring(@control.default_gateway_token_path()),
      )
      |> ignore
      status
    }
    _ => status
  }
}

///|
/// デーモンを停止（PIDファイル経由でシグナル送信）
pub fn stop_daemon(pid_path~ : String) -> @cli.CliResult {
  let daemon_manager = NativeDaemonManager::new(pid_path~)

  daemon_manager.stop_remote() catch {
    @control.DaemonError::ProcessNotFound(0) =>
      return @cli.CliResult::Error("Gateway is not running (no PID file)")
    @control.DaemonError::ProcessNotFound(pid) =>
      return @cli.CliResult::Ok(
        "Gateway PID file found (\{pid}) but process not running (cleaned up)",
      )
    @control.DaemonError::SignalError(e) =>
      return @cli.CliResult::Error("Failed to stop gateway: \{e}")
    @control.DaemonError::AlreadyRunning(pid) =>
      return @cli.CliResult::Error("Unexpected state: running \{pid}")
    @control.DaemonError::PidFileReadError(e) =>
      return @cli.CliResult::Error("Failed to read PID file: \{e}")
    @control.DaemonError::PidFileWriteError(e) =>
      return @cli.CliResult::Error("Failed to write PID file: \{e}")
    @control.DaemonError::InitError(e) =>
      return @cli.CliResult::Error("Init error: \{e}")
  }

  @cli.CliResult::Ok("Stop signal sent to gateway daemon")
}
