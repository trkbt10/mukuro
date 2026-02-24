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
/// token最大寿命（秒）
let daemon_token_max_age_sec : Int64 = 900

///|
/// 認証失敗レート制御の窓（秒）
let daemon_auth_fail_window_sec : Int64 = 10

///|
/// 窓内失敗閾値
let daemon_auth_fail_threshold : Int = 5

///|
/// レート制限（全IPC拒否）継続秒数
let daemon_auth_rate_limit_sec : Int64 = 15

///|
let daemon_startup_config_path = ".mukuro/daemon-startup.json"

///|
let daemon_auth_log_path = ".mukuro/gateway-auth.log"

///|
struct DaemonStartupConfig {
  gateway_config : @interfaces.GatewayConfig
  runtime_model_config_path : String
  control_api : Bool
}

///|
fn daemon_startup_default() -> DaemonStartupConfig {
  {
    gateway_config: @interfaces.GatewayConfig::default(),
    runtime_model_config_path: ".mukuro/config.json",
    control_api: false,
  }
}

///|
fn write_daemon_startup_config(
  opts : GatewayStartOptions,
  config : @interfaces.GatewayConfig,
) -> Bool {
  let payload : Json = {
    "runtime_model_config_path": opts.config_path.unwrap_or(
      ".mukuro/config.json",
    ),
    "control_api": opts.control_api,
    "gateway": {
      "host": config.host,
      "port": config.port,
      "auth_token": config.auth_token,
      "auto_connect_channels": config.auto_connect_channels,
      "health_endpoint": {
        "path": config.health_endpoint.path,
        "require_auth": config.health_endpoint.require_auth,
        "include_details": config.health_endpoint.include_details,
        "cache_seconds": config.health_endpoint.cache_seconds,
      },
    },
  }
  let text = payload.stringify()
  @native.c_write_text_file(
    @native.string_to_cstring(daemon_startup_config_path),
    @native.string_to_cstring(text),
  ) ==
  0
}

///|
fn parse_daemon_startup_config(content : String) -> DaemonStartupConfig {
  let root_json : Json = @json.parse(content) catch {
    _ => return daemon_startup_default()
  }
  let root = match root_json {
    Object(obj) => obj
    _ => return daemon_startup_default()
  }
  let runtime_model_config_path = match root.get("runtime_model_config_path") {
    Some(String(path)) => path
    _ => ".mukuro/config.json"
  }
  let control_api = match root.get("control_api") {
    Some(True) => true
    Some(False) => false
    _ => false
  }
  let base_cfg = @interfaces.GatewayConfig::default()
  let gateway = match root.get("gateway") {
    Some(Object(obj)) => obj
    _ =>
      return {
        gateway_config: base_cfg,
        runtime_model_config_path,
        control_api,
      }
  }
  let health_base = base_cfg.health_endpoint
  let health_endpoint : @interfaces.HealthEndpointConfig = match
    gateway.get("health_endpoint") {
    Some(Object(h)) =>
      {
        path: match h.get("path") {
          Some(String(v)) => v
          _ => health_base.path
        },
        require_auth: match h.get("require_auth") {
          Some(True) => true
          Some(False) => false
          _ => health_base.require_auth
        },
        include_details: match h.get("include_details") {
          Some(True) => true
          Some(False) => false
          _ => health_base.include_details
        },
        cache_seconds: match h.get("cache_seconds") {
          Some(Number(n, ..)) => n.to_int()
          _ => health_base.cache_seconds
        },
      }
    _ => health_base
  }
  let gateway_config : @interfaces.GatewayConfig = {
    host: match gateway.get("host") {
      Some(String(v)) => v
      _ => base_cfg.host
    },
    port: match gateway.get("port") {
      Some(Number(n, ..)) => n.to_int()
      _ => base_cfg.port
    },
    auth_token: match gateway.get("auth_token") {
      Some(String(v)) => v
      _ => base_cfg.auth_token
    },
    health_endpoint,
    auto_connect_channels: match gateway.get("auto_connect_channels") {
      Some(True) => true
      Some(False) => false
      _ => base_cfg.auto_connect_channels
    },
  }
  { gateway_config, runtime_model_config_path, control_api }
}

///|
fn load_daemon_startup_config() -> DaemonStartupConfig {
  let buffer_len = 65536
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file(
    @native.string_to_cstring(daemon_startup_config_path),
    buffer,
    buffer_len,
  )
  if read_len <= 0 {
    return daemon_startup_default()
  }
  let data = Bytes::from_iter(buffer[:read_len].iter())
  let content = @utf8.decode(data[:]) catch {
    _ => return daemon_startup_default()
  }
  parse_daemon_startup_config(content)
}

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
  opts : GatewayStartOptions,
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

  if !write_daemon_startup_config(opts, config) {
    return CliResult::Error("Failed to persist daemon startup configuration")
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
fn current_cli_client_id() -> String {
  "cli-\{@native.c_getpid()}"
}

///|
fn read_last_ipc_client_id() -> String {
  let buffer = Bytes::new(128)
  let read_len = @native.c_ipc_get_last_client_id(buffer, 128)
  if read_len <= 0 {
    return "unknown"
  }
  Bytes::from_iter(buffer[:read_len].iter())
  .to_unchecked_string()
  .trim(chars=" \t\n\r")
  .to_string()
}

///|
fn append_auth_audit_detail(
  now : Int64,
  event : Int,
  value : Int,
  source : String,
  client_id : String,
  session_id : Int,
  reason : String,
  token_age_sec : Int,
  blocked_until : Int64,
) -> Unit {
  ignore(
    @native.c_append_gateway_auth_audit_detail(
      now,
      event,
      value,
      @native.string_to_cstring(source),
      @native.string_to_cstring(client_id),
      session_id,
      @native.string_to_cstring(reason),
      token_age_sec,
      blocked_until,
    ),
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

  let startup = load_daemon_startup_config()
  set_runtime_model_config_path_for_process(startup.runtime_model_config_path)
  bootstrap_runtime_channels_from_config(startup.runtime_model_config_path)
  global_gateway.start(config=startup.gateway_config) catch {
    _ => {
      @native.c_remove_file(@native.string_to_cstring(pid_path)) |> ignore
      @native.c_exit(1)
      return CliResult::Exit(1)
    }
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
  let mut token_issued_at = started_at
  let mut prev_token_issued_at : Int64 = 0
  let mut auth_failed_in_window = 0
  let mut auth_fail_window_started_at : Int64 = 0
  let mut auth_rate_limited_until : Int64 = 0
  let mut last_snapshot_uptime = -1
  let daemon_auth = @interfaces.AuthContext::token_only(
    startup.gateway_config.auth_token,
  )

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

  let daemon_tick = fn() {
    let now = @native.c_time()
    let uptime_sec = (now - started_at).to_int()
    if auth_rate_limited_until != 0 && now >= auth_rate_limited_until {
      auth_rate_limited_until = 0
      append_auth_audit_detail(
        now,
        3,
        0,
        "ipc",
        "unknown",
        session_id,
        "rate_limit_end",
        (now - token_issued_at).to_int(),
        0,
      )
    }
    if uptime_sec != last_snapshot_uptime {
      @native.c_write_gateway_snapshot(self_pid, uptime_sec, 1) |> ignore
      last_snapshot_uptime = uptime_sec
    }
    if now - last_token_rotated_at >= daemon_token_rotation_interval_sec ||
      now - token_issued_at >= daemon_token_max_age_sec {
      let next_token = @native.c_generate_gateway_token()
      if next_token > 0 && next_token != token {
        if @native.c_write_gateway_token_record(next_token, session_id, now) ==
          0 {
          prev_token = token
          prev_token_issued_at = token_issued_at
          prev_token_grace_until = now + daemon_prev_token_grace_sec
          token = next_token
          token_issued_at = now
          last_token_rotated_at = now
        }
      }
    }
    if prev_token != -1 && now >= prev_token_grace_until {
      prev_token = -1
    }
    let is_rate_limited = auth_rate_limited_until != 0 &&
      now < auth_rate_limited_until
    let current_token_for_auth = if is_rate_limited ||
      now - token_issued_at >= daemon_token_max_age_sec {
      -1
    } else {
      token
    }
    let prev_token_for_auth = if is_rate_limited ||
      prev_token == -1 ||
      now >= prev_token_grace_until ||
      now - prev_token_issued_at >= daemon_token_max_age_sec {
      -1
    } else {
      prev_token
    }
    let ipc_result = @native.c_ipc_server_poll(
      current_token_for_auth, prev_token_for_auth, session_id, self_pid, uptime_sec,
    )
    ignore(pump_registered_channels_to_gateway(global_gateway, daemon_auth))
    if !is_rate_limited && ipc_result == 3 {
      if auth_fail_window_started_at == 0 ||
        now - auth_fail_window_started_at > daemon_auth_fail_window_sec {
        auth_fail_window_started_at = now
        auth_failed_in_window = 1
      } else {
        auth_failed_in_window += 1
      }
      append_auth_audit_detail(
        now,
        1,
        auth_failed_in_window,
        "ipc",
        read_last_ipc_client_id(),
        @native.c_ipc_get_last_session_id(),
        "unauthorized",
        (now - token_issued_at).to_int(),
        auth_rate_limited_until,
      )
      if auth_failed_in_window >= daemon_auth_fail_threshold {
        auth_rate_limited_until = now + daemon_auth_rate_limit_sec
        auth_failed_in_window = 0
        auth_fail_window_started_at = 0
        append_auth_audit_detail(
          now,
          2,
          daemon_auth_rate_limit_sec.to_int(),
          "ipc",
          read_last_ipc_client_id(),
          @native.c_ipc_get_last_session_id(),
          "rate_limited",
          (now - token_issued_at).to_int(),
          auth_rate_limited_until,
        )
      }
    } else if ipc_result == 1 || ipc_result == 2 {
      auth_failed_in_window = 0
      auth_fail_window_started_at = 0
    }
    // stopコマンドを受信したらループを終了
    ipc_result != 2
  }

  // デーモンループを実行（シグナル待機 + IPC）
  let signal = if startup.control_api {
    if !@native.setup_signal_handlers() {
      @native.c_write_gateway_snapshot(self_pid, 0, 0) |> ignore
      @native.c_remove_file(
        @native.string_to_cstring(@control.default_gateway_token_path),
      )
      |> ignore
      @native.c_ipc_server_cleanup() |> ignore
      @native.c_remove_file(@native.string_to_cstring(pid_path)) |> ignore
      @native.c_exit(1)
      return CliResult::Exit(1)
    }
    let mut local_signal = 0
    run_control_api_server_with_tick_blocking(
      global_gateway,
      startup.gateway_config.host,
      startup.gateway_config.port,
      fn() {
        if @native.has_received_signal() {
          local_signal = @native.get_signal_received()
          false
        } else if daemon_tick() {
          true
        } else {
          local_signal = 1
          false
        }
      },
    ) catch {
      _ => {
        @native.c_write_gateway_snapshot(self_pid, 0, 0) |> ignore
        @native.c_remove_file(
          @native.string_to_cstring(@control.default_gateway_token_path),
        )
        |> ignore
        @native.c_ipc_server_cleanup() |> ignore
        @native.c_remove_file(@native.string_to_cstring(pid_path)) |> ignore
        @native.c_exit(1)
        return CliResult::Exit(1)
      }
    }
    local_signal
  } else {
    @native.run_daemon_loop(interval_ms=100, on_tick=daemon_tick)
  }

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
    token,
    session_id,
    command_code,
    @native.string_to_cstring(current_cli_client_id()),
    buffer,
    512,
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
fn parse_auth_log_string_field(
  obj : Map[String, Json],
  key : String,
) -> String? {
  match obj.get(key) {
    Some(String(v)) => Some(v)
    _ => None
  }
}

///|
fn parse_auth_log_int64_field(obj : Map[String, Json], key : String) -> Int64? {
  match obj.get(key) {
    Some(Number(v, ..)) => Some(v.to_int64())
    _ => None
  }
}

///|
fn read_auth_log_text() -> String? {
  let buffer_len = 262144
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file(
    @native.string_to_cstring(daemon_auth_log_path),
    buffer,
    buffer_len,
  )
  if read_len <= 0 {
    return None
  }
  let data = Bytes::from_iter(buffer[:read_len].iter())
  let decoded = @utf8.decode(data[:]) catch { _ => return None }
  Some(decoded)
}

///|
pub fn query_gateway_auth_log(
  since_seconds : Int64,
  as_json : Bool,
) -> CliResult {
  let content = read_auth_log_text().unwrap_or("")
  if content.length() == 0 {
    if as_json {
      return CliResult::Ok(
        "{\"path\":\"\{daemon_auth_log_path}\",\"total\":0,\"since_seconds\":\{since_seconds}}",
      )
    }
    return CliResult::Ok(
      "Gateway auth log is empty or not found: \{daemon_auth_log_path}",
    )
  }

  let now = @native.c_time()
  let cutoff = if since_seconds > 0 { now - since_seconds } else { 0 }
  let mut total = 0
  let event_counts : Map[String, Int] = {}
  let client_counts : Map[String, Int] = {}
  for line_sv in content.split("\n") {
    let line = line_sv.to_string().trim(chars=" \t\n\r").to_string()
    if line.length() == 0 {
      continue
    }
    let row_json : Json = @json.parse(line) catch { _ => continue }
    let row = match row_json {
      Object(obj) => obj
      _ => continue
    }
    let ts = parse_auth_log_int64_field(row, "ts").unwrap_or(0)
    if cutoff > 0 && ts < cutoff {
      continue
    }
    total = total + 1
    let event = parse_auth_log_string_field(row, "event").unwrap_or("unknown")
    event_counts[event] = event_counts.get(event).unwrap_or(0) + 1
    let client_id = parse_auth_log_string_field(row, "client_id").unwrap_or(
      "unknown",
    )
    client_counts[client_id] = client_counts.get(client_id).unwrap_or(0) + 1
  }

  if as_json {
    let events_obj : Map[String, Json] = {}
    for name, count in event_counts {
      events_obj[name] = Json::number(count.to_double())
    }
    let clients_obj : Map[String, Json] = {}
    for name, count in client_counts {
      clients_obj[name] = Json::number(count.to_double())
    }
    let payload : Json = {
      "path": daemon_auth_log_path,
      "total": total,
      "since_seconds": Json::number(since_seconds.to_double()),
      "cutoff_ts": Json::number(cutoff.to_double()),
      "events": Json::object(events_obj),
      "clients": Json::object(clients_obj),
    }
    return CliResult::Ok(payload.stringify())
  }

  let mut output = "Gateway Auth Log Summary\n"
  output = output + "  Path: \{daemon_auth_log_path}\n"
  output = output + "  Total: \{total}\n"
  output = output + "  Since: last \{since_seconds}s\n"
  output = output + "  Events:\n"
  for name, count in event_counts {
    output = output + "    - \{name}: \{count}\n"
  }
  output = output + "  Clients:\n"
  for name, count in client_counts {
    output = output + "    - \{name}: \{count}\n"
  }
  CliResult::Ok(output)
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
