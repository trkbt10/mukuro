///|
/// CLI Gateway Commands
/// Gateway start, status, stop command implementations

///|
/// Gatewayコマンドを実行 (async)
pub async fn execute_gateway_command(cmd : GatewayCommand) -> CliResult {
  match cmd {
    GatewayCommand::Start(opts) => execute_gateway_start(opts)
    GatewayCommand::Status(opts) => execute_gateway_status(opts)
    GatewayCommand::Stop => execute_gateway_stop()
    GatewayCommand::AuthLog(opts) =>
      query_gateway_auth_log(opts.since_seconds, opts.json)
    GatewayCommand::Unknown(name) =>
      CliResult::Error("Unknown gateway command: \{name}")
  }
}

///|
/// Gatewayを起動 (async)
async fn execute_gateway_start(opts : GatewayStartOptions) -> CliResult {
  match runtime_model_unavailable_reason_impl() {
    Some(reason) => return CliResult::Error(reason)
    None => ()
  }
  // 設定パスの解決
  let config_path = opts.config_path.unwrap_or(default_runtime_config_path())
  if not(runtime_config_exists(config_path)) {
    return CliResult::Error(config_not_found_message(config_path))
  }
  bootstrap_runtime_channels_from_config(config_path)
  // プラグインシステムの初期化（native transport使用）
  initialize_plugin_system_with_native_transport() catch {
    e =>
      if opts.debug {
        println("Warning: Plugin system initialization failed: \{e}")
      }
    // プラグイン初期化失敗は警告のみ（Gateway自体は起動継続）
  }
  // プラグイン監視のセットアップ（オプション）
  setup_plugin_watcher(@config.data_dir() + "/plugins")
  // 設定ファイルが指定されている場合のみ読み込み（未指定時はデフォルト）
  let base_config = match opts.config_path {
    Some(path) =>
      load_gateway_config_impl(path) catch {
        @interfaces.ControlError::ConfigError(msg) =>
          return CliResult::Error(
            "Failed to start gateway: config error - \{msg}",
          )
        _ =>
          return CliResult::Error(
            "Failed to start gateway: config error - unknown",
          )
      }
    None => @interfaces.GatewayConfig::default()
  }
  // CLI引数（--host/--port）があれば設定を上書き
  let host = opts.host.unwrap_or(base_config.host)
  let port = opts.port.unwrap_or(base_config.port)
  let gateway_config : @interfaces.GatewayConfig = { ..base_config, host, port }

  // デーモンモードの場合
  if opts.daemon {
    return execute_daemon_start(opts, gateway_config)
  }

  // 通常モード（インプロセス）
  global_gateway.start(config=gateway_config) catch {
    @interfaces.ControlError::AlreadyRunning =>
      return CliResult::Error("Failed to start gateway: already running")
    @interfaces.ControlError::ConfigError(msg) =>
      return CliResult::Error("Failed to start gateway: config error - \{msg}")
    @interfaces.ControlError::ChannelError(msg) =>
      return CliResult::Error("Failed to start gateway: channel error - \{msg}")
    _ => return CliResult::Error("Failed to start gateway: unknown error")
  }
  let status = global_gateway.status()

  // API v1 state を初期化（設定読み込み）
  let config_text = read_config_text_impl(config_path) catch {
    _ => return CliResult::Error(config_not_found_message(config_path))
  }
  let mukuro_config = @config.ConfigLoaderImpl::default().load_from_string(
    config_text,
  ) catch {
    _ =>
      return CliResult::Error(
        "Failed to parse configuration: \{config_path}\nCheck the file format or run 'mukuro onboard' to reinitialize.",
      )
  }
  init_api_v1_state(mukuro_config, config_path)

  // フォアグラウンドモード: 常にHTTPサーバーを起動してリクエストを受け付ける
  println(
    "Gateway started (in-process mode):\n  Host: \{host}\n  Port: \{port}\n  Config: \{config_path}\n  State: \{status.state.to_string()}\n  Debug: \{opts.debug}\n\nPress Ctrl+C to stop.",
  )
  run_control_api_server_with_tick_blocking(global_gateway, host, port, fn() {
    // シグナルチェック
    if @native.has_received_signal() {
      false
    } else {
      true
    }
  }) catch {
    e => return CliResult::Error("Control API server failed: \{e}")
  }
  CliResult::Ok("Gateway stopped")
}

///|
/// Gatewayの状態を表示 (async)
async fn execute_gateway_status(opts : GatewayStatusOptions) -> CliResult {
  // まずPIDファイル経由でデーモン状態を確認
  let daemon_status = get_daemon_status(pid_path=@control.default_pid_path())

  // デーモン状態に応じて表示
  match daemon_status {
    @control.DaemonStatus::Running(pid) => query_daemon_status(pid, opts.json)
    @control.DaemonStatus::Stale(pid) =>
      if opts.json {
        CliResult::Ok(
          "{\"mode\":\"daemon\",\"state\":\"stale\",\"stale_pid\":\{pid},\"pid_file\":\"\{@control.default_pid_path()}\",\"socket\":\"\{@control.default_ipc_socket_path()}\"}",
        )
      } else {
        CliResult::Ok(
          "Gateway Status (stale):\n  State: stale (PID file exists but process not running)\n  Stale PID: \{pid}\n  PID file: \{@control.default_pid_path()}\n\nUse 'gateway stop' to clean up stale PID file.",
        )
      }
    @control.DaemonStatus::Stopped => {
      // インプロセスモードの状態を確認
      let status = global_gateway.status()
      let health_str = match status.health {
        Some(h) => h.overall.to_string()
        None => "unknown"
      }
      let started_str = match status.started_at {
        Some(ts) => "\{ts}"
        None => "not started"
      }
      if opts.json {
        let started_json = match status.started_at {
          Some(ts) => "\{ts}"
          None => "null"
        }
        CliResult::Ok(
          "{\"mode\":\"in-process\",\"state\":\"\{status.state.to_string()}\",\"version\":\"\{status.version}\",\"health\":\"\{health_str}\",\"channels\":\{status.connected_channels.length()},\"sessions\":\{status.active_sessions},\"started\":\{started_json}}",
        )
      } else {
        CliResult::Ok(
          "Gateway Status (in-process mode):\n  State: \{status.state.to_string()}\n  Version: \{status.version}\n  Health: \{health_str}\n  Channels: \{status.connected_channels.length()}\n  Sessions: \{status.active_sessions}\n  Started: \{started_str}",
        )
      }
    }
  }
}

///|
/// Gatewayを停止 (async)
async fn execute_gateway_stop() -> CliResult {
  // まずPIDファイル経由でデーモン状態を確認
  let daemon_status = get_daemon_status(pid_path=@control.default_pid_path())

  match daemon_status {
    @control.DaemonStatus::Running(pid) => {
      // まずIPCで停止要求し、失敗時はシグナル送信へフォールバック
      let ipc_result = request_daemon_stop(pid)
      match ipc_result {
        CliResult::Ok(_) => ipc_result
        _ => stop_daemon(pid_path=@control.default_pid_path())
      }
    }
    @control.DaemonStatus::Stale(pid) => {
      // stale状態 → PIDファイルをクリーンアップ
      let _ = stop_daemon(pid_path=@control.default_pid_path())
      CliResult::Ok("Cleaned up stale PID file (PID: \{pid} was not running)")
    }
    @control.DaemonStatus::Stopped => {
      // デーモンなし → インプロセスモードを停止
      global_gateway.stop() catch {
        @interfaces.ControlError::AlreadyStopped =>
          return CliResult::Error("Gateway is not running")
        _ => return CliResult::Error("Failed to stop gateway")
      }
      CliResult::Ok("Gateway stopped successfully (in-process mode)")
    }
  }
}
