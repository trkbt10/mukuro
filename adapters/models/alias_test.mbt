///|
test "ModelAliasRegistry::with_defaults creates default aliases" {
  let registry = ModelAliasRegistry::with_defaults()
  let aliases = registry.list_aliases()
  // Should have default aliases for claude, gpt, etc.
  inspect(aliases.length() > 5, content="true")
}

///|
test "ModelAliasRegistry::resolve finds registered alias" {
  let registry = ModelAliasRegistry::with_defaults()
  match registry.resolve("claude") {
    Some(resolved) => {
      inspect(resolved.provider, content="anthropic")
      inspect(resolved.model_name.contains("claude"), content="true")
    }
    None => fail("Expected claude alias to exist")
  }
}

///|
test "ModelAliasRegistry::resolve returns None for unknown alias" {
  let registry = ModelAliasRegistry::new()
  match registry.resolve("unknown-model") {
    Some(_) => fail("Expected None for unknown alias")
    None => ()
  }
}

///|
test "ModelAliasRegistry::get_provider returns correct provider" {
  let registry = ModelAliasRegistry::with_defaults()
  inspect(registry.get_provider("claude"), content="anthropic")
  inspect(registry.get_provider("gpt4"), content="openai")
}

///|
test "ModelAliasRegistry::get_provider infers provider for unknown model" {
  let registry = ModelAliasRegistry::new()
  // Infers from model name
  inspect(registry.get_provider("claude-3-opus"), content="anthropic")
  inspect(registry.get_provider("gpt-4-turbo"), content="openai")
}

///|
test "ModelAliasRegistry::register adds new alias" {
  let registry = ModelAliasRegistry::new()
  registry.register({
    alias: "my-model",
    provider: "custom",
    model_name: "custom-model-v1",
  })
  match registry.resolve("my-model") {
    Some(resolved) => {
      inspect(resolved.provider, content="custom")
      inspect(resolved.model_name, content="custom-model-v1")
    }
    None => fail("Expected registered alias")
  }
}

///|
test "ModelAliasRegistry::unregister removes alias" {
  let registry = ModelAliasRegistry::with_defaults()
  let existed = registry.unregister("claude")
  inspect(existed, content="true")
  match registry.resolve("claude") {
    Some(_) => fail("Expected alias to be removed")
    None => ()
  }
}

///|
test "ModelAliasRegistry::get_model_name resolves alias" {
  let registry = ModelAliasRegistry::with_defaults()
  let model_name = registry.get_model_name("claude")
  // Should resolve to actual model name
  inspect(model_name.contains("claude"), content="true")
}

///|
test "ModelAliasRegistry::get_model_name returns input for unknown" {
  let registry = ModelAliasRegistry::new()
  // Returns input unchanged if not an alias
  inspect(
    registry.get_model_name("some-unknown-model"),
    content="some-unknown-model",
  )
}
