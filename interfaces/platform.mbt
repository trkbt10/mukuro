///|
/// プラットフォーム抽象層
/// Web/Native両環境で共通のインターフェースを定義

///|
/// 時計 トレイト
/// 時刻取得を抽象化
pub(open) trait Clock {
  /// 現在時刻をUnix epoch ミリ秒で取得
  now_ms(Self) -> Int64
  /// 現在時刻をUnix epoch 秒で取得
  now_seconds(Self) -> Int64
}

///|
/// ロガー トレイト
/// ログ出力を抽象化
pub(open) trait Logger {
  /// デバッグログ
  debug(Self, message~ : String) -> Unit
  /// 情報ログ
  info(Self, message~ : String) -> Unit
  /// 警告ログ
  warn(Self, message~ : String) -> Unit
  /// エラーログ
  error(Self, message~ : String) -> Unit
}

///|
/// ログレベル
pub(all) enum LogLevel {
  Debug
  Info
  Warn
  Error
}

///|
/// ログコンテキスト
/// 構造化ログに付与するコンテキスト情報
pub(all) struct LogContext {
  /// リクエストID
  request_id : String?
  /// エージェントID
  agent_id : String?
  /// コンポーネント名
  component : String?
  /// 追加のメタデータ
  extra : Map[String, String]
}

///|
/// 空のLogContext
pub fn LogContext::empty() -> LogContext {
  { request_id: None, agent_id: None, component: None, extra: Map::new() }
}

///|
/// リクエストID付きのLogContext
pub fn LogContext::with_request_id(request_id~ : String) -> LogContext {
  {
    request_id: Some(request_id),
    agent_id: None,
    component: None,
    extra: Map::new(),
  }
}

///|
/// コンポーネント名付きのLogContext
pub fn LogContext::with_component(component~ : String) -> LogContext {
  {
    request_id: None,
    agent_id: None,
    component: Some(component),
    extra: Map::new(),
  }
}

///|
/// 構造化ロガー トレイト
/// JSON形式でログを出力し、コンテキスト情報を付与する
pub(open) trait StructuredLogger {
  /// 構造化ログを出力
  log_structured(
    Self,
    level~ : LogLevel,
    message~ : String,
    context~ : LogContext,
  ) -> Unit
  /// コンテキストを設定した新しいロガーを取得
  with_context(Self, context~ : LogContext) -> Self
  /// リクエストIDを設定した新しいロガーを取得
  with_request_id(Self, request_id~ : String) -> Self
  /// コンポーネント名を設定した新しいロガーを取得
  with_component(Self, component~ : String) -> Self
}

///|
/// ログ出力フォーマット
pub(all) enum LogFormat {
  /// プレーンテキスト
  Plain
  /// JSON形式
  Json
  /// コンパクトJSON（改行なし）
  JsonCompact
}

///|
/// コンポーネント別ログレベル設定
pub(all) struct ComponentLogLevel {
  /// コンポーネント名
  component : String
  /// 最小ログレベル
  min_level : LogLevel
}

///|
/// 環境変数 トレイト
/// 環境変数へのアクセスを抽象化
pub(open) trait Environment {
  /// 環境変数を取得
  get_env(Self, name~ : String) -> String?
  /// 環境変数を設定
  set_env(Self, name~ : String, value~ : String) -> Unit raise
  /// 環境変数を削除
  unset_env(Self, name~ : String) -> Unit raise
  /// 全環境変数を取得
  get_all_env(Self) -> Map[String, String]
}

///|
/// プロセス実行結果
pub(all) struct ProcessResult {
  /// 終了コード
  exit_code : Int
  /// 標準出力
  stdout : Bytes
  /// 標準エラー
  stderr : Bytes
}

///|
/// プロセス実行オプション
pub(all) struct ProcessOptions {
  /// 作業ディレクトリ
  cwd : String?
  /// 環境変数
  env : Map[String, String]
  /// タイムアウト（ミリ秒）
  timeout_ms : Int64?
  /// 標準入力
  stdin : Bytes?
}

///|
/// デフォルトのプロセスオプション
pub fn ProcessOptions::default() -> ProcessOptions {
  { cwd: None, env: {}, timeout_ms: None, stdin: None }
}

///|
/// プロセス実行 トレイト
/// 外部コマンド実行を抽象化
pub(open) trait ProcessExecutor {
  /// コマンドを実行（同期）
  exec(
    Self,
    command~ : String,
    args~ : Array[String],
    options~ : ProcessOptions,
  ) -> ProcessResult raise
  /// コマンドを実行（非同期、コールバック）
  exec_async(
    Self,
    command~ : String,
    args~ : Array[String],
    options~ : ProcessOptions,
    on_complete~ : (ProcessResult) -> Unit,
    on_error~ : (String) -> Unit,
  ) -> Unit
}

///|
/// 乱数生成 トレイト
pub(open) trait Random {
  /// 0.0から1.0の乱数を生成
  random(Self) -> Double
  /// 指定範囲の整数乱数を生成
  random_int(Self, min~ : Int, max~ : Int) -> Int
  /// ランダムなバイト列を生成
  random_bytes(Self, length~ : Int) -> Bytes
  /// UUIDv4を生成
  uuid_v4(Self) -> String
}

///|
/// プラットフォームランタイム
/// 全プラットフォーム機能を統合したインターフェース
pub(all) struct PlatformRuntime {
  /// 時計
  clock : &Clock
  /// ロガー
  logger : &Logger
  /// 環境変数
  env : &Environment
  /// HTTPクライアント
  http : &HttpClient
  /// ファイルストア
  fs : &FileStore
  /// プロセス実行
  process : &ProcessExecutor
  /// タイマー
  timer : &Timer
}

///|
/// プラットフォーム種別
pub(all) enum PlatformType {
  /// Web/ブラウザ環境
  Browser
  /// Node.js環境
  NodeJS
  /// ネイティブ（Linux/macOS/Windows）
  Native(String) // OS name
  /// 不明
  Unknown
}

///|
/// プラットフォーム情報
pub(all) struct PlatformInfo {
  /// プラットフォーム種別
  platform_type : PlatformType
  /// アーキテクチャ
  arch : String
  /// バージョン
  version : String
}
