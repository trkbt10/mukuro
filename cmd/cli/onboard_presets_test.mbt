///|
/// オンボーディング プリセット・マージロジック テスト

// =============================================================================
// find_preset
// =============================================================================

///|
test "find_preset returns anthropic preset" {
  let preset = find_preset("anthropic")
  assert_true(preset is Some(_))
  let p = preset.unwrap()
  assert_eq(p.name, "anthropic")
  assert_eq(p.default_model, "claude-sonnet-4-20250514")
  assert_eq(p.env_var, Some("ANTHROPIC_API_KEY"))
  assert_true(p.base_url is None)
}

///|
test "find_preset returns openai preset with base_url" {
  let preset = find_preset("openai")
  assert_true(preset is Some(_))
  let p = preset.unwrap()
  assert_eq(p.name, "openai")
  assert_eq(p.default_model, "gpt-4o")
  assert_eq(p.base_url, Some("https://api.openai.com/v1"))
  assert_eq(p.env_var, Some("OPENAI_API_KEY"))
}

///|
test "find_preset returns ollama preset with no env_var" {
  let preset = find_preset("ollama")
  assert_true(preset is Some(_))
  let p = preset.unwrap()
  assert_eq(p.name, "ollama")
  assert_eq(p.default_model, "llama3.2")
  assert_eq(p.base_url, Some("http://localhost:11434/v1"))
  assert_true(p.env_var is None)
}

///|
test "find_preset is case-insensitive" {
  let preset = find_preset("Anthropic")
  assert_true(preset is Some(_))
  assert_eq(preset.unwrap().name, "anthropic")
}

///|
test "find_preset returns None for unknown provider" {
  let preset = find_preset("unknown-provider")
  assert_true(preset is None)
}

// =============================================================================
// known_provider_presets
// =============================================================================

///|
test "known_provider_presets has 8 providers" {
  let presets = known_provider_presets()
  assert_eq(presets.length(), 8)
}

///|
test "known_provider_presets all have non-empty name and model" {
  for preset in known_provider_presets() {
    assert_true(preset.name.length() > 0)
    assert_true(preset.default_model.length() > 0)
  }
}

// =============================================================================
// merge_provider_into_config
// =============================================================================

///|
test "merge adds provider to empty config" {
  let config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  let provider = @types.ProviderConfig::new(
    name="anthropic",
    api_key=Some("sk-test"),
    default_model="claude-sonnet-4-20250514",
  )
  let merged = merge_provider_into_config(config, provider)
  assert_eq(merged.providers.length(), 1)
  assert_eq(merged.providers[0].name, "anthropic")
  assert_eq(merged.providers[0].api_key, Some("sk-test"))
}

///|
test "merge adds second provider" {
  let config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [
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
  let provider = @types.ProviderConfig::new(
    name="openai",
    api_key=Some("sk-oai"),
    default_model="gpt-4o",
  )
  let merged = merge_provider_into_config(config, provider)
  assert_eq(merged.providers.length(), 2)
  assert_eq(merged.providers[0].name, "anthropic")
  assert_eq(merged.providers[1].name, "openai")
}

///|
test "merge updates existing provider" {
  let config : @types.MukuroConfig = {
    agent: @types.AgentConfig::default(),
    providers: [
      @types.ProviderConfig::new(
        name="anthropic",
        api_key=Some("sk-old"),
        default_model="claude-sonnet-4-20250514",
      ),
      @types.ProviderConfig::new(
        name="openai",
        api_key=Some("sk-oai"),
        default_model="gpt-4o",
      ),
    ],
    fallback: @types.FallbackConfig::new(),
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  let updated_provider = @types.ProviderConfig::new(
    name="anthropic",
    api_key=Some("sk-new"),
    default_model="claude-opus-4-20250514",
  )
  let merged = merge_provider_into_config(config, updated_provider)
  assert_eq(merged.providers.length(), 2)
  assert_eq(merged.providers[0].name, "anthropic")
  assert_eq(merged.providers[0].api_key, Some("sk-new"))
  assert_eq(merged.providers[0].default_model, "claude-opus-4-20250514")
  assert_eq(merged.providers[1].name, "openai")
  assert_eq(merged.providers[1].api_key, Some("sk-oai"))
}

///|
test "merge preserves other config fields" {
  let config : @types.MukuroConfig = {
    agent: { ..@types.AgentConfig::default(), max_iterations: 20 },
    providers: [],
    fallback: { enabled: true, providers: ["openai"], cooldown_ms: 5000 },
    channels: [],
    thinking: @types.ThinkingConfig::default(),
  }
  let provider = @types.ProviderConfig::new(
    name="anthropic",
    api_key=Some("sk-test"),
    default_model="claude-sonnet-4-20250514",
  )
  let merged = merge_provider_into_config(config, provider)
  assert_eq(merged.agent.max_iterations, 20)
  assert_eq(merged.fallback.enabled, true)
  assert_eq(merged.fallback.cooldown_ms, 5000)
}

// =============================================================================
// format_provider_list
// =============================================================================

///|
test "format_provider_list includes all providers" {
  let list = format_provider_list()
  assert_true(list.contains("anthropic"))
  assert_true(list.contains("openai"))
  assert_true(list.contains("gemini"))
  assert_true(list.contains("deepseek"))
  assert_true(list.contains("groq"))
  assert_true(list.contains("openrouter"))
  assert_true(list.contains("ollama"))
  assert_true(list.contains("moonshot"))
}

///|
test "format_provider_list shows env var hints" {
  let list = format_provider_list()
  assert_true(list.contains("ANTHROPIC_API_KEY"))
  assert_true(list.contains("OPENAI_API_KEY"))
  assert_true(list.contains("no key needed"))
}

// =============================================================================
// build_post_onboard_guidance
// =============================================================================

///|
test "guidance with api_key shows agent/gateway commands" {
  let guidance = build_post_onboard_guidance(
    "anthropic", "claude-sonnet-4-20250514", "/test/config.json", true,
  )
  assert_true(guidance.contains("mukuro agent"))
  assert_true(guidance.contains("mukuro gateway"))
  assert_true(guidance.contains("mukuro config providers"))
  assert_false(guidance.contains("Add your API key"))
}

///|
test "guidance without api_key shows setup instructions" {
  let guidance = build_post_onboard_guidance(
    "anthropic", "claude-sonnet-4-20250514", "/test/config.json", false,
  )
  assert_true(guidance.contains("Add your API key"))
  assert_true(guidance.contains("ANTHROPIC_API_KEY"))
  assert_true(guidance.contains("mukuro onboard --provider anthropic"))
}

///|
test "guidance for unknown provider without api_key omits env var hint" {
  let guidance = build_post_onboard_guidance(
    "custom-llm", "my-model", "/test/config.json", false,
  )
  assert_true(guidance.contains("Add your API key"))
  assert_false(guidance.contains("ANTHROPIC_API_KEY"))
}
