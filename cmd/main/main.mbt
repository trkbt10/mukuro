///|
/// mukuro CLI
/// サブコマンドの定義と実行ロジック

///|
/// mukuro バージョン
pub let version : String = "0.1.0"

///|
/// グローバルGatewayインスタンス（シングルプロセス用）
let global_gateway : @control.Gateway = @control.Gateway::minimal(version~)

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
  /// 不明なコマンド
  Unknown(String)
}

///|
/// Gatewayサブコマンド
pub(all) enum GatewayCommand {
  /// Gatewayを起動
  Start(GatewayStartOptions)
  /// Gatewayの状態を表示
  Status
  /// Gatewayを停止
  Stop
  /// 不明
  Unknown(String)
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
  "mukuro - MoonBit Agent Framework v\{version}\n\nUsage: mukuro <command> [options]\n\nCommands:\n  onboard              Initialize mukuro configuration\n  gateway start        Start the gateway service\n  gateway status       Show gateway status\n  gateway stop         Stop the gateway service\n  cron list            List scheduled cron jobs\n  version              Show version information\n  help                 Show this help message\n\nOptions:\n  --config <path>      Path to configuration file\n                       (default: ~/.mukuro/config.json)\n\nExamples:\n  mukuro onboard --provider anthropic --api-key sk-xxx\n  mukuro gateway start --config ./config.json\n  mukuro gateway status\n  mukuro cron list"
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
    Command::Unknown(name) =>
      CliResult::Error("Unknown command: \{name}\n\n\{get_help_message()}")
  }
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
  let output_path = opts.output_path.unwrap_or("~/.mukuro/config.json")
  // 設定JSONを構築（実際の値を補間）
  let config_json = "{\n  \"provider\": \"\{provider}\",\n  \"api_key\": \"\{api_key}\",\n  \"default_model\": \"\{default_model}\"\n}"
  // NOTE: 実際のファイル書き込みはプラットフォーム固有のFFIが必要
  // ここでは設定内容を返すのみ
  CliResult::Ok(
    "Configuration prepared:\n  Provider: \{provider}\n  Model: \{default_model}\n  Output: \{output_path}\n\nConfig JSON:\n\{config_json}",
  )
}

///|
/// Gatewayコマンドを実行
pub fn execute_gateway_command(cmd : GatewayCommand) -> CliResult {
  match cmd {
    GatewayCommand::Start(opts) => execute_gateway_start(opts)
    GatewayCommand::Status => execute_gateway_status()
    GatewayCommand::Stop => execute_gateway_stop()
    GatewayCommand::Unknown(name) =>
      CliResult::Error("Unknown gateway command: \{name}")
  }
}

///|
/// Gatewayを起動
///
/// NOTE: 現在の実装では、gateway startは即座に終了します。
/// プロセス間での状態共有には以下のアプローチが必要です:
/// - PIDファイルによるプロセス管理
/// - ソケット/ファイル経由のIPC
/// - デーモンモードでの常駐実行
///
/// 現時点では、run_cli() を直接呼び出すアプリケーションから
/// グローバルGatewayインスタンスを操作することを想定しています。
fn execute_gateway_start(opts : GatewayStartOptions) -> CliResult {
  // 設定パスの解決
  let config_path = opts.config_path.unwrap_or("~/.mukuro/config.json")
  // ホストとポートのデフォルト
  let host = opts.host.unwrap_or("127.0.0.1")
  let port = opts.port.unwrap_or(8080)
  // Gateway設定を構築
  let gateway_config : @interfaces.GatewayConfig = {
    host,
    port,
    auth_token: "",
    health_endpoint: @interfaces.HealthEndpointConfig::default(),
    auto_connect_channels: true,
  }
  // グローバルGatewayを起動
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
  // NOTE: 現在はGateway起動後に即終了します。
  // 常駐モードが必要な場合は、イベントループの実装が必要です。
  CliResult::Ok(
    "Gateway started (in-process mode):\n  Host: \{host}\n  Port: \{port}\n  Config: \{config_path}\n  State: \{status.state.to_string()}\n  Debug: \{opts.debug}\n\nNote: Gateway runs in-process. For daemon mode, use an event loop.",
  )
}

///|
/// Gatewayの状態を表示
fn execute_gateway_status() -> CliResult {
  // グローバルGatewayの状態を取得
  let status = global_gateway.status()
  let health_str = match status.health {
    Some(h) => h.overall.to_string()
    None => "unknown"
  }
  let started_str = match status.started_at {
    Some(ts) => "\{ts}"
    None => "not started"
  }
  CliResult::Ok(
    "Gateway Status:\n  State: \{status.state.to_string()}\n  Version: \{status.version}\n  Health: \{health_str}\n  Channels: \{status.connected_channels.length()}\n  Sessions: \{status.active_sessions}\n  Started: \{started_str}",
  )
}

///|
/// Gatewayを停止
fn execute_gateway_stop() -> CliResult {
  // グローバルGatewayを停止
  global_gateway.stop() catch {
    @interfaces.ControlError::AlreadyStopped =>
      return CliResult::Error("Gateway is not running")
    _ => return CliResult::Error("Failed to stop gateway")
  }
  CliResult::Ok("Gateway stopped successfully")
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
    "status" => Command::Gateway(GatewayCommand::Status)
    "stop" => Command::Gateway(GatewayCommand::Stop)
    _ => Command::Gateway(GatewayCommand::Unknown(subcmd))
  }
}

///|
/// gateway startオプションをパース
fn parse_gateway_start_opts(args : ArrayView[String]) -> GatewayStartOptions {
  let opts : GatewayStartOptions = {
    config_path: None,
    host: None,
    port: None,
    debug: false,
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
