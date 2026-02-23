///|
/// モデル呼び出しオプション
pub(all) struct ModelOptions {
  /// モデル名
  model_name : String
  /// 温度パラメータ
  temperature : Double?
  /// 最大トークン数
  max_tokens : Int?
  /// 停止シーケンス
  stop_sequences : Array[String]?
}

///|
/// モデルプロバイダ設定
pub(all) struct ProviderConfig {
  /// プロバイダ名（anthropic, openai, ollama等）
  name : String
  /// APIキー
  api_key : String?
  /// ベースURL
  base_url : String?
  /// デフォルトモデル
  default_model : String
  /// タイムアウト（ミリ秒）
  timeout_ms : Int
  /// リトライ回数
  max_retries : Int
}

///|
/// フォールバック設定
pub(all) struct FallbackConfig {
  /// 有効かどうか
  enabled : Bool
  /// フォールバック先プロバイダ名のリスト
  providers : Array[String]
  /// クールダウン時間（ミリ秒）
  cooldown_ms : Int
}

///|
/// チャネル設定
pub(all) struct ChannelConfig {
  /// チャネル名
  name : String
  /// 有効かどうか
  enabled : Bool
  /// 認証トークン
  token : String?
  /// Webhook URL
  webhook_url : String?
  /// チャネル固有設定
  options : Map[String, Json]
}

///|
/// エージェント設定
pub(all) struct AgentConfig {
  /// 最大反復回数（ツール呼び出しループの制限）
  max_iterations : Int
  /// モデルオプション
  model_options : ModelOptions
  /// タイムアウト（ミリ秒）
  timeout_ms : Int64
  /// ブートストラップ指示（システムプロンプト）
  bootstrap : String
}

///|
/// 全体設定
pub(all) struct MukuroConfig {
  /// エージェント設定
  agent : AgentConfig
  /// プロバイダ設定のリスト
  providers : Array[ProviderConfig]
  /// フォールバック設定
  fallback : FallbackConfig
  /// チャネル設定のリスト
  channels : Array[ChannelConfig]
}

///|
/// ModelOptionsのデフォルト値
pub fn ModelOptions::default() -> ModelOptions {
  {
    model_name: "claude-sonnet-4-20250514",
    temperature: Some(0.7),
    max_tokens: Some(4096),
    stop_sequences: None,
  }
}

///|
/// AgentConfigのデフォルト値
pub fn AgentConfig::default() -> AgentConfig {
  {
    max_iterations: 10,
    model_options: ModelOptions::default(),
    timeout_ms: 120000L,
    bootstrap: "",
  }
}

///|
/// ProviderConfigを新規作成
pub fn ProviderConfig::new(
  name~ : String,
  api_key~ : String?,
  default_model~ : String,
) -> ProviderConfig {
  {
    name,
    api_key,
    base_url: None,
    default_model,
    timeout_ms: 30000,
    max_retries: 3,
  }
}

///|
/// ChannelConfigを新規作成
pub fn ChannelConfig::new(name~ : String, token~ : String?) -> ChannelConfig {
  { name, enabled: true, token, webhook_url: None, options: {} }
}
