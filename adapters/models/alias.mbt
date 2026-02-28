///|
/// Model Alias Resolver
/// Resolves model aliases to actual provider and model names

///|
/// Model alias registry
pub struct ModelAliasRegistry {
  aliases : Map[String, @types.ModelAlias]
}

///|
/// Create new empty registry
pub fn ModelAliasRegistry::new() -> ModelAliasRegistry {
  { aliases: {} }
}

///|
/// Create registry with default aliases
pub fn ModelAliasRegistry::with_defaults() -> ModelAliasRegistry {
  let registry = ModelAliasRegistry::new()
  // Anthropic Claude aliases
  registry.register({
    alias: "claude",
    provider: "anthropic",
    model_name: "claude-sonnet-4-20250514",
  })
  registry.register({
    alias: "claude-sonnet",
    provider: "anthropic",
    model_name: "claude-sonnet-4-20250514",
  })
  registry.register({
    alias: "claude-opus",
    provider: "anthropic",
    model_name: "claude-opus-4-20250514",
  })
  registry.register({
    alias: "claude-haiku",
    provider: "anthropic",
    model_name: "claude-3-5-haiku-20241022",
  })
  // OpenAI aliases
  registry.register({
    alias: "gpt4",
    provider: "openai",
    model_name: "gpt-4-turbo-preview",
  })
  registry.register({ alias: "gpt4o", provider: "openai", model_name: "gpt-4o" })
  registry.register({
    alias: "gpt35",
    provider: "openai",
    model_name: "gpt-3.5-turbo",
  })
  // Ollama aliases
  registry.register({ alias: "llama", provider: "ollama", model_name: "llama2" })
  registry.register({
    alias: "mistral",
    provider: "ollama",
    model_name: "mistral",
  })
  registry
}

///|
/// Register an alias
pub fn ModelAliasRegistry::register(
  self : ModelAliasRegistry,
  model_alias : @types.ModelAlias,
) -> Unit {
  self.aliases[model_alias.alias_name] = model_alias
}

///|
/// Unregister an alias
pub fn ModelAliasRegistry::unregister(
  self : ModelAliasRegistry,
  alias_name : String,
) -> Bool {
  match self.aliases.get(alias_name) {
    Some(_) => {
      self.aliases.remove(alias_name)
      true
    }
    None => false
  }
}

///|
/// Resolve an alias to provider and model
pub fn ModelAliasRegistry::resolve(
  self : ModelAliasRegistry,
  alias_or_model : String,
) -> @types.ModelAlias? {
  self.aliases.get(alias_or_model)
}

///|
/// Get provider name for alias or model
/// Returns the provider name if alias exists, otherwise attempts to infer from model name
pub fn ModelAliasRegistry::get_provider(
  self : ModelAliasRegistry,
  alias_or_model : String,
) -> String {
  match self.aliases.get(alias_or_model) {
    Some(model_alias) => model_alias.provider
    None => infer_provider_from_model(alias_or_model)
  }
}

///|
/// Get actual model name for alias
/// Returns the resolved model name if alias exists, otherwise returns the input
pub fn ModelAliasRegistry::get_model_name(
  self : ModelAliasRegistry,
  alias_or_model : String,
) -> String {
  match self.aliases.get(alias_or_model) {
    Some(model_alias) => model_alias.model_name
    None => alias_or_model
  }
}

///|
/// List all registered aliases
pub fn ModelAliasRegistry::list_aliases(
  self : ModelAliasRegistry,
) -> Array[String] {
  let result : Array[String] = []
  for alias, _ in self.aliases {
    result.push(alias)
  }
  result
}

///|
/// Infer provider from model name
fn infer_provider_from_model(model_name : String) -> String {
  let lower = model_name.to_lower()
  if lower.contains("claude") {
    "anthropic"
  } else if lower.contains("gpt") ||
    lower.contains("o1") ||
    lower.contains("davinci") {
    "openai"
  } else if lower.contains("llama") ||
    lower.contains("mistral") ||
    lower.contains("codellama") {
    "ollama"
  } else {
    // Default to anthropic
    "anthropic"
  }
}
