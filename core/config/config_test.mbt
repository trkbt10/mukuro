///|
/// Config Loader Tests

///|
test "ConfigLoaderImpl::default creates loader with EnvFirst priority" {
  let loader = ConfigLoaderImpl::default()
  match loader.priority {
    @interfaces.ConfigPriority::EnvFirst => ()
    _ => fail!("Expected EnvFirst priority")
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
  let config = loader.load_from_string!(json)
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
  let config = loader.load_from_string!(json)
  // デフォルト値が使用される
  inspect(config.agent.max_iterations, content="10")
  inspect(config.providers.length(), content="0")
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
  let config = loader.load_from_string!(json)
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
  let config = loader.load_from_string!(json)
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
  let config = loader.load_from_string!(json)
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
  }
  validator.validate!(config~)
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
  }
  try {
    @interfaces.ConfigValidator::validate(validator, config~)
    fail!("Expected validation error for negative max_iterations")
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
