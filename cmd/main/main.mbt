///|
/// mukuro CLI
/// サブコマンドの定義と実行ロジック

///|
/// mukuro バージョン
pub let version : String = "0.1.0"

///|
/// グローバルGatewayインスタンス（シングルプロセス用）
let global_gateway : @control.Gateway = create_global_gateway(version)

///|
/// CLIコマンド
pub(all) enum Command {
  /// ヘルプを表示
  Help
  /// バージョンを表示
  Version
  /// オンボーディング
  Onboard(OnboardOptions)
  /// Gateway操作
  Gateway(GatewayCommand)
  /// Cron操作
  Cron(CronCommand)
  /// デーモン子プロセス（内部使用）
  DaemonChild(String)
  /// 不明なコマンド
  Unknown(String)
}

///|
/// Gatewayサブコマンド
pub(all) enum GatewayCommand {
  /// Gatewayを起動
  Start(GatewayStartOptions)
  /// Gatewayの状態を表示
  Status(GatewayStatusOptions)
  /// Gatewayを停止
  Stop
  /// 不明
  Unknown(String)
}

///|
/// Gateway状態表示オプション
pub(all) struct GatewayStatusOptions {
  /// JSON形式で出力
  mut json : Bool
}

///|
/// Cronサブコマンド
pub(all) enum CronCommand {
  /// ジョブ一覧
  List
  /// 不明
  Unknown(String)
}

///|
/// オンボーディングオプション
pub(all) struct OnboardOptions {
  /// プロバイダ名
  mut provider : String?
  /// APIキー
  mut api_key : String?
  /// デフォルトモデル
  mut default_model : String?
  /// 出力先設定ファイルパス
  mut output_path : String?
}

///|
/// Gateway起動オプション
pub(all) struct GatewayStartOptions {
  /// 設定ファイルパス
  mut config_path : String?
  /// ホスト
  mut host : String?
  /// ポート
  mut port : Int?
  /// デバッグモード
  mut debug : Bool
  /// デーモンモード（バックグラウンド常駐）
  mut daemon : Bool
  /// Control APIをHTTP公開する（フォアグラウンド常駐）
  mut control_api : Bool
}

///|
/// CLI実行結果
pub(all) enum CliResult {
  /// 成功
  Ok(String)
  /// エラー
  Error(String)
  /// 終了コード付き
  Exit(Int)
}

///|
/// ヘルプメッセージを取得
pub fn get_help_message() -> String {
  "mukuro - MoonBit Agent Framework v\{version}\n\nUsage: mukuro <command> [options]\n\nCommands:\n  onboard              Initialize mukuro configuration\n  gateway start        Start the gateway service\n  gateway status       Show gateway status\n  gateway stop         Stop the gateway service\n  cron list            List scheduled cron jobs\n  version              Show version information\n  help                 Show this help message\n\nGateway Start Options:\n  --config <path>      Path to configuration file\n                       (default: .mukuro/config.json)\n  --host <host>        Host to bind (default: 127.0.0.1)\n  --port <port>        Port to bind (default: 8080)\n  --daemon, -D         Run as daemon (background process)\n  --control-api        Serve HTTP control API (works with --daemon)\n  --debug, -d          Enable debug mode\n\nGateway Status Options:\n  --json               Output status as JSON\n\nExamples:\n  mukuro onboard --provider anthropic --api-key sk-xxx\n  mukuro gateway start --config ./config.json\n  mukuro gateway start --daemon\n  mukuro gateway start --control-api --host 127.0.0.1 --port 8080\n  mukuro gateway status\n  mukuro gateway status --json\n  mukuro gateway stop\n  mukuro cron list"
}

///|
/// バージョン情報を取得
pub fn get_version_message() -> String {
  "mukuro v\{version}"
}

///|
/// コマンドを実行
pub fn execute_command(cmd : Command) -> CliResult {
  match cmd {
    Command::Help => CliResult::Ok(get_help_message())
    Command::Version => CliResult::Ok(get_version_message())
    Command::Onboard(opts) => execute_onboard(opts)
    Command::Gateway(gateway_cmd) => execute_gateway_command(gateway_cmd)
    Command::Cron(cron_cmd) => execute_cron_command(cron_cmd)
    Command::DaemonChild(pid_path) => execute_daemon_child(pid_path)
    Command::Unknown(name) =>
      CliResult::Error("Unknown command: \{name}\n\n\{get_help_message()}")
  }
}

///|
/// 統合経路テスト用: dispatch_inbound -> agent loop -> outbound を実行
pub fn dispatch_echo_for_test(content : String) -> CliResult {
  set_forced_response_for_test(Some("Echo: \{content}"))
  let start_result : Result[Unit, @interfaces.ControlError] = Ok(
    global_gateway.start(config=@interfaces.GatewayConfig::default()),
  ) catch {
    e => Err(e)
  }
  match start_result {
    Ok(_) => ()
    Err(@interfaces.ControlError::AlreadyRunning) => ()
    Err(_) => {
      set_forced_response_for_test(None)
      return CliResult::Error("Failed to start gateway for test")
    }
  }

  let before = sent_messages_count()
  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-1",
    sender_id: "user-1",
    sender_name: "User",
    content,
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 1000L,
  }
  let auth = @interfaces.AuthContext::token_only("test-token")
  let dispatch_result : Result[Unit, @interfaces.ControlError] = Ok(
    global_gateway.dispatch_inbound(auth~, envelope~),
  ) catch {
    e => Err(e)
  }
  match dispatch_result {
    Ok(_) => ()
    Err(_) => {
      set_forced_response_for_test(None)
      return CliResult::Error("dispatch_inbound failed")
    }
  }

  let after = sent_messages_count()
  if after <= before {
    set_forced_response_for_test(None)
    return CliResult::Error("No outbound message dispatched")
  }
  let result = match sent_message_at(after - 1) {
    Some(msg) => CliResult::Ok(msg.content)
    None => CliResult::Error("Dispatched message not found")
  }
  set_forced_response_for_test(None)
  result
}

///|
/// オンボーディングを実行
pub fn execute_onboard(opts : OnboardOptions) -> CliResult {
  // プロバイダの確認
  let provider = match opts.provider {
    Some(p) => p
    None => return CliResult::Error("Missing required option: --provider")
  }
  // APIキーの確認
  let api_key = match opts.api_key {
    Some(k) => k
    None => return CliResult::Error("Missing required option: --api-key")
  }
  // デフォルトモデルはオプション
  let default_model = opts.default_model.unwrap_or("")
  // 出力パスのデフォルト
  let output_path = opts.output_path.unwrap_or(".mukuro/config.json")
  // 設定JSONを構築（実際の値を補間）
  let config_json = "{\n  \"provider\": \"\{provider}\",\n  \"api_key\": \"\{api_key}\",\n  \"default_model\": \"\{default_model}\"\n}"
  execute_onboard_impl(
    provider, api_key, default_model, output_path, config_json,
  )
}

///|
/// Gatewayコマンドを実行
pub fn execute_gateway_command(cmd : GatewayCommand) -> CliResult {
  match cmd {
    GatewayCommand::Start(opts) => execute_gateway_start(opts)
    GatewayCommand::Status(opts) => execute_gateway_status(opts)
    GatewayCommand::Stop => execute_gateway_stop()
    GatewayCommand::Unknown(name) =>
      CliResult::Error("Unknown gateway command: \{name}")
  }
}

///|
/// Gatewayを起動
fn execute_gateway_start(opts : GatewayStartOptions) -> CliResult {
  match runtime_model_unavailable_reason_impl() {
    Some(reason) => return CliResult::Error(reason)
    None => ()
  }
  // 設定パスの解決
  let config_path = opts.config_path.unwrap_or(".mukuro/config.json")
  set_runtime_model_config_path_for_process(config_path)
  bootstrap_runtime_channels_from_config(config_path)
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
  if opts.control_api {
    let control_api_auth = @interfaces.AuthContext::token_only(
      gateway_config.auth_token,
    )
    run_control_api_server_with_tick_blocking(global_gateway, host, port, fn() {
      ignore(
        pump_registered_channels_to_gateway(global_gateway, control_api_auth),
      )
      true
    }) catch {
      e =>
        return CliResult::Error("Control API server failed: \{e.to_string()}")
    }
    return CliResult::Ok("Control API server stopped")
  }
  CliResult::Ok(
    "Gateway started (in-process mode):\n  Host: \{host}\n  Port: \{port}\n  Config: \{config_path}\n  State: \{status.state.to_string()}\n  Debug: \{opts.debug}\n\nNote: Gateway runs in-process. Use --daemon for background execution.",
  )
}

///|
/// Gatewayの状態を表示
fn execute_gateway_status(opts : GatewayStatusOptions) -> CliResult {
  // まずPIDファイル経由でデーモン状態を確認
  let daemon_status = get_daemon_status(pid_path=@control.default_pid_path)

  // デーモン状態に応じて表示
  match daemon_status {
    @control.DaemonStatus::Running(pid) => query_daemon_status(pid, opts.json)
    @control.DaemonStatus::Stale(pid) =>
      if opts.json {
        CliResult::Ok(
          "{\"mode\":\"daemon\",\"state\":\"stale\",\"stale_pid\":\{pid},\"pid_file\":\"\{@control.default_pid_path}\",\"socket\":\"\{@control.default_ipc_socket_path}\"}",
        )
      } else {
        CliResult::Ok(
          "Gateway Status (stale):\n  State: stale (PID file exists but process not running)\n  Stale PID: \{pid}\n  PID file: \{@control.default_pid_path}\n\nUse 'gateway stop' to clean up stale PID file.",
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
/// Gatewayを停止
fn execute_gateway_stop() -> CliResult {
  // まずPIDファイル経由でデーモン状態を確認
  let daemon_status = get_daemon_status(pid_path=@control.default_pid_path)

  match daemon_status {
    @control.DaemonStatus::Running(pid) => {
      // まずIPCで停止要求し、失敗時はシグナル送信へフォールバック
      let ipc_result = request_daemon_stop(pid)
      match ipc_result {
        CliResult::Ok(_) => ipc_result
        _ => stop_daemon(pid_path=@control.default_pid_path)
      }
    }
    @control.DaemonStatus::Stale(pid) => {
      // stale状態 → PIDファイルをクリーンアップ
      let _ = stop_daemon(pid_path=@control.default_pid_path)
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

///|
/// Cronコマンドを実行
pub fn execute_cron_command(cmd : CronCommand) -> CliResult {
  match cmd {
    CronCommand::List => execute_cron_list()
    CronCommand::Unknown(name) =>
      CliResult::Error("Unknown cron command: \{name}")
  }
}

///|
/// Cronジョブ一覧を表示
fn execute_cron_list() -> CliResult {
  // TaskSchedulerインスタンスを作成
  let scheduler = @scheduler.TaskScheduler::new()
  let tasks = scheduler.get_all_tasks()
  if tasks.is_empty() {
    return CliResult::Ok("No cron jobs scheduled")
  }
  let mut output = "Cron Jobs:\n"
  for task in tasks {
    output = output + "  - \{task.name}: (enabled: \{task.enabled})\n"
  }
  CliResult::Ok(output)
}

///|
/// 配列からスライスを作成（インデックス1から）
fn slice_from_1(arr : Array[String]) -> Array[String] {
  let result : Array[String] = []
  for i in 1..<arr.length() {
    result.push(arr[i])
  }
  result
}

///|
/// 引数配列からコマンドをパース
pub fn parse_args(args : Array[String]) -> Command {
  if args.is_empty() {
    return Command::Help
  }
  let cmd_name = args[0]
  match cmd_name {
    "help" | "--help" | "-h" => Command::Help
    "version" | "--version" | "-v" => Command::Version
    "--daemon-child" =>
      // 内部使用：posix_spawn で起動されたデーモン子プロセス
      if args.length() > 1 {
        Command::DaemonChild(args[1])
      } else {
        Command::Unknown("--daemon-child requires pid_path argument")
      }
    "onboard" => parse_onboard_args(slice_from_1(args)[:])
    "gateway" =>
      if args.length() > 1 {
        parse_gateway_args(slice_from_1(args)[:])
      } else {
        Command::Gateway(GatewayCommand::Unknown(""))
      }
    "cron" =>
      if args.length() > 1 {
        parse_cron_args(slice_from_1(args)[:])
      } else {
        Command::Cron(CronCommand::Unknown(""))
      }
    _ => Command::Unknown(cmd_name)
  }
}

///|
/// ArrayViewをArrayに変換
fn array_view_to_array(view : ArrayView[String]) -> Array[String] {
  let arr : Array[String] = []
  for item in view {
    arr.push(item)
  }
  arr
}

///|
/// onboardコマンドの引数をパース
fn parse_onboard_args(args : ArrayView[String]) -> Command {
  let opts : OnboardOptions = {
    provider: None,
    api_key: None,
    default_model: None,
    output_path: None,
  }
  let arr = array_view_to_array(args)
  let mut i = 0
  while i < arr.length() {
    let arg = arr[i]
    match arg {
      "--provider" =>
        if i + 1 < arr.length() {
          opts.provider = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--api-key" =>
        if i + 1 < arr.length() {
          opts.api_key = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--model" =>
        if i + 1 < arr.length() {
          opts.default_model = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--output" =>
        if i + 1 < arr.length() {
          opts.output_path = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      _ => i = i + 1
    }
  }
  Command::Onboard(opts)
}

///|
/// gatewayコマンドの引数をパース
fn parse_gateway_args(args : ArrayView[String]) -> Command {
  if args.is_empty() {
    return Command::Gateway(GatewayCommand::Unknown(""))
  }
  let arr = array_view_to_array(args)
  let subcmd = arr[0]
  match subcmd {
    "start" => {
      let opts = parse_gateway_start_opts(slice_from_1(arr)[:])
      Command::Gateway(GatewayCommand::Start(opts))
    }
    "status" => {
      let opts = parse_gateway_status_opts(slice_from_1(arr)[:])
      Command::Gateway(GatewayCommand::Status(opts))
    }
    "stop" => Command::Gateway(GatewayCommand::Stop)
    _ => Command::Gateway(GatewayCommand::Unknown(subcmd))
  }
}

///|
/// gateway statusオプションをパース
fn parse_gateway_status_opts(args : ArrayView[String]) -> GatewayStatusOptions {
  let opts : GatewayStatusOptions = { json: false }
  let arr = array_view_to_array(args)
  for arg in arr {
    if arg == "--json" {
      opts.json = true
    }
  }
  opts
}

///|
/// gateway startオプションをパース
fn parse_gateway_start_opts(args : ArrayView[String]) -> GatewayStartOptions {
  let opts : GatewayStartOptions = {
    config_path: None,
    host: None,
    port: None,
    debug: false,
    daemon: false,
    control_api: false,
  }
  let arr = array_view_to_array(args)
  let mut i = 0
  while i < arr.length() {
    let arg = arr[i]
    match arg {
      "--config" =>
        if i + 1 < arr.length() {
          opts.config_path = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--host" =>
        if i + 1 < arr.length() {
          opts.host = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--port" =>
        if i + 1 < arr.length() {
          try {
            let port_json : Json = @json.parse(arr[i + 1])
            match port_json {
              Number(n, ..) => opts.port = Some(n.to_int())
              _ => ()
            }
          } catch {
            _ => ()
          }
          i = i + 2
        } else {
          i = i + 1
        }
      "--debug" | "-d" => {
        opts.debug = true
        i = i + 1
      }
      "--daemon" | "-D" => {
        opts.daemon = true
        i = i + 1
      }
      "--control-api" => {
        opts.control_api = true
        i = i + 1
      }
      _ => i = i + 1
    }
  }
  opts
}

///|
/// cronコマンドの引数をパース
fn parse_cron_args(args : ArrayView[String]) -> Command {
  if args.is_empty() {
    return Command::Cron(CronCommand::Unknown(""))
  }
  let arr = array_view_to_array(args)
  let subcmd = arr[0]
  match subcmd {
    "list" => Command::Cron(CronCommand::List)
    _ => Command::Cron(CronCommand::Unknown(subcmd))
  }
}

///|
/// CLI実行結果を出力
fn print_result(result : CliResult) -> Unit {
  match result {
    CliResult::Ok(msg) => println(msg)
    CliResult::Error(msg) => println("Error: \{msg}")
    CliResult::Exit(code) => println("Exit code: \{code}")
  }
}

///|
/// CLIを実行（引数配列を受け取る）
pub fn run_cli(args : Array[String]) -> CliResult {
  let cmd = parse_args(args)
  execute_command(cmd)
}

///|
fn main {
  // NOTE: MoonBitでは直接コマンドライン引数を取得できないため、
  // 現時点ではヘルプを表示。実際の使用時は run_cli() を呼び出す。
  // Native/JSターゲットでは別途FFI経由で引数を取得し run_cli() に渡す。
  let args = get_command_line_args()
  if args.is_empty() {
    println(get_help_message())
  } else {
    let result = run_cli(args)
    print_result(result)
  }
}

// get_command_line_args() は args.mbt で共通実装:
// @env.args() を使用し、Node.js環境を自動検出してスキップ数を調整
