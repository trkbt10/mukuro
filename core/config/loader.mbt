///|
/// 設定読み込み実装

///|
/// 設定ローダー実装
pub struct ConfigLoaderImpl {
  /// 環境変数マッピング
  env_mapping : @interfaces.EnvMapping
  /// 設定マージ優先度
  priority : @interfaces.ConfigPriority
}

///|
/// ConfigLoaderImplを新規作成
pub fn ConfigLoaderImpl::new(
  env_mapping~ : @interfaces.EnvMapping,
  priority~ : @interfaces.ConfigPriority,
) -> ConfigLoaderImpl {
  { env_mapping, priority }
}

///|
/// デフォルト設定で作成
pub fn ConfigLoaderImpl::default() -> ConfigLoaderImpl {
  {
    env_mapping: @interfaces.EnvMapping::default(),
    priority: @interfaces.ConfigPriority::EnvFirst,
  }
}

///|
/// JSONから設定をパース
fn parse_config_json(
  content : String,
) -> @types.MukuroConfig raise @interfaces.ConfigError {
  let json : Json = @json.parse(content) catch {
    e => raise @interfaces.ConfigError::ParseError(e.to_string())
  }
  // JSONオブジェクトを解析
  let obj : Map[String, Json] = match json {
    Object(o) => o
    _ =>
      raise @interfaces.ConfigError::ParseError("Config must be a JSON object")
  }
  // agent設定をパース
  let agent : @types.AgentConfig = match obj.get("agent") {
    Some(Object(a)) => parse_agent_config!(a)
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("agent must be an object")
    None => @types.AgentConfig::default()
  }
  // providers設定をパース
  let providers : Array[@types.ProviderConfig] = match obj.get("providers") {
    Some(Array(arr)) => {
      let result : Array[@types.ProviderConfig] = []
      for item in arr {
        match item {
          Object(o) => result.push(parse_provider_config!(o))
          _ =>
            raise @interfaces.ConfigError::ParseError(
              "provider must be an object",
            )
        }
      }
      result
    }
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("providers must be an array")
    None => []
  }
  // fallback設定をパース
  let fallback : @types.FallbackConfig = match obj.get("fallback") {
    Some(Object(f)) => parse_fallback_config!(f)
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("fallback must be an object")
    None => @types.FallbackConfig::new()
  }
  // channels設定をパース
  let channels : Array[@types.ChannelConfig] = match obj.get("channels") {
    Some(Array(arr)) => {
      let result : Array[@types.ChannelConfig] = []
      for item in arr {
        match item {
          Object(o) => result.push(parse_channel_config!(o))
          _ =>
            raise @interfaces.ConfigError::ParseError(
              "channel must be an object",
            )
        }
      }
      result
    }
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("channels must be an array")
    None => []
  }
  { agent, providers, fallback, channels }
}

///|
/// AgentConfigをパース
fn parse_agent_config(
  obj : Map[String, Json],
) -> @types.AgentConfig raise @interfaces.ConfigError {
  let max_iterations = match obj.get("max_iterations") {
    Some(Number(n)) => n.to_int()
    Some(_) =>
      raise @interfaces.ConfigError::ParseError(
        "max_iterations must be a number",
      )
    None => 10
  }
  let timeout_ms : Int64 = match obj.get("timeout_ms") {
    Some(Number(n)) => n.to_int64()
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("timeout_ms must be a number")
    None => 120000L
  }
  let bootstrap = match obj.get("bootstrap") {
    Some(String(s)) => s
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("bootstrap must be a string")
    None => ""
  }
  // model_optionsをパース
  let model_options = match obj.get("model_options") {
    Some(Object(o)) => parse_model_options!(o)
    Some(_) =>
      raise @interfaces.ConfigError::ParseError(
        "model_options must be an object",
      )
    None => @types.ModelOptions::default()
  }
  { max_iterations, timeout_ms, bootstrap, model_options }
}

///|
/// ModelOptionsをパース
fn parse_model_options(
  obj : Map[String, Json],
) -> @types.ModelOptions raise @interfaces.ConfigError {
  let model_name = match obj.get("model_name") {
    Some(String(s)) => s
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("model_name must be a string")
    None => "claude-sonnet-4-20250514"
  }
  let temperature : Double? = match obj.get("temperature") {
    Some(Number(n)) => Some(n)
    Some(Null) => None
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("temperature must be a number")
    None => Some(0.7)
  }
  let max_tokens : Int? = match obj.get("max_tokens") {
    Some(Number(n)) => Some(n.to_int())
    Some(Null) => None
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("max_tokens must be a number")
    None => Some(4096)
  }
  let stop_sequences : Array[String]? = match obj.get("stop_sequences") {
    Some(Array(arr)) => {
      let result : Array[String] = []
      for item in arr {
        match item {
          String(s) => result.push(s)
          _ =>
            raise @interfaces.ConfigError::ParseError(
              "stop_sequences items must be strings",
            )
        }
      }
      Some(result)
    }
    Some(Null) => None
    Some(_) =>
      raise @interfaces.ConfigError::ParseError(
        "stop_sequences must be an array",
      )
    None => None
  }
  { model_name, temperature, max_tokens, stop_sequences }
}

///|
/// ProviderConfigをパース
fn parse_provider_config(
  obj : Map[String, Json],
) -> @types.ProviderConfig raise @interfaces.ConfigError {
  let name = match obj.get("name") {
    Some(String(s)) => s
    Some(_) =>
      raise @interfaces.ConfigError::ParseError(
        "provider name must be a string",
      )
    None =>
      raise @interfaces.ConfigError::ValidationError(
        "provider name is required",
      )
  }
  let api_key : String? = match obj.get("api_key") {
    Some(String(s)) => Some(s)
    Some(Null) => None
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("api_key must be a string")
    None => None
  }
  let base_url : String? = match obj.get("base_url") {
    Some(String(s)) => Some(s)
    Some(Null) => None
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("base_url must be a string")
    None => None
  }
  let default_model = match obj.get("default_model") {
    Some(String(s)) => s
    Some(_) =>
      raise @interfaces.ConfigError::ParseError(
        "default_model must be a string",
      )
    None => "default"
  }
  let timeout_ms = match obj.get("timeout_ms") {
    Some(Number(n)) => n.to_int()
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("timeout_ms must be a number")
    None => 30000
  }
  let max_retries = match obj.get("max_retries") {
    Some(Number(n)) => n.to_int()
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("max_retries must be a number")
    None => 3
  }
  { name, api_key, base_url, default_model, timeout_ms, max_retries }
}

///|
/// FallbackConfigをパース
fn parse_fallback_config(
  obj : Map[String, Json],
) -> @types.FallbackConfig raise @interfaces.ConfigError {
  let enabled = match obj.get("enabled") {
    Some(True) => true
    Some(False) => false
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("enabled must be a boolean")
    None => false
  }
  let providers : Array[String] = match obj.get("providers") {
    Some(Array(arr)) => {
      let result : Array[String] = []
      for item in arr {
        match item {
          String(s) => result.push(s)
          _ =>
            raise @interfaces.ConfigError::ParseError(
              "fallback providers must be strings",
            )
        }
      }
      result
    }
    Some(_) =>
      raise @interfaces.ConfigError::ParseError(
        "fallback providers must be an array",
      )
    None => []
  }
  let cooldown_ms = match obj.get("cooldown_ms") {
    Some(Number(n)) => n.to_int()
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("cooldown_ms must be a number")
    None => 30000
  }
  { enabled, providers, cooldown_ms }
}

///|
/// ChannelConfigをパース
fn parse_channel_config(
  obj : Map[String, Json],
) -> @types.ChannelConfig raise @interfaces.ConfigError {
  let name = match obj.get("name") {
    Some(String(s)) => s
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("channel name must be a string")
    None =>
      raise @interfaces.ConfigError::ValidationError("channel name is required")
  }
  let enabled = match obj.get("enabled") {
    Some(True) => true
    Some(False) => false
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("enabled must be a boolean")
    None => true
  }
  let token : String? = match obj.get("token") {
    Some(String(s)) => Some(s)
    Some(Null) => None
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("token must be a string")
    None => None
  }
  let webhook_url : String? = match obj.get("webhook_url") {
    Some(String(s)) => Some(s)
    Some(Null) => None
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("webhook_url must be a string")
    None => None
  }
  let options : Map[String, Json] = match obj.get("options") {
    Some(Object(o)) => o
    Some(Null) => Map::new()
    Some(_) =>
      raise @interfaces.ConfigError::ParseError("options must be an object")
    None => Map::new()
  }
  { name, enabled, token, webhook_url, options }
}

///|
/// 環境変数からプロバイダ設定をマージ
fn merge_provider_from_env(
  provider : @types.ProviderConfig,
  env : &@interfaces.Environment,
  env_mapping : @interfaces.EnvMapping,
) -> @types.ProviderConfig {
  let api_key = match provider.name {
    "anthropic" =>
      match env.get_env(name=env_mapping.anthropic_api_key) {
        Some(key) => Some(key)
        None => provider.api_key
      }
    "openai" =>
      match env.get_env(name=env_mapping.openai_api_key) {
        Some(key) => Some(key)
        None => provider.api_key
      }
    _ => provider.api_key
  }
  {
    name: provider.name,
    api_key,
    base_url: provider.base_url,
    default_model: provider.default_model,
    timeout_ms: provider.timeout_ms,
    max_retries: provider.max_retries,
  }
}

///|
/// 環境変数をマージした設定を返す
fn merge_config_with_env(
  config : @types.MukuroConfig,
  env : &@interfaces.Environment,
  env_mapping : @interfaces.EnvMapping,
) -> @types.MukuroConfig {
  // プロバイダの環境変数をマージ
  let merged_providers : Array[@types.ProviderConfig] = []
  for provider in config.providers {
    merged_providers.push(merge_provider_from_env(provider, env, env_mapping))
  }
  {
    agent: config.agent,
    providers: merged_providers,
    fallback: config.fallback,
    channels: config.channels,
  }
}

///|
/// ConfigLoader実装
pub impl @interfaces.ConfigLoader for ConfigLoaderImpl with load(self, path~) {
  // このメソッドはファイルI/Oが必要なため、プラットフォーム固有の実装が必要
  // ここではダミー実装（実際の読み込みはFileStore経由で行う）
  ignore(self)
  ignore(path)
  raise @interfaces.ConfigError::FileNotFound(
    "File loading not implemented. Use load_from_string instead.",
  )
}

///|
pub impl @interfaces.ConfigLoader for ConfigLoaderImpl with load_with_env(
  self,
  path~,
  env~,
) {
  // ファイル読み込みとenv mergeの組み合わせ
  ignore(self)
  ignore(path)
  ignore(env)
  raise @interfaces.ConfigError::FileNotFound(
    "File loading not implemented. Use load_from_string_with_env instead.",
  )
}

///|
pub impl @interfaces.ConfigLoader for ConfigLoaderImpl with load_from_env(
  self,
  env~,
) {
  // 環境変数のみからデフォルト設定を構築
  let default_config = self.default_config()
  merge_config_with_env(default_config, env, self.env_mapping)
}

///|
pub impl @interfaces.ConfigLoader for ConfigLoaderImpl with default_config(
  self,
) {
  ignore(self)
  let agent = @types.AgentConfig::default()
  let providers : Array[@types.ProviderConfig] = [
    @types.ProviderConfig::new(
      name="anthropic",
      api_key=None,
      default_model="claude-sonnet-4-20250514",
    ),
  ]
  let fallback : @types.FallbackConfig = @types.FallbackConfig::new()
  let channels : Array[@types.ChannelConfig] = []
  { agent, providers, fallback, channels }
}

///|
/// 文字列から設定を読み込む（ユーティリティ関数）
pub fn ConfigLoaderImpl::load_from_string(
  self : ConfigLoaderImpl,
  content : String,
) -> @types.MukuroConfig raise @interfaces.ConfigError {
  ignore(self)
  parse_config_json(content)
}

///|
/// 文字列から設定を読み込み、環境変数をマージ
pub fn ConfigLoaderImpl::load_from_string_with_env(
  self : ConfigLoaderImpl,
  content : String,
  env : &@interfaces.Environment,
) -> @types.MukuroConfig raise @interfaces.ConfigError {
  let config = parse_config_json(content)
  merge_config_with_env(config, env, self.env_mapping)
}

///|
/// 設定バリデータ実装
pub struct ConfigValidatorImpl {
  /// 厳密モード（trueの場合、より厳格なバリデーションを行う）
  strict_mode : Bool
}

///|
/// ConfigValidatorImplを新規作成
pub fn ConfigValidatorImpl::new() -> ConfigValidatorImpl {
  { strict_mode: false }
}

///|
/// 厳密モードで作成
pub fn ConfigValidatorImpl::strict() -> ConfigValidatorImpl {
  { strict_mode: true }
}

///|
/// ConfigValidator実装
pub impl @interfaces.ConfigValidator for ConfigValidatorImpl with validate(
  self,
  config~,
) {
  ignore(self)
  // max_iterationsのバリデーション
  if config.agent.max_iterations <= 0 {
    raise @interfaces.ConfigError::ValidationError(
      "max_iterations must be positive",
    )
  }
  // timeout_msのバリデーション
  if config.agent.timeout_ms <= 0L {
    raise @interfaces.ConfigError::ValidationError(
      "timeout_ms must be positive",
    )
  }
  // プロバイダのバリデーション
  for provider in config.providers {
    if provider.name.is_empty() {
      raise @interfaces.ConfigError::ValidationError(
        "provider name cannot be empty",
      )
    }
    if provider.timeout_ms <= 0 {
      raise @interfaces.ConfigError::ValidationError(
        "provider timeout_ms must be positive",
      )
    }
    if provider.max_retries < 0 {
      raise @interfaces.ConfigError::ValidationError(
        "provider max_retries cannot be negative",
      )
    }
  }
  // チャネルのバリデーション
  for channel in config.channels {
    if channel.name.is_empty() {
      raise @interfaces.ConfigError::ValidationError(
        "channel name cannot be empty",
      )
    }
  }
}

///|
/// FileStore統合設定ローダー
/// FileStoreを使用して実際にファイルを読み込む
pub struct FileStoreConfigLoader {
  /// ファイルストア
  file_store : &@interfaces.FileStore
  /// 環境変数マッピング
  env_mapping : @interfaces.EnvMapping
  /// 設定マージ優先度
  priority : @interfaces.ConfigPriority
}

///|
/// FileStoreConfigLoaderを新規作成
pub fn FileStoreConfigLoader::new(
  file_store~ : &@interfaces.FileStore,
  env_mapping~ : @interfaces.EnvMapping,
  priority~ : @interfaces.ConfigPriority,
) -> FileStoreConfigLoader {
  { file_store, env_mapping, priority }
}

///|
/// デフォルト設定で作成
pub fn FileStoreConfigLoader::with_defaults(
  file_store~ : &@interfaces.FileStore,
) -> FileStoreConfigLoader {
  {
    file_store,
    env_mapping: @interfaces.EnvMapping::default(),
    priority: @interfaces.ConfigPriority::EnvFirst,
  }
}

///|
/// バイト列を文字列に変換（UTF-8デコード）
fn bytes_to_string(
  data : Bytes,
) -> String raise @interfaces.ConfigError {
  @utf8.decode(data[:]) catch {
    _ => raise @interfaces.ConfigError::ParseError("UTF-8 decode error: invalid byte sequence")
  }
}

///|
/// ConfigLoader実装（FileStore版）
pub impl @interfaces.ConfigLoader for FileStoreConfigLoader with load(
  self,
  path~,
) {
  // ファイル存在確認
  let exists = self.file_store.exists(path~) catch {
    e => raise @interfaces.ConfigError::FileNotFound(e.to_string())
  }
  if not(exists) {
    raise @interfaces.ConfigError::FileNotFound("Config file not found: \{path}")
  }
  // ファイル読み込み
  let data = self.file_store.read_file(path~) catch {
    e => raise @interfaces.ConfigError::FileNotFound(e.to_string())
  }
  // 文字列に変換してパース
  let content = bytes_to_string(data)
  parse_config_json(content)
}

///|
pub impl @interfaces.ConfigLoader for FileStoreConfigLoader with load_with_env(
  self,
  path~,
  env~,
) {
  // ファイルから読み込み
  let config = @interfaces.ConfigLoader::load(self, path~)
  // 環境変数をマージ
  merge_config_with_env(config, env, self.env_mapping)
}

///|
pub impl @interfaces.ConfigLoader for FileStoreConfigLoader with load_from_env(
  self,
  env~,
) {
  // 環境変数のみからデフォルト設定を構築
  let default_config = self.default_config()
  merge_config_with_env(default_config, env, self.env_mapping)
}

///|
pub impl @interfaces.ConfigLoader for FileStoreConfigLoader with default_config(
  self,
) {
  ignore(self)
  let agent = @types.AgentConfig::default()
  let providers : Array[@types.ProviderConfig] = [
    @types.ProviderConfig::new(
      name="anthropic",
      api_key=None,
      default_model="claude-sonnet-4-20250514",
    ),
  ]
  let fallback : @types.FallbackConfig = @types.FallbackConfig::new()
  let channels : Array[@types.ChannelConfig] = []
  { agent, providers, fallback, channels }
}

///|
/// 文字列から設定を読み込む（ユーティリティ関数）
pub fn FileStoreConfigLoader::load_from_string(
  self : FileStoreConfigLoader,
  content : String,
) -> @types.MukuroConfig raise @interfaces.ConfigError {
  ignore(self)
  parse_config_json(content)
}

///|
/// 文字列から設定を読み込み、環境変数をマージ
pub fn FileStoreConfigLoader::load_from_string_with_env(
  self : FileStoreConfigLoader,
  content : String,
  env : &@interfaces.Environment,
) -> @types.MukuroConfig raise @interfaces.ConfigError {
  let config = parse_config_json(content)
  merge_config_with_env(config, env, self.env_mapping)
}

///|
/// 設定ファイルが存在するか確認
pub fn FileStoreConfigLoader::config_exists(
  self : FileStoreConfigLoader,
  path : String,
) -> Bool {
  self.file_store.exists(path~) catch { _ => false }
}

///|
/// 環境変数から設定ファイルパスを取得して読み込み
pub fn FileStoreConfigLoader::load_from_env_path(
  self : FileStoreConfigLoader,
  env : &@interfaces.Environment,
) -> @types.MukuroConfig raise @interfaces.ConfigError {
  // 環境変数から設定ファイルパスを取得
  let config_path = match env.get_env(name=self.env_mapping.config_path) {
    Some(path) => path
    None =>
      raise @interfaces.ConfigError::EnvironmentError(
        "Config path not set in environment variable: \{self.env_mapping.config_path}",
      )
  }
  // ファイルから読み込み、環境変数をマージ
  self.load_with_env(path=config_path, env~)
}
