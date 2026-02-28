///|
/// Settings API Schemas
/// Request/Response schemas for settings endpoints

///|
/// Retry settings response
pub(all) struct RetrySettingsResponse {
  max_retries : Int
  initial_backoff_ms : Int
  max_backoff_ms : Int
  backoff_multiplier : Double
  retry_status_codes : Array[Int]
}

///|
/// Create from RetryConfig
pub fn RetrySettingsResponse::from_config(config : @types.RetryConfig) -> RetrySettingsResponse {
  {
    max_retries: config.max_retries,
    initial_backoff_ms: config.initial_backoff_ms,
    max_backoff_ms: config.max_backoff_ms,
    backoff_multiplier: config.backoff_multiplier,
    retry_status_codes: config.retry_status_codes,
  }
}

///|
/// Convert to JSON
pub fn RetrySettingsResponse::to_json(self : RetrySettingsResponse) -> Json {
  let status_codes : Array[Json] = []
  for code in self.retry_status_codes {
    status_codes.push(Json::number(code.to_double()))
  }
  {
    "max_retries": self.max_retries,
    "initial_backoff_ms": self.initial_backoff_ms,
    "max_backoff_ms": self.max_backoff_ms,
    "backoff_multiplier": self.backoff_multiplier,
    "retry_status_codes": Json::array(status_codes),
  }
}

///|
/// Agent settings response
pub(all) struct AgentSettingsResponse {
  max_iterations : Int
  timeout_ms : Int64
  bootstrap : String
}

///|
/// Create from AgentConfig
pub fn AgentSettingsResponse::from_config(config : @types.AgentConfig) -> AgentSettingsResponse {
  {
    max_iterations: config.max_iterations,
    timeout_ms: config.timeout_ms,
    bootstrap: config.bootstrap,
  }
}

///|
/// Convert to JSON
pub fn AgentSettingsResponse::to_json(self : AgentSettingsResponse) -> Json {
  {
    "max_iterations": self.max_iterations,
    "timeout_ms": self.timeout_ms.to_double(),
    "bootstrap": self.bootstrap,
  }
}

///|
/// Model settings response
pub(all) struct ModelSettingsResponse {
  model_name : String
  temperature : Double?
  max_tokens : Int?
  stop_sequences : Array[String]?
}

///|
/// Create from ModelOptions
pub fn ModelSettingsResponse::from_config(config : @types.ModelOptions) -> ModelSettingsResponse {
  {
    model_name: config.model_name,
    temperature: config.temperature,
    max_tokens: config.max_tokens,
    stop_sequences: config.stop_sequences,
  }
}

///|
/// Convert to JSON
pub fn ModelSettingsResponse::to_json(self : ModelSettingsResponse) -> Json {
  let obj : Map[String, Json] = {}
  obj["model_name"] = Json::string(self.model_name)
  match self.temperature {
    Some(t) => obj["temperature"] = Json::number(t)
    None => obj["temperature"] = Json::null()
  }
  match self.max_tokens {
    Some(m) => obj["max_tokens"] = Json::number(m.to_double())
    None => obj["max_tokens"] = Json::null()
  }
  match self.stop_sequences {
    Some(seqs) => {
      let arr : Array[Json] = []
      for s in seqs {
        arr.push(Json::string(s))
      }
      obj["stop_sequences"] = Json::array(arr)
    }
    None => obj["stop_sequences"] = Json::null()
  }
  Json::object(obj)
}

///|
/// Provider settings response
pub(all) struct ProviderSettingsResponse {
  name : String
  base_url : String?
  default_model : String
  timeout_ms : Int
  max_retries : Int
  has_api_key : Bool
}

///|
/// Create from ProviderConfig
pub fn ProviderSettingsResponse::from_config(config : @types.ProviderConfig) -> ProviderSettingsResponse {
  let has_key = match config.api_key {
    Some(_) => true
    None => false
  }
  {
    name: config.name,
    base_url: config.base_url,
    default_model: config.default_model,
    timeout_ms: config.timeout_ms,
    max_retries: config.max_retries,
    has_api_key: has_key,
  }
}

///|
/// Convert to JSON
pub fn ProviderSettingsResponse::to_json(self : ProviderSettingsResponse) -> Json {
  let obj : Map[String, Json] = {}
  obj["name"] = Json::string(self.name)
  match self.base_url {
    Some(url) => obj["base_url"] = Json::string(url)
    None => obj["base_url"] = Json::null()
  }
  obj["default_model"] = Json::string(self.default_model)
  obj["timeout_ms"] = Json::number(self.timeout_ms.to_double())
  obj["max_retries"] = Json::number(self.max_retries.to_double())
  obj["has_api_key"] = Json::boolean(self.has_api_key)
  Json::object(obj)
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
/// Thinking settings response (OpenClaw compatible)
pub(all) struct ThinkingSettingsResponse {
  enabled : Bool
  level : String
  budget_tokens : Int?
}

///|
/// Create from ThinkingConfig
pub fn ThinkingSettingsResponse::from_config(config : @types.ThinkingConfig) -> ThinkingSettingsResponse {
  {
    enabled: config.enabled,
    level: config.level.to_string(),
    budget_tokens: config.budget_tokens,
  }
}

///|
/// Convert to JSON
pub fn ThinkingSettingsResponse::to_json(self : ThinkingSettingsResponse) -> Json {
  let obj : Map[String, Json] = {}
  obj["enabled"] = Json::boolean(self.enabled)
  obj["level"] = Json::string(self.level)
  match self.budget_tokens {
    Some(b) => obj["budget_tokens"] = Json::number(b.to_double())
    None => obj["budget_tokens"] = Json::null()
  }
  Json::object(obj)
}

