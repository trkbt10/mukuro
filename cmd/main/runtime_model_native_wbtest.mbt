///|
/// RuntimeModelOrchestrator テスト
/// validate_provider_config, ConfigProviderResolver,
/// ModelOrchestrator::call の config 経路を検証

// =============================================================================
// validate_provider_config
// =============================================================================

///|
test "validate_provider_config rejects empty provider name" {
  let p = @types.ProviderConfig::new(name="", api_key=None, default_model="m")
  match validate_provider_config(p) {
    Some(msg) => assert_true(msg.contains("provider is required"))
    None => fail("expected validation error for empty provider name")
  }
}

///|
test "validate_provider_config rejects openai-compatible without base_url" {
  let p = @types.ProviderConfig::new(
    name="groq",
    api_key=Some("key"),
    default_model="llama",
  )
  match validate_provider_config(p) {
    Some(msg) => assert_true(msg.contains("base_url is required"))
    None => fail("expected validation error for missing base_url")
  }
}

///|
test "validate_provider_config rejects openai-compatible with blank base_url" {
  let p : @types.ProviderConfig = {
    name: "openai",
    api_key: Some("sk-test"),
    base_url: Some("   "),
    default_model: "gpt-4",
    timeout_ms: 30000,
    max_retries: 3,
    use_responses_api: false,
  }
  match validate_provider_config(p) {
    Some(msg) => assert_true(msg.contains("base_url is required"))
    None => fail("expected validation error for blank base_url")
  }
}

///|
test "validate_provider_config rejects openai-compatible without model" {
  let p : @types.ProviderConfig = {
    name: "groq",
    api_key: Some("key"),
    base_url: Some("https://api.groq.com/openai"),
    default_model: "",
    timeout_ms: 30000,
    max_retries: 3,
    use_responses_api: false,
  }
  match validate_provider_config(p) {
    Some(msg) => assert_true(msg.contains("model is required"))
    None => fail("expected validation error for empty model")
  }
}

///|
test "validate_provider_config accepts valid openai-compatible provider" {
  let p : @types.ProviderConfig = {
    name: "groq",
    api_key: Some("gsk_test"),
    base_url: Some("https://api.groq.com/openai"),
    default_model: "llama-3.3-70b",
    timeout_ms: 30000,
    max_retries: 3,
    use_responses_api: false,
  }
  match validate_provider_config(p) {
    Some(msg) => fail("unexpected error: \{msg}")
    None => ()
  }
}

///|
test "validate_provider_config rejects anthropic without api_key" {
  let p = @types.ProviderConfig::new(
    name="anthropic",
    api_key=None,
    default_model="claude-sonnet-4-20250514",
  )
  match validate_provider_config(p) {
    Some(msg) => assert_true(msg.contains("api_key is required"))
    None => fail("expected validation error for missing api_key")
  }
}

///|
test "validate_provider_config rejects anthropic with empty api_key" {
  let p = @types.ProviderConfig::new(
    name="anthropic",
    api_key=Some(""),
    default_model="claude-sonnet-4-20250514",
  )
  match validate_provider_config(p) {
    Some(msg) => assert_true(msg.contains("api_key is required"))
    None => fail("expected validation error for empty api_key")
  }
}

///|
test "validate_provider_config rejects anthropic without model" {
  let p = @types.ProviderConfig::new(
    name="anthropic",
    api_key=Some("sk-ant-test"),
    default_model="",
  )
  match validate_provider_config(p) {
    Some(msg) => assert_true(msg.contains("model is required"))
    None => fail("expected validation error for empty model")
  }
}

///|
test "validate_provider_config accepts valid anthropic provider" {
  let p = @types.ProviderConfig::new(
    name="anthropic",
    api_key=Some("sk-ant-test"),
    default_model="claude-sonnet-4-20250514",
  )
  match validate_provider_config(p) {
    Some(msg) => fail("unexpected error: \{msg}")
    None => ()
  }
}

// =============================================================================
// ConfigProviderResolver
// =============================================================================

///|
test "ConfigProviderResolver::resolve returns None when state not initialized" {
  let saved = api_v1_settings_state.config
  api_v1_settings_state.config = None
  let resolver = ConfigProviderResolver::new()
  let result = resolver.resolve()
  api_v1_settings_state.config = saved
  assert_true(result is None)
}

///|
test "ConfigProviderResolver::resolve returns None when providers empty" {
  let saved = api_v1_settings_state.config
  let empty_config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  api_v1_settings_state.config = Some(empty_config)
  let resolver = ConfigProviderResolver::new()
  let result = resolver.resolve()
  api_v1_settings_state.config = saved
  assert_true(result is None)
}

///|
test "ConfigProviderResolver::resolve returns first provider" {
  let saved = api_v1_settings_state.config
  let config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [
      @types.ProviderConfig::new(
        name="groq",
        api_key=Some("gsk_test"),
        default_model="llama-3.3-70b",
      ),
      @types.ProviderConfig::new(
        name="anthropic",
        api_key=Some("sk-ant"),
        default_model="claude-sonnet-4-20250514",
      ),
    ],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  api_v1_settings_state.config = Some(config)
  let resolver = ConfigProviderResolver::new()
  let result = resolver.resolve()
  api_v1_settings_state.config = saved
  match result {
    Some(p) => {
      inspect(p.name, content="groq")
      inspect(p.default_model, content="llama-3.3-70b")
    }
    None => fail("expected Some provider")
  }
}

// =============================================================================
// ModelOrchestrator::call — config 経路の統合テスト
// =============================================================================

///|
async test "ModelOrchestrator::call returns error when config not initialized" {
  let saved = api_v1_settings_state.config
  api_v1_settings_state.config = None
  let resolver = ConfigProviderResolver::new()
  let orchestrator = RuntimeModelOrchestrator::new(resolver)
  let result = @interfaces.ModelOrchestrator::call(
    orchestrator,
    messages=[],
    tools=[],
    options=@types.ModelOptions::default(),
  )
  api_v1_settings_state.config = saved
  match result {
    @types.ModelResponse::ModelError(msg) =>
      assert_true(msg.contains("not initialized"))
    _ => fail("expected ModelError")
  }
}

///|
async test "ModelOrchestrator::call returns error when providers empty" {
  let saved = api_v1_settings_state.config
  let empty_config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  api_v1_settings_state.config = Some(empty_config)
  let resolver = ConfigProviderResolver::new()
  let orchestrator = RuntimeModelOrchestrator::new(resolver)
  let result = @interfaces.ModelOrchestrator::call(
    orchestrator,
    messages=[],
    tools=[],
    options=@types.ModelOptions::default(),
  )
  api_v1_settings_state.config = saved
  match result {
    @types.ModelResponse::ModelError(msg) =>
      assert_true(
        msg.contains("no providers configured") ||
        msg.contains("not initialized"),
      )
    _ => fail("expected ModelError")
  }
}

///|
async test "ModelOrchestrator::call returns error when provider validation fails" {
  let saved = api_v1_settings_state.config
  let config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [
      @types.ProviderConfig::new(
        name="groq",
        api_key=Some("key"),
        default_model="llama",
      ),
    ],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  api_v1_settings_state.config = Some(config)
  let resolver = ConfigProviderResolver::new()
  let orchestrator = RuntimeModelOrchestrator::new(resolver)
  let result = @interfaces.ModelOrchestrator::call(
    orchestrator,
    messages=[],
    tools=[],
    options=@types.ModelOptions::default(),
  )
  api_v1_settings_state.config = saved
  match result {
    @types.ModelResponse::ModelError(msg) =>
      assert_true(msg.contains("base_url is required"))
    _ => fail("expected ModelError for missing base_url")
  }
}

///|
async test "ModelOrchestrator::call uses forced response for test" {
  set_forced_response_for_test(Some("test response"))
  let resolver = ConfigProviderResolver::new()
  let orchestrator = RuntimeModelOrchestrator::new(resolver)
  let result = @interfaces.ModelOrchestrator::call(
    orchestrator,
    messages=[],
    tools=[],
    options=@types.ModelOptions::default(),
  )
  set_forced_response_for_test(None)
  match result {
    @types.ModelResponse::Text(content) =>
      inspect(content, content="test response")
    _ => fail("expected Text response from forced test toggle")
  }
}

///|
async test "ModelOrchestrator::call reflects config updates immediately" {
  let saved = api_v1_settings_state.config
  let empty_config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  api_v1_settings_state.config = Some(empty_config)
  let resolver = ConfigProviderResolver::new()
  let orchestrator = RuntimeModelOrchestrator::new(resolver)
  // 空 providers → エラー
  let result1 = @interfaces.ModelOrchestrator::call(
    orchestrator,
    messages=[],
    tools=[],
    options=@types.ModelOptions::default(),
  )
  match result1 {
    @types.ModelResponse::ModelError(_) => ()
    _ => fail("expected ModelError for empty providers")
  }
  // config を更新 → 同じ orchestrator で validation エラーが変わる
  let updated_config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [
      @types.ProviderConfig::new(
        name="groq",
        api_key=Some("key"),
        default_model="llama",
      ),
    ],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  api_v1_settings_state.config = Some(updated_config)
  let result2 = @interfaces.ModelOrchestrator::call(
    orchestrator,
    messages=[],
    tools=[],
    options=@types.ModelOptions::default(),
  )
  api_v1_settings_state.config = saved
  match result2 {
    @types.ModelResponse::ModelError(msg) =>
      assert_true(msg.contains("base_url is required"))
    _ => fail("expected ModelError for missing base_url")
  }
}

// =============================================================================
// is_openai_compatible_provider
// =============================================================================

///|
test "is_openai_compatible_provider returns false for anthropic" {
  assert_true(not(is_openai_compatible_provider("anthropic")))
}

///|
test "is_openai_compatible_provider returns true for groq" {
  assert_true(is_openai_compatible_provider("groq"))
}

///|
test "is_openai_compatible_provider returns true for openai" {
  assert_true(is_openai_compatible_provider("openai"))
}

///|
test "is_openai_compatible_provider returns true for ollama" {
  assert_true(is_openai_compatible_provider("ollama"))
}

// =============================================================================
// normalize_base_url
// =============================================================================

///|
test "normalize_base_url strips trailing slash" {
  inspect(
    normalize_base_url("https://api.groq.com/openai/"),
    content="https://api.groq.com/openai",
  )
}

///|
test "normalize_base_url trims whitespace" {
  inspect(
    normalize_base_url("  https://api.openai.com  "),
    content="https://api.openai.com",
  )
}

///|
test "normalize_base_url preserves clean url" {
  inspect(
    normalize_base_url("https://api.anthropic.com"),
    content="https://api.anthropic.com",
  )
}

// =============================================================================
// build_agent_loop_options_from_config
// =============================================================================

///|
test "build_agent_loop_options_from_config propagates all config values" {
  let saved = api_v1_settings_state.config
  let config : @types.MukuroConfig = {
    agent: {
      max_iterations: 20,
      model_options: {
        model_name: "",
        temperature: Some(0.7),
        max_tokens: Some(4096),
        stop_sequences: Some(["STOP", "END"]),
      },
      timeout_ms: 60000L,
      bootstrap: "",
    },
    providers: [
      @types.ProviderConfig::new(
        name="groq",
        api_key=Some("key"),
        default_model="llama-3.3-70b",
      ),
    ],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  api_v1_settings_state.config = Some(config)
  let options = build_agent_loop_options_from_config()
  api_v1_settings_state.config = saved
  inspect(options.model_options.model_name, content="llama-3.3-70b")
  inspect(options.max_iterations, content="20")
  inspect(options.model_options.temperature, content="Some(0.7)")
  inspect(options.model_options.max_tokens, content="Some(4096)")
  inspect(options.timeout_ms, content="60000")
  match options.model_options.stop_sequences {
    Some(seqs) => {
      assert_eq(seqs.length(), 2)
      assert_eq(seqs[0], "STOP")
      assert_eq(seqs[1], "END")
    }
    None => fail("expected stop_sequences to be propagated from config")
  }
}

///|
test "build_agent_loop_options_from_config returns defaults when no config" {
  let saved = api_v1_settings_state.config
  api_v1_settings_state.config = None
  let options = build_agent_loop_options_from_config()
  api_v1_settings_state.config = saved
  let defaults = @agent.AgentLoopOptions::default()
  inspect(
    options.model_options.model_name,
    content=defaults.model_options.model_name,
  )
  inspect(options.max_iterations, content=defaults.max_iterations.to_string())
}

///|
test "build_agent_loop_options_from_config uses empty model when no providers" {
  let saved = api_v1_settings_state.config
  let config : @types.MukuroConfig = {
    agent: {
      max_iterations: 5,
      model_options: @types.ModelOptions::default(),
      timeout_ms: 30000L,
      bootstrap: "",
    },
    providers: [],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  api_v1_settings_state.config = Some(config)
  let options = build_agent_loop_options_from_config()
  api_v1_settings_state.config = saved
  inspect(options.model_options.model_name, content="")
  inspect(options.max_iterations, content="5")
  inspect(options.timeout_ms, content="30000")
}
