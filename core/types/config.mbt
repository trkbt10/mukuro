// ============================================================
// OpenClaw互換: システムプロンプト設定
// ============================================================

///|
/// システムプロンプトモード
pub(all) enum SystemPromptMode {
  /// 既存のプロンプトに追記
  Append
  /// 既存のプロンプトを置換
  Replace
}

///|
/// SystemPromptMode to string
pub fn SystemPromptMode::to_string(self : SystemPromptMode) -> String {
  match self {
    SystemPromptMode::Append => "append"
    SystemPromptMode::Replace => "replace"
  }
}

///|
/// システムプロンプト適用タイミング
pub(all) enum SystemPromptWhen {
  /// 最初のメッセージのみ
  First
  /// 常に適用
  Always
  /// 適用しない
  Never
}

///|
/// SystemPromptWhen to string
pub fn SystemPromptWhen::to_string(self : SystemPromptWhen) -> String {
  match self {
    SystemPromptWhen::First => "first"
    SystemPromptWhen::Always => "always"
    SystemPromptWhen::Never => "never"
  }
}

///|
/// システムプロンプト設定
pub(all) struct SystemPromptConfig {
  /// モード（追記/置換）
  mode : SystemPromptMode
  /// 適用タイミング
  when : SystemPromptWhen
  /// プロンプト内容
  content : String
}

///|
/// デフォルトのシステムプロンプト設定
pub fn SystemPromptConfig::default() -> SystemPromptConfig {
  { mode: SystemPromptMode::Append, when: SystemPromptWhen::First, content: "" }
}

// ============================================================
// OpenClaw互換: Thinking設定
// ============================================================

///|
/// Thinkingレベル
pub(all) enum ThinkingLevel {
  Off
  Minimal
  Low
  Medium
  High
  XHigh
}

///|
/// ThinkingLevel to string
pub fn ThinkingLevel::to_string(self : ThinkingLevel) -> String {
  match self {
    ThinkingLevel::Off => "off"
    ThinkingLevel::Minimal => "minimal"
    ThinkingLevel::Low => "low"
    ThinkingLevel::Medium => "medium"
    ThinkingLevel::High => "high"
    ThinkingLevel::XHigh => "xhigh"
  }
}

///|
/// ThinkingLevel from string
pub fn ThinkingLevel::from_string(s : String) -> ThinkingLevel {
  match s.to_lower() {
    "off" | "none" | "disabled" => ThinkingLevel::Off
    "minimal" | "min" => ThinkingLevel::Minimal
    "low" => ThinkingLevel::Low
    "medium" | "med" => ThinkingLevel::Medium
    "high" => ThinkingLevel::High
    "xhigh" | "max" | "maximum" => ThinkingLevel::XHigh
    _ => ThinkingLevel::Off
  }
}

///|
/// Thinking設定
pub(all) struct ThinkingConfig {
  /// Thinking機能の有効/無効
  enabled : Bool
  /// Thinkingレベル
  level : ThinkingLevel
  /// トークン予算（オプション）
  budget_tokens : Int?
}

///|
/// デフォルトのThinking設定
pub fn ThinkingConfig::default() -> ThinkingConfig {
  { enabled: false, level: ThinkingLevel::Off, budget_tokens: None }
}

// ============================================================
// OpenClaw互換: コンテキスト刈り込み設定
// ============================================================

///|
/// 刈り込み戦略
pub(all) enum PruningStrategy {
  /// キャッシュTTLベース
  CacheTTL(Int64)
  /// ソフトトリム（最大メッセージ数）
  SoftTrim(Int)
  /// ハードクリア
  HardClear
}

///|
/// PruningStrategy to string
pub fn PruningStrategy::to_string(self : PruningStrategy) -> String {
  match self {
    PruningStrategy::CacheTTL(ttl) => "cache_ttl:\{ttl}"
    PruningStrategy::SoftTrim(max) => "soft_trim:\{max}"
    PruningStrategy::HardClear => "hard_clear"
  }
}

///|
/// コンテキスト刈り込み設定
pub(all) struct ContextPruningConfig {
  /// 刈り込み戦略
  strategy : PruningStrategy
  /// システムプロンプトを保持するか
  preserve_system : Bool
  /// 最小コンテキストトークン数
  min_context_tokens : Int?
}

///|
/// デフォルトの刈り込み設定
pub fn ContextPruningConfig::default() -> ContextPruningConfig {
  {
    strategy: PruningStrategy::SoftTrim(100),
    preserve_system: true,
    min_context_tokens: None,
  }
}

// ============================================================
// OpenClaw互換: モデルエイリアス
// ============================================================

///|
/// モデルエイリアス
pub(all) struct ModelAlias {
  /// エイリアス名
  alias_name : String
  /// プロバイダ名
  provider : String
  /// 実際のモデル名
  model_name : String
}

// ============================================================
// OpenClaw互換: リトライ設定
// ============================================================

///|
/// リトライ設定
pub(all) struct RetryConfig {
  /// 最大リトライ回数
  max_retries : Int
  /// 初期バックオフ（ミリ秒）
  initial_backoff_ms : Int
  /// 最大バックオフ（ミリ秒）
  max_backoff_ms : Int
  /// バックオフ乗数
  backoff_multiplier : Double
  /// リトライ対象のHTTPステータスコード
  retry_status_codes : Array[Int]
}

///|
/// デフォルトのリトライ設定
pub fn RetryConfig::default() -> RetryConfig {
  {
    max_retries: 3,
    initial_backoff_ms: 1000,
    max_backoff_ms: 30000,
    backoff_multiplier: 2.0,
    retry_status_codes: [429, 500, 502, 503, 504],
  }
}

// ============================================================
// 既存の型定義
// ============================================================

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
  /// Responses API を使用するか（OpenAI互換プロバイダ向け）
  use_responses_api : Bool
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
  /// Thinking設定
  thinking : ThinkingConfig
}

///|
/// ModelOptionsのデフォルト値
pub fn ModelOptions::default() -> ModelOptions {
  { model_name: "", temperature: None, max_tokens: None, stop_sequences: None }
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
  use_responses_api? : Bool = false,
) -> ProviderConfig {
  {
    name,
    api_key,
    base_url: None,
    default_model,
    timeout_ms: 30000,
    max_retries: 3,
    use_responses_api,
  }
}

///|
/// FallbackConfigのデフォルト値
pub fn FallbackConfig::new() -> FallbackConfig {
  { enabled: false, providers: [], cooldown_ms: 30000 }
}

///|
/// ChannelConfigを新規作成
pub fn ChannelConfig::new(name~ : String, token~ : String?) -> ChannelConfig {
  { name, enabled: true, token, webhook_url: None, options: {} }
}

// ============================================================
// JSONシリアライズ
// ============================================================

///|
/// ThinkingConfig to JSON
pub fn ThinkingConfig::to_json(self : ThinkingConfig) -> Json {
  let obj : Map[String, Json] = {}
  obj["enabled"] = Json::boolean(self.enabled)
  obj["level"] = Json::string(self.level.to_string())
  match self.budget_tokens {
    Some(n) => obj["budget_tokens"] = Json::number(n.to_double())
    None => ()
  }
  Json::object(obj)
}

///|
/// ModelOptions to JSON
pub fn ModelOptions::to_json(self : ModelOptions) -> Json {
  let obj : Map[String, Json] = {}
  obj["model_name"] = Json::string(self.model_name)
  match self.temperature {
    Some(t) => obj["temperature"] = Json::number(t)
    None => ()
  }
  match self.max_tokens {
    Some(n) => obj["max_tokens"] = Json::number(n.to_double())
    None => ()
  }
  match self.stop_sequences {
    Some(seqs) => obj["stop_sequences"] = Json::array(seqs.map(Json::string))
    None => ()
  }
  Json::object(obj)
}

///|
/// ProviderConfig to JSON
pub fn ProviderConfig::to_json(self : ProviderConfig) -> Json {
  let obj : Map[String, Json] = {}
  obj["name"] = Json::string(self.name)
  match self.api_key {
    Some(k) => obj["api_key"] = Json::string(k)
    None => ()
  }
  match self.base_url {
    Some(u) => obj["base_url"] = Json::string(u)
    None => ()
  }
  obj["default_model"] = Json::string(self.default_model)
  obj["timeout_ms"] = Json::number(self.timeout_ms.to_double())
  obj["max_retries"] = Json::number(self.max_retries.to_double())
  obj["use_responses_api"] = Json::boolean(self.use_responses_api)
  Json::object(obj)
}

///|
/// FallbackConfig to JSON
pub fn FallbackConfig::to_json(self : FallbackConfig) -> Json {
  let obj : Map[String, Json] = {}
  obj["enabled"] = Json::boolean(self.enabled)
  obj["providers"] = Json::array(self.providers.map(Json::string))
  obj["cooldown_ms"] = Json::number(self.cooldown_ms.to_double())
  Json::object(obj)
}

///|
/// ChannelConfig to JSON
pub fn ChannelConfig::to_json(self : ChannelConfig) -> Json {
  let obj : Map[String, Json] = {}
  obj["name"] = Json::string(self.name)
  obj["enabled"] = Json::boolean(self.enabled)
  match self.token {
    Some(t) => obj["token"] = Json::string(t)
    None => ()
  }
  match self.webhook_url {
    Some(u) => obj["webhook_url"] = Json::string(u)
    None => ()
  }
  if self.options.length() > 0 {
    obj["options"] = Json::object(self.options)
  }
  Json::object(obj)
}

///|
/// AgentConfig to JSON
pub fn AgentConfig::to_json(self : AgentConfig) -> Json {
  let obj : Map[String, Json] = {}
  obj["max_iterations"] = Json::number(self.max_iterations.to_double())
  obj["model_options"] = self.model_options.to_json()
  obj["timeout_ms"] = Json::number(self.timeout_ms.to_double())
  if self.bootstrap.length() > 0 {
    obj["bootstrap"] = Json::string(self.bootstrap)
  }
  Json::object(obj)
}

///|
/// MukuroConfig to JSON
pub fn MukuroConfig::to_json(self : MukuroConfig) -> Json {
  let obj : Map[String, Json] = {}
  obj["agent"] = self.agent.to_json()
  obj["providers"] = Json::array(self.providers.map(fn(p) { p.to_json() }))
  obj["fallback"] = self.fallback.to_json()
  if self.channels.length() > 0 {
    obj["channels"] = Json::array(self.channels.map(fn(c) { c.to_json() }))
  }
  obj["thinking"] = self.thinking.to_json()
  Json::object(obj)
}
