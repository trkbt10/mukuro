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
  // JSONオブジェクトを解析
  let obj : Map[String, Json] = match
    @config_json_accessors.parse_root_object(content) {
    Ok(root) => root
    Err(message) => raise @interfaces.ConfigError::ParseError(message)
  }
  // agent設定をパース
  // flat config format (top-level "model", "provider", etc.) にも対応
  let agent : @types.AgentConfig = match
    @config_json_accessors.optional_object_field(obj, "agent") {
    Ok(Some(agent_obj)) => parse_agent_config(agent_obj)
    Ok(None) => parse_agent_config_from_flat(obj)
    Err(message) => raise @interfaces.ConfigError::ParseError(message)
  }
  // providers設定をパース
  let providers : Array[@types.ProviderConfig] = match
    @config_json_accessors.optional_array_field(obj, "providers") {
    Ok(Some(arr)) => {
      let result : Array[@types.ProviderConfig] = []
      for item in arr {
        match item {
          Object(o) => result.push(parse_provider_config(o))
          _ =>
            raise @interfaces.ConfigError::ParseError(
              "provider must be an object",
            )
        }
      }
      result
    }
    Ok(None) => parse_providers_from_flat(obj)
    Err(message) => raise @interfaces.ConfigError::ParseError(message)
  }
  // fallback設定をパース
  let fallback : @types.FallbackConfig = match
    @config_json_accessors.optional_object_field(obj, "fallback") {
    Ok(Some(fallback_obj)) => parse_fallback_config(fallback_obj)
    Ok(None) => @types.FallbackConfig::new()
    Err(message) => raise @interfaces.ConfigError::ParseError(message)
  }
  // channels設定をパース
  let channels : Array[@types.ChannelConfig] = match
    @config_json_accessors.optional_array_field(obj, "channels") {
    Ok(Some(arr)) => {
      let result : Array[@types.ChannelConfig] = []
      for item in arr {
        match item {
          Object(o) => result.push(parse_channel_config(o))
          _ =>
            raise @interfaces.ConfigError::ParseError(
              "channel must be an object",
            )
        }
      }
      result
    }
    Ok(None) => []
    Err(message) => raise @interfaces.ConfigError::ParseError(message)
  }
  { agent, providers, fallback, channels, thinking: @types.ThinkingConfig::default() }
}

///|
/// Flat config format からProviderConfigの配列を構築
/// top-level の "provider", "api_key", "base_url", "model" から推定
fn parse_providers_from_flat(
  obj : Map[String, Json],
) -> Array[@types.ProviderConfig] {
  let provider_name = match obj.get("provider") {
    Some(String(s)) => s
    _ => return []
  }
  if provider_name.length() == 0 {
    return []
  }
  let api_key : String? = match obj.get("api_key") {
    Some(String(s)) => if s.length() > 0 { Some(s) } else { None }
    _ => None
  }
  let base_url : String? = match obj.get("base_url") {
    Some(String(s)) => if s.length() > 0 { Some(s) } else { None }
    _ => None
  }
  let default_model = match obj.get("model") {
    Some(String(s)) => if s.length() > 0 { s } else { "default" }
    _ =>
      match obj.get("default_model") {
        Some(String(s)) => if s.length() > 0 { s } else { "default" }
        _ => "default"
      }
  }
  [
    {
      name: provider_name,
      api_key,
      base_url,
      default_model,
      timeout_ms: 30000,
      max_retries: 3,
    },
  ]
}

///|
/// Flat config format からAgentConfigを構築
/// top-level の "model", "provider", "base_url" 等から推定
fn parse_agent_config_from_flat(
  obj : Map[String, Json],
) -> @types.AgentConfig {
  let mut model_options = @types.ModelOptions::default()
  // top-level "model" フィールドを model_name にマッピング
  match obj.get("model") {
    Some(String(m)) =>
      if m.length() > 0 {
        model_options = { ..model_options, model_name: m }
      }
    _ => ()
  }
  // top-level "default_model" も fallback として利用
  if model_options.model_name == "claude-sonnet-4-20250514" {
    match obj.get("default_model") {
      Some(String(m)) =>
        if m.length() > 0 {
          model_options = { ..model_options, model_name: m }
        }
      _ => ()
    }
  }
  { ..@types.AgentConfig::default(), model_options }
}

///|
/// AgentConfigをパース
fn parse_agent_config(
  obj : Map[String, Json],
) -> @types.AgentConfig raise @interfaces.ConfigError {
  let max_iterations = match
    @config_json_accessors.int_field_or_default(obj, "max_iterations", 10) {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let timeout_ms = match
    @config_json_accessors.int64_field_or_default(obj, "timeout_ms", 120000L) {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let bootstrap = match
    @config_json_accessors.string_field_or_default(obj, "bootstrap", "") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  // model_optionsをパース
  let model_options = match
    @config_json_accessors.optional_object_field(obj, "model_options") {
    Ok(Some(model_options_obj)) => parse_model_options(model_options_obj)
    Ok(None) => @types.ModelOptions::default()
    Err(message) => raise @interfaces.ConfigError::ParseError(message)
  }
  { max_iterations, timeout_ms, bootstrap, model_options }
}

///|
/// ModelOptionsをパース
fn parse_model_options(
  obj : Map[String, Json],
) -> @types.ModelOptions raise @interfaces.ConfigError {
  let model_name = match
    @config_json_accessors.string_field_or_default(
      obj, "model_name", "claude-sonnet-4-20250514",
    ) {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let temperature : Double? = match
    @config_json_accessors.optional_double_field(obj, "temperature") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let max_tokens : Int? = match
    @config_json_accessors.optional_int_field(obj, "max_tokens") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  // stop_sequences: None if not specified
  let stop_sequences : Array[String]? = match
    @config_json_accessors.optional_array_field(obj, "stop_sequences") {
    Ok(Some(arr)) => {
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
    Ok(None) => None
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  { model_name, temperature, max_tokens, stop_sequences }
}

///|
/// ProviderConfigをパース
fn parse_provider_config(
  obj : Map[String, Json],
) -> @types.ProviderConfig raise @interfaces.ConfigError {
  let name = match @config_json_accessors.required_string_field(obj, "name") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ValidationError(msg)
  }
  let api_key = match
    @config_json_accessors.optional_string_field(obj, "api_key") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let base_url = match
    @config_json_accessors.optional_string_field(obj, "base_url") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let default_model = match
    @config_json_accessors.string_field_or_default(
      obj, "default_model", "default",
    ) {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let timeout_ms = match
    @config_json_accessors.int_field_or_default(obj, "timeout_ms", 30000) {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let max_retries = match
    @config_json_accessors.int_field_or_default(obj, "max_retries", 3) {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  { name, api_key, base_url, default_model, timeout_ms, max_retries }
}

///|
/// FallbackConfigをパース
fn parse_fallback_config(
  obj : Map[String, Json],
) -> @types.FallbackConfig raise @interfaces.ConfigError {
  let enabled = match
    @config_json_accessors.bool_field_or_default(obj, "enabled", false) {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let providers = match
    @config_json_accessors.string_array_field_or_default(obj, "providers") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let cooldown_ms = match
    @config_json_accessors.int_field_or_default(obj, "cooldown_ms", 30000) {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  { enabled, providers, cooldown_ms }
}

///|
/// ChannelConfigをパース
fn parse_channel_config(
  obj : Map[String, Json],
) -> @types.ChannelConfig raise @interfaces.ConfigError {
  let name = match @config_json_accessors.required_string_field(obj, "name") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ValidationError(msg)
  }
  let enabled = match
    @config_json_accessors.bool_field_or_default(obj, "enabled", true) {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let token = match @config_json_accessors.optional_string_field(obj, "token") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let webhook_url = match
    @config_json_accessors.optional_string_field(obj, "webhook_url") {
    Ok(v) => v
    Err(msg) => raise @interfaces.ConfigError::ParseError(msg)
  }
  let options : Map[String, Json] = match
    @config_json_accessors.optional_object_field(obj, "options") {
    Ok(Some(option_obj)) => option_obj
    Ok(None) => Map::new()
    Err(message) => raise @interfaces.ConfigError::ParseError(message)
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
    thinking: config.thinking,
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
pub impl @interfaces.ConfigLoader for ConfigLoaderImpl with default_config(self) {
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
  { agent, providers, fallback, channels, thinking: @types.ThinkingConfig::default() }
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
fn bytes_to_string(data : Bytes) -> String raise @interfaces.ConfigError {
  @utf8.decode(data[:]) catch {
    _ =>
      raise @interfaces.ConfigError::ParseError(
        "UTF-8 decode error: invalid byte sequence",
      )
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
    raise @interfaces.ConfigError::FileNotFound(
      "Config file not found: \{path}",
    )
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
  { agent, providers, fallback, channels, thinking: @types.ThinkingConfig::default() }
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
  self.file_store.exists(path~) catch {
    _ => false
  }
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
