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
/// ヘルプメッセージを取得（argparse のコマンドツリーから生成）
pub fn get_help_message() -> String {
  mukuro_command().render_help()
}

///|
/// バージョン情報を取得
pub fn get_version_message() -> String {
  "mukuro v\{version}"
}
