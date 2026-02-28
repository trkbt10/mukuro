///|
/// Config Loader Tests

///|
test "ConfigLoaderImpl::default creates loader with EnvFirst priority" {
  let loader = ConfigLoaderImpl::default()
  match loader.priority {
    @interfaces.ConfigPriority::EnvFirst => ()
    _ => fail("Expected EnvFirst priority")
  }
}

///|
test "ConfigLoaderImpl::load_from_string parses valid JSON" {
  let loader = ConfigLoaderImpl::default()
  let json =
    #|{
    #|  "agent": {
    #|    "max_iterations": 5,
    #|    "timeout_ms": 60000,
    #|    "bootstrap": "You are a helpful assistant"
    #|  },
    #|  "providers": [
    #|    {
    #|      "name": "anthropic",
    #|      "default_model": "claude-sonnet-4-20250514"
    #|    }
    #|  ]
    #|}
  let config = loader.load_from_string(json)
  inspect(config.agent.max_iterations, content="5")
  inspect(config.agent.timeout_ms, content="60000")
  inspect(config.agent.bootstrap, content="You are a helpful assistant")
  inspect(config.providers.length(), content="1")
  inspect(config.providers[0].name, content="anthropic")
}

///|
test "ConfigLoaderImpl::load_from_string parses empty config" {
  let loader = ConfigLoaderImpl::default()
  let json = "{}"
  let config = loader.load_from_string(json)
  // デフォルト値が使用される
  inspect(config.agent.max_iterations, content="10")
  inspect(config.providers.length(), content="0")
}

///|
test "ConfigLoaderImpl::load_from_string parses flat config format" {
  let loader = ConfigLoaderImpl::default()
  let json =
    #|{
    #|  "provider": "groq",
    #|  "api_key": "gsk_test",
    #|  "model": "openai/gpt-oss-20b",
    #|  "base_url": "https://api.groq.com/openai",
    #|  "use_responses_api": true
    #|}
  let config = loader.load_from_string(json)
  // model_name should come from top-level "model", not the hardcoded default
  inspect(config.agent.model_options.model_name, content="openai/gpt-oss-20b")
  // provider should be extracted from top-level fields
  inspect(config.providers.length(), content="1")
  inspect(config.providers[0].name, content="groq")
  inspect(config.providers[0].base_url, content="Some(\"https://api.groq.com/openai\")")
  inspect(config.providers[0].default_model, content="openai/gpt-oss-20b")
  inspect(config.providers[0].api_key, content="Some(\"gsk_test\")")
}

///|
test "ConfigLoaderImpl::load_from_string parses provider config" {
  let loader = ConfigLoaderImpl::default()
  let json =
    #|{
    #|  "providers": [
    #|    {
    #|      "name": "openai",
    #|      "api_key": "sk-test",
    #|      "default_model": "gpt-4",
    #|      "timeout_ms": 5000,
    #|      "max_retries": 5
    #|    }
    #|  ]
    #|}
  let config = loader.load_from_string(json)
  inspect(config.providers.length(), content="1")
  let provider = config.providers[0]
  inspect(provider.name, content="openai")
  inspect(provider.api_key, content="Some(\"sk-test\")")
  inspect(provider.default_model, content="gpt-4")
  inspect(provider.timeout_ms, content="5000")
  inspect(provider.max_retries, content="5")
}

///|
test "ConfigLoaderImpl::load_from_string parses channel config" {
  let loader = ConfigLoaderImpl::default()
  let json =
    #|{
    #|  "channels": [
    #|    {
    #|      "name": "discord",
    #|      "enabled": true,
    #|      "token": "bot-token-123"
    #|    }
    #|  ]
    #|}
  let config = loader.load_from_string(json)
  inspect(config.channels.length(), content="1")
  let channel = config.channels[0]
  inspect(channel.name, content="discord")
  inspect(channel.enabled, content="true")
  inspect(channel.token, content="Some(\"bot-token-123\")")
}

///|
test "ConfigLoaderImpl::load_from_string parses fallback config" {
  let loader = ConfigLoaderImpl::default()
  let json =
    #|{
    #|  "fallback": {
    #|    "enabled": true,
    #|    "providers": ["openai", "ollama"],
    #|    "cooldown_ms": 10000
    #|  }
    #|}
  let config = loader.load_from_string(json)
  inspect(config.fallback.enabled, content="true")
  inspect(config.fallback.providers.length(), content="2")
  inspect(config.fallback.cooldown_ms, content="10000")
}

///|
test "ConfigLoaderImpl::default_config returns valid defaults" {
  let loader = ConfigLoaderImpl::default()
  let config = loader.default_config()
  inspect(config.agent.max_iterations, content="10")
  inspect(config.agent.timeout_ms, content="120000")
  inspect(config.providers.length(), content="1")
  inspect(config.providers[0].name, content="anthropic")
}

///|
test "ConfigValidatorImpl::validate passes valid config" {
  let validator = ConfigValidatorImpl::new()
  let config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [
      @types.ProviderConfig::new(
        name="test",
        api_key=None,
        default_model="test-model",
      ),
    ],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  validator.validate(config~)
}

///|
test "ConfigValidatorImpl::validate rejects negative max_iterations" {
  let validator = ConfigValidatorImpl::new()
  let config : @types.MukuroConfig = {
    agent: {
      max_iterations: -1,
      model_options: @types.ModelOptions::default(),
      timeout_ms: 60000L,
      bootstrap: "",
    },
    providers: [],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  try {
    @interfaces.ConfigValidator::validate(validator, config~)
    fail("Expected validation error for negative max_iterations")
  } catch {
    _ => () // Expected error
  }
}

///|
test "EnvMapping::default has correct keys" {
  let mapping = @interfaces.EnvMapping::default()
  inspect(mapping.anthropic_api_key, content="ANTHROPIC_API_KEY")
  inspect(mapping.openai_api_key, content="OPENAI_API_KEY")
  inspect(mapping.config_path, content="MUKURO_CONFIG")
  inspect(mapping.log_level, content="MUKURO_LOG_LEVEL")
}

///|
/// テスト用モックFileStore
struct MockFileStore {
  files : Map[String, Bytes]
}

///|
fn MockFileStore::new() -> MockFileStore {
  { files: Map::new() }
}

///|
fn MockFileStore::add_file(
  self : MockFileStore,
  path : String,
  content : String,
) -> Unit {
  // UTF-8でエンコード
  let bytes = @utf8.encode(content.view())
  self.files[path] = bytes
}

///|
pub impl @interfaces.FileStore for MockFileStore with read_file(self, path~) {
  match self.files.get(path) {
    Some(data) => data
    None => raise @builtin.Failure("File not found: \{path}")
  }
}

///|
pub impl @interfaces.FileStore for MockFileStore with write_file(
  self,
  path~,
  data~,
) {
  self.files[path] = data
}

///|
pub impl @interfaces.FileStore for MockFileStore with exists(self, path~) {
  self.files.contains(path)
}

///|
pub impl @interfaces.FileStore for MockFileStore with remove_file(self, path~) {
  self.files.remove(path)
}

///|
pub impl @interfaces.FileStore for MockFileStore with create_dir(self, path~) {
  ignore(self)
  ignore(path)
}

///|
pub impl @interfaces.FileStore for MockFileStore with list_dir(self, path~) {
  ignore(self)
  ignore(path)
  []
}

///|
test "UTF-8 encoding round-trip works" {
  let original = "{}"
  let bytes = @utf8.encode(original.view())
  let decoded = @utf8.decode(bytes[:]) catch { _ => "" }
  inspect(decoded, content="{}")
}

///|
test "FileStoreConfigLoader::load reads config from file" {
  let fs = MockFileStore::new()
  // シンプルなJSON文字列を直接使用
  fs.add_file("/config.json", "{}")
  let loader = FileStoreConfigLoader::with_defaults(file_store=fs)
  let config = loader.load(path="/config.json")
  // デフォルト値が使用される
  inspect(config.agent.max_iterations, content="10")
}

///|
test "FileStoreConfigLoader::load raises error for missing file" {
  let fs = MockFileStore::new()
  let loader = FileStoreConfigLoader::with_defaults(file_store=fs)
  try {
    let _ = loader.load(path="/nonexistent.json")
    fail("Expected FileNotFound error")
  } catch {
    @interfaces.ConfigError::FileNotFound(_) => () // Expected
    _ => fail("Expected FileNotFound error")
  }
}

///|
test "FileStoreConfigLoader::config_exists returns true for existing file" {
  let fs = MockFileStore::new()
  fs.add_file("/config.json", "{}")
  let loader = FileStoreConfigLoader::with_defaults(file_store=fs)
  inspect(loader.config_exists("/config.json"), content="true")
  inspect(loader.config_exists("/missing.json"), content="false")
}

///|
test "FileStoreConfigLoader::load_from_string works like ConfigLoaderImpl" {
  let fs = MockFileStore::new()
  let loader = FileStoreConfigLoader::with_defaults(file_store=fs)
  let json = "{\"agent\": {\"max_iterations\": 15}}"
  let config = loader.load_from_string(json)
  inspect(config.agent.max_iterations, content="15")
}
