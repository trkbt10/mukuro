///|
/// 設定読み込みインターフェース

///|
/// 設定読み込みエラー
pub(all) suberror ConfigError {
  /// ファイルが見つからない
  FileNotFound(String)
  /// パースエラー
  ParseError(String)
  /// バリデーションエラー
  ValidationError(String)
  /// 環境変数エラー
  EnvironmentError(String)
}

///|
/// 設定読み込み トレイト
/// 設定ファイルと環境変数からの設定読み込みを抽象化
pub(open) trait ConfigLoader {
  /// 設定ファイルから読み込み
  load(Self, path~ : String) -> @types.MukuroConfig raise ConfigError
  /// 設定ファイルと環境変数をマージして読み込み
  load_with_env(
    Self,
    path~ : String,
    env~ : &Environment,
  ) -> @types.MukuroConfig raise ConfigError
  /// 環境変数のみから読み込み
  load_from_env(Self, env~ : &Environment) -> @types.MukuroConfig raise ConfigError
  /// デフォルト設定を取得
  default_config(Self) -> @types.MukuroConfig
}

///|
/// 設定バリデータ トレイト
/// 設定値の検証を行う
pub(open) trait ConfigValidator {
  /// 設定を検証
  validate(Self, config~ : @types.MukuroConfig) -> Unit raise ConfigError
}

///|
/// 設定マージ優先度
/// 設定値のマージ時の優先度を定義
pub(all) enum ConfigPriority {
  /// 環境変数が最優先
  EnvFirst
  /// ファイルが最優先
  FileFirst
  /// デフォルト値のみ
  DefaultOnly
}

///|
/// 設定ソース
/// 設定値の取得元を追跡
pub(all) struct ConfigSource {
  /// ソース種別
  source_type : ConfigSourceType
  /// ソースパス（ファイルパスまたは環境変数名）
  path : String
}

///|
/// 設定ソース種別
pub(all) enum ConfigSourceType {
  /// ファイルから読み込み
  File
  /// 環境変数から読み込み
  Environment
  /// デフォルト値
  Default
}

///|
/// 環境変数マッピング
/// 設定キーと環境変数名のマッピングを定義
pub(all) struct EnvMapping {
  /// Anthropic APIキーの環境変数名
  anthropic_api_key : String
  /// OpenAI APIキーの環境変数名
  openai_api_key : String
  /// 設定ファイルパスの環境変数名
  config_path : String
  /// ログレベルの環境変数名
  log_level : String
}

///|
/// デフォルトの環境変数マッピング
pub fn EnvMapping::default() -> EnvMapping {
  {
    anthropic_api_key: "ANTHROPIC_API_KEY",
    openai_api_key: "OPENAI_API_KEY",
    config_path: "MUKURO_CONFIG",
    log_level: "MUKURO_LOG_LEVEL",
  }
}
