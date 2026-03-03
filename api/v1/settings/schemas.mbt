///|
/// Settings API Schemas
/// Request/Response schemas for settings endpoints

///|
/// Retry settings response
/// Delegates to @types.RetryConfig::to_settings_json() for JSON output
pub(all) struct RetrySettingsResponse {
  config : @types.RetryConfig
}

///|
/// Create from RetryConfig
pub fn RetrySettingsResponse::from_config(
  config : @types.RetryConfig,
) -> RetrySettingsResponse {
  { config, }
}

///|
/// Convert to JSON - delegates to source of truth
pub fn RetrySettingsResponse::to_json(self : RetrySettingsResponse) -> Json {
  self.config.to_settings_json()
}

///|
/// Agent settings response
/// Delegates to @types.AgentConfig::to_settings_json() for JSON output
pub(all) struct AgentSettingsResponse {
  config : @types.AgentConfig
}

///|
/// Create from AgentConfig
pub fn AgentSettingsResponse::from_config(
  config : @types.AgentConfig,
) -> AgentSettingsResponse {
  { config, }
}

///|
/// Convert to JSON - delegates to source of truth
pub fn AgentSettingsResponse::to_json(self : AgentSettingsResponse) -> Json {
  self.config.to_settings_json()
}

///|
/// Model settings response
/// Delegates to @types.ModelOptions::to_settings_json() for JSON output
pub(all) struct ModelSettingsResponse {
  config : @types.ModelOptions
}

///|
/// Create from ModelOptions
pub fn ModelSettingsResponse::from_config(
  config : @types.ModelOptions,
) -> ModelSettingsResponse {
  { config, }
}

///|
/// Convert to JSON - delegates to source of truth
pub fn ModelSettingsResponse::to_json(self : ModelSettingsResponse) -> Json {
  self.config.to_settings_json()
}

///|
/// Provider settings response
/// Delegates to @types.ProviderConfig::to_settings_json() for JSON output
pub(all) struct ProviderSettingsResponse {
  config : @types.ProviderConfig
}

///|
/// Create from ProviderConfig
pub fn ProviderSettingsResponse::from_config(
  config : @types.ProviderConfig,
) -> ProviderSettingsResponse {
  { config, }
}

///|
/// Convert to JSON - delegates to source of truth
pub fn ProviderSettingsResponse::to_json(
  self : ProviderSettingsResponse,
) -> Json {
  self.config.to_settings_json()
}

///|
/// All settings response
pub(all) struct AllSettingsResponse {
  retry : RetrySettingsResponse
  agent : AgentSettingsResponse
  model : ModelSettingsResponse
  thinking : ThinkingSettingsResponse
  providers : Array[ProviderSettingsResponse]
}

///|
/// Convert to JSON
pub fn AllSettingsResponse::to_json(self : AllSettingsResponse) -> Json {
  let providers : Array[Json] = []
  for p in self.providers {
    providers.push(p.to_json())
  }
  {
    "retry": self.retry.to_json(),
    "agent": self.agent.to_json(),
    "model": self.model.to_json(),
    "thinking": self.thinking.to_json(),
    "providers": Json::array(providers),
  }
}

///|
/// Model + Inference 統合レスポンス
/// Delegates to @types.to_model_inference_json() for JSON output
pub(all) struct ModelInferenceSettingsResponse {
  model : @types.ModelOptions
  thinking : @types.ThinkingConfig
}

///|
pub fn ModelInferenceSettingsResponse::from_configs(
  model : @types.ModelOptions,
  thinking : @types.ThinkingConfig,
) -> ModelInferenceSettingsResponse {
  { model, thinking }
}

///|
/// Convert to JSON - delegates to source of truth
pub fn ModelInferenceSettingsResponse::to_json(
  self : ModelInferenceSettingsResponse,
) -> Json {
  @types.to_model_inference_json(self.model, self.thinking)
}

///|
/// Thinking settings response (OpenClaw compatible)
/// Delegates to @types.ThinkingConfig::to_settings_json() for JSON output
pub(all) struct ThinkingSettingsResponse {
  config : @types.ThinkingConfig
}

///|
/// Create from ThinkingConfig
pub fn ThinkingSettingsResponse::from_config(
  config : @types.ThinkingConfig,
) -> ThinkingSettingsResponse {
  { config, }
}

///|
/// Convert to JSON - delegates to source of truth
pub fn ThinkingSettingsResponse::to_json(
  self : ThinkingSettingsResponse,
) -> Json {
  self.config.to_settings_json()
}
