///|
/// CLI Types
/// Command enums, option structs, and result types

///|
/// mukuro バージョン
pub let version : String = "0.1.0"

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
  "mukuro - MoonBit Agent Framework v\{version}\n\nUsage: mukuro <command> [options]\n\nCommands:\n  onboard              Initialize mukuro configuration\n  gateway              Start the gateway service\n  gateway status       Show gateway status\n  gateway stop         Stop the gateway service\n  gateway auth-log     Show auth audit log summary\n  cron list            List scheduled cron jobs\n  version              Show version information\n  help                 Show this help message\n\nGateway Options:\n  --config <path>      Path to configuration file\n                       (default: \{default_runtime_config_path()})\n  --host <host>        Host to bind (default: 127.0.0.1)\n  --port <port>        Port to bind (default: 8080)\n  --daemon, -D         Run as daemon (background process)\n  --control-api        Serve HTTP control API (works with --daemon)\n  --debug, -d          Enable debug mode\n\nGateway Status Options:\n  --json               Output status as JSON\n\nGateway Auth Log Options:\n  --since <seconds>    Lookback window in seconds (default: 3600)\n  --json               Output summary as JSON\n\nExamples:\n  mukuro onboard --provider anthropic --api-key sk-xxx\n  mukuro gateway\n  mukuro gateway --config ~/.mukuro/config.json\n  mukuro gateway --daemon\n  mukuro gateway status\n  mukuro gateway stop\n  mukuro cron list"
}

///|
/// バージョン情報を取得
pub fn get_version_message() -> String {
  "mukuro v\{version}"
}
