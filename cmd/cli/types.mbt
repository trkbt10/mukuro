///|
/// CLI Types
/// Command enums, option structs, and result types

///|
/// mukuro バージョン
pub let version : String = "0.1.0"

///|
/// グローバルオプション（全コマンド共通）
pub(all) struct GlobalOptions {
  /// パスモード: Standard（デフォルト）、Local、Custom
  mut path_mode : @config.PathMode
}

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
  /// Agent実行（CLI REPL / 単発実行）
  Agent(AgentOptions)
  /// Config操作
  Config(ConfigCommand)
  /// Cron操作
  Cron(CronCommand)
  /// Service操作
  Service(ServiceCommand)
  /// デーモン子プロセス（内部使用）
  DaemonChild(String)
  /// 不明なコマンド
  Unknown(String)
}

///|
/// Configサブコマンド
pub(all) enum ConfigCommand {
  /// 設定ファイルパスを表示
  Path
  /// 現在の設定を表示
  Show
  /// プロバイダ一覧を表示
  Providers
  /// 不明
  Unknown(String)
}

///|
/// Agentコマンドオプション
pub(all) struct AgentOptions {
  /// 単発メッセージ（指定時はREPLに入らず1回実行して終了）
  mut message : String?
  /// 設定ファイルパス
  mut config_path : String?
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
  /// 認証監査ログの集計
  AuthLog(GatewayAuthLogOptions)
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
pub(all) struct GatewayAuthLogOptions {
  /// 何秒前まで遡るか（0以下で全件）
  mut since_seconds : Int64
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
/// Serviceサブコマンド
pub(all) enum ServiceCommand {
  /// サービスをインストール
  Install(ServiceInstallOptions)
  /// サービスをアンインストール
  Uninstall
  /// サービスを開始
  Start
  /// サービスを停止
  Stop
  /// サービスを再起動
  Restart
  /// サービスの状態を表示
  Status(ServiceStatusOptions)
  /// サービスのログを表示
  Logs(ServiceLogsOptions)
  /// 不明
  Unknown(String)
}

///|
/// サービスインストールオプション
pub(all) struct ServiceInstallOptions {
  /// ユーザーレベルでインストール（デフォルト）
  mut user : Bool
  /// システムレベルでインストール
  mut system : Bool
  /// 設定ファイルパス
  mut config_path : String?
  /// 自動起動を有効化
  mut auto_start : Bool
}

///|
/// サービス状態表示オプション
pub(all) struct ServiceStatusOptions {
  /// JSON形式で出力
  mut json : Bool
}

///|
/// サービスログ表示オプション
pub(all) struct ServiceLogsOptions {
  /// フォロー（リアルタイム表示）
  mut follow : Bool
  /// 表示行数
  mut lines : Int
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
  /// ベースURL（カスタムプロバイダー用）
  mut base_url : String?
  /// 出力先設定ファイルパス
  mut output_path : String?
  /// 設定をリセットして初期化
  mut reset : Bool
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
/// config_path: デフォルト設定ファイルパス（表示用）
pub fn get_help_message(config_path~ : String) -> String {
  let global_opts = "Global Options:\n  --local              Use .mukuro in current directory (project-local)\n  --data-dir <path>    Use custom data directory"
  let gateway_opts = "Gateway Options:\n  --config <path>      Path to configuration file\n                       (default: \{config_path})\n  --host <host>        Host to bind (default: \{@interfaces.gateway_default_host})\n  --port <port>        Port to bind (default: \{@interfaces.gateway_default_port})\n  --daemon, -D         Run as daemon (background process)\n  --control-api        Serve HTTP control API (works with --daemon)\n  --debug, -d          Enable debug mode"
  let status_opts = "Gateway Status Options:\n  --json               Output status as JSON"
  let auth_log_opts = "Gateway Auth Log Options:\n  --since <seconds>    Lookback window in seconds (default: 3600)\n  --json               Output summary as JSON"
  let service_opts = "Service Options:\n  install [--user|--system] [--config PATH] [--auto-start]\n                       Install as system service\n  uninstall            Uninstall system service\n  start                Start the service\n  stop                 Stop the service\n  restart              Restart the service\n  status [--json]      Show service status\n  logs [-f] [-n LINES] View service logs"
  let agent_opts = "Agent Options:\n  -m, --message <msg>  Send a single message and exit\n  --config <path>      Path to configuration file"
  let onboard_opts = "Onboard Options:\n  --provider <name>    Provider name (anthropic, openai, gemini, deepseek, groq,\n                       openrouter, ollama, moonshot, or custom)\n  --api-key <key>      API key (auto-detected from env if not specified)\n  --model <model>      Default model (auto-set from provider if not specified)\n  --base-url <url>     Base URL for custom/OpenAI-compatible endpoints\n  --output <path>      Config file path\n  --reset              Reset config before writing (default: merge)"
  let examples = "Examples:\n  mukuro onboard                                 # Show providers & detected keys\n  mukuro onboard --provider anthropic --api-key sk-xxx\n  mukuro onboard --provider openai               # Use OPENAI_API_KEY env var\n  mukuro onboard --provider deepseek --base-url https://api.deepseek.com/v1\n  mukuro onboard --provider anthropic --reset     # Reset and reconfigure\n  mukuro gateway\n  mukuro gateway --daemon\n  mukuro gateway status\n  mukuro agent -m \"What is MoonBit?\"\n  mukuro agent                     # Interactive REPL\n  mukuro --local gateway          # Use project-local .mukuro\n  mukuro config providers          # List configured providers\n  mukuro service install --user\n  mukuro service status"
  "mukuro - MoonBit Agent Framework v\{version}\n\nUsage: mukuro [global-options] <command> [options]\n\nCommands:\n  onboard              Initialize mukuro configuration\n  gateway              Start the gateway service\n  gateway status       Show gateway status\n  gateway stop         Stop the gateway service\n  gateway auth-log     Show auth audit log summary\n  agent                Interactive agent REPL or single-shot execution\n  config               View configuration\n  service              Manage system service\n  cron list            List scheduled cron jobs\n  version              Show version information\n  help                 Show this help message\n\n\{global_opts}\n\n\{onboard_opts}\n\n\{gateway_opts}\n\n\{agent_opts}\n\n\{status_opts}\n\n\{auth_log_opts}\n\n\{service_opts}\n\n\{examples}"
}

///|
/// バージョン情報を取得
pub fn get_version_message() -> String {
  "mukuro v\{version}"
}
