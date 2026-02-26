///|
/// Daemon Child Process
/// Main daemon loop with token rotation and rate limiting

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
        @native.string_to_cstring(@control.default_gateway_token_path()),
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
          @native.string_to_cstring(@control.default_gateway_token_path()),
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
    @native.string_to_cstring(@control.default_gateway_token_path()),
  )
  |> ignore
  @native.c_ipc_server_cleanup() |> ignore
  @native.c_remove_file(@native.string_to_cstring(pid_path)) |> ignore

  // 正常終了
  @native.c_exit(0)
  CliResult::Exit(0)
}
