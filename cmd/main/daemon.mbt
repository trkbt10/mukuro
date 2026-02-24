///|
/// Daemon起動サポート（Native専用）
/// PIDファイル管理とバックグラウンド常駐

///|
/// テスト用IPCレスポンスフック
struct IpcResponseHookCell {
  mut value : ((String) -> String?)?
}

///|
let daemon_ipc_response_hook : IpcResponseHookCell = { value: None }

///|
/// IPCトークンのローテーション間隔（秒）
let daemon_token_rotation_interval_sec : Int64 = 300

///|
/// ローテーション直後に直前tokenを許容するgrace期間（秒）
let daemon_prev_token_grace_sec : Int64 = 30

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
  let socket_path = @control.default_ipc_socket_path

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
    "Gateway daemon started in background (PID: \{daemon_pid})\n  Host: \{config.host}\n  Port: \{config.port}\n  PID file: \{pid_path}\n  IPC socket: \{socket_path}",
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

  let self_pid = @native.c_getpid()
  let started_at = @native.c_time()
  let generated_token = @native.c_generate_gateway_token()
  let mut token = if generated_token > 0 {
    generated_token
  } else {
    // 予備経路（通常到達しない）
    (self_pid * 1103515245 + started_at.to_int()) & 2147483647
  }
  let generated_session_id = @native.c_generate_gateway_token()
  let session_id = if generated_session_id > 0 {
    generated_session_id
  } else {
    self_pid
  }
  let mut prev_token = -1
  let mut prev_token_grace_until : Int64 = 0
  let mut last_token_rotated_at = started_at
  let mut last_snapshot_uptime = -1

  if @native.c_write_gateway_token_record(token, session_id, started_at) != 0 {
    @native.c_remove_file(@native.string_to_cstring(pid_path)) |> ignore
    @native.c_exit(1)
    return CliResult::Exit(1)
  }

  let ipc_start = @native.c_ipc_server_start()
  if ipc_start != 0 {
    @native.c_remove_file(@native.string_to_cstring(pid_path)) |> ignore
    @native.c_exit(1)
    return CliResult::Exit(1)
  }

  // デーモンループを実行（シグナルを待機）
  let signal = @native.run_daemon_loop(interval_ms=100, on_tick=fn() {
    let now = @native.c_time()
    let uptime_sec = (now - started_at).to_int()
    if uptime_sec != last_snapshot_uptime {
      @native.c_write_gateway_snapshot(self_pid, uptime_sec, 1) |> ignore
      last_snapshot_uptime = uptime_sec
    }
    if now - last_token_rotated_at >= daemon_token_rotation_interval_sec {
      let next_token = @native.c_generate_gateway_token()
      if next_token > 0 && next_token != token {
        if @native.c_write_gateway_token_record(next_token, session_id, now) ==
          0 {
          prev_token = token
          prev_token_grace_until = now + daemon_prev_token_grace_sec
          token = next_token
          last_token_rotated_at = now
        }
      }
    }
    if prev_token != -1 && now >= prev_token_grace_until {
      prev_token = -1
    }
    let ipc_result = @native.c_ipc_server_poll(
      token, prev_token, session_id, self_pid, uptime_sec,
    )
    // stopコマンドを受信したらループを終了
    ipc_result != 2
  })

  // シグナル受信後のクリーンアップ
  let signal_name = match signal {
    1 => "SIGTERM"
    2 => "SIGINT"
    _ => "unknown"
  }

  // デバッグログ（stdout/stderrは閉じられているので効果なし）
  let _ = signal_name

  // PIDファイルを削除
  @native.c_write_gateway_snapshot(self_pid, 0, 0) |> ignore
  @native.c_remove_file(
    @native.string_to_cstring(@control.default_gateway_token_path),
  )
  |> ignore
  @native.c_ipc_server_cleanup() |> ignore
  @native.c_remove_file(@native.string_to_cstring(pid_path)) |> ignore

  // 正常終了
  @native.c_exit(0)
  CliResult::Exit(0)
}

///|
/// デーモンへIPCリクエストを送信
fn daemon_ipc_request(command : String) -> String? {
  match daemon_ipc_response_hook.value {
    Some(hook) => return hook(command)
    None => ()
  }
  let buffer = Bytes::new(512)
  let command_code = if command == "stop" { 2 } else { 1 }
  let token = @native.c_read_gateway_token()
  if token < 0 {
    return None
  }
  let session_id = @native.c_read_gateway_session_id()
  let read_len = @native.c_ipc_client_request(
    token, session_id, command_code, buffer, 512,
  )
  if read_len <= 0 {
    return None
  }
  Some(
    Bytes::from_iter(buffer.sub(end=read_len).iter())
    .to_unchecked_string()
    .trim(chars=" \t\n\r")
    .to_string(),
  )
}

///|
/// デーモンへstatus要求（IPC）
pub fn query_daemon_status(pid : Int, as_json : Bool) -> CliResult {
  let response = daemon_ipc_request("status").unwrap_or("")
  if response.has_prefix("OK running ") {
    let parts = response.split(" ").collect()
    let runtime_pid = if parts.length() > 2 { parts[2] } else { "\{pid}" }
    let uptime_sec = if parts.length() > 3 { parts[3] } else { "0" }
    if as_json {
      CliResult::Ok(
        "{\"mode\":\"daemon\",\"state\":\"running\",\"pid\":\{runtime_pid},\"uptime_sec\":\{uptime_sec},\"ipc\":\"connected\",\"pid_file\":\"\{@control.default_pid_path}\",\"socket\":\"\{@control.default_ipc_socket_path}\"}",
      )
    } else {
      CliResult::Ok(
        "Gateway Status (daemon mode):\n  State: running\n  PID: \{runtime_pid}\n  Uptime: \{uptime_sec}s\n  IPC: connected\n  PID file: \{@control.default_pid_path}\n  Socket: \{@control.default_ipc_socket_path}",
      )
    }
  } else if response.has_prefix("ERR unauthorized") {
    CliResult::Error("Daemon IPC authentication failed")
  } else if response == "" {
    CliResult::Error("Daemon IPC unavailable")
  } else {
    CliResult::Error("Daemon IPC error: \{response}")
  }
}

///|
/// デーモンへstop要求（IPC）
pub fn request_daemon_stop(pid : Int) -> CliResult {
  ignore(pid)
  let response = daemon_ipc_request("stop").unwrap_or("")
  if response.has_prefix("OK stopping") {
    CliResult::Ok("Stop request sent to gateway daemon via IPC")
  } else if response.has_prefix("ERR unauthorized") {
    CliResult::Error("Daemon IPC authentication failed")
  } else if response == "" {
    CliResult::Error("Daemon IPC unavailable")
  } else {
    CliResult::Error("Daemon IPC error: \{response}")
  }
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
  let status = daemon_manager.status()
  match status {
    @control.DaemonStatus::Stale(_) => {
      // stale検知時は運用アーティファクトをクリーンアップ
      @native.c_remove_file(
        @native.string_to_cstring(@control.default_ipc_socket_path),
      )
      |> ignore
      @native.c_remove_file(
        @native.string_to_cstring(@control.default_gateway_state_path),
      )
      |> ignore
      @native.c_remove_file(
        @native.string_to_cstring(@control.default_gateway_token_path),
      )
      |> ignore
      status
    }
    _ => status
  }
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
