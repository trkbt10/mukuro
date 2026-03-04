///|
/// Settings API Handlers
/// HTTP handlers for /api/v1/settings/* endpoints

///|
/// Runtime settings state
pub(all) struct SettingsState {
  mut config : @types.MukuroConfig?
  mut retry_config : @types.RetryConfig
  mut config_path : String
  /// Callback for persisting config changes
  mut persister : ((@types.MukuroConfig, String) -> Unit)?
}

///|
/// Create new settings state
pub fn SettingsState::new() -> SettingsState {
  {
    config: None,
    retry_config: @types.RetryConfig::default(),
    config_path: "",
    persister: None,
  }
}

///|
/// Initialize settings state
pub fn SettingsState::init(
  self : SettingsState,
  config : @types.MukuroConfig,
  path : String,
) -> Unit {
  self.config = Some(config)
  self.config_path = path
}

///|
/// Set config persistence callback
pub fn SettingsState::set_persister(
  self : SettingsState,
  persister : (@types.MukuroConfig, String) -> Unit,
) -> Unit {
  self.persister = Some(persister)
}

///|
/// Persist current config to disk
fn SettingsState::persist(self : SettingsState) -> Unit {
  match (self.config, self.persister) {
    (Some(config), Some(persister)) => persister(config, self.config_path)
    _ => () // No config or persister, skip
  }
}

///|
/// Get current config
pub fn SettingsState::get_config(self : SettingsState) -> @types.MukuroConfig? {
  self.config
}

///|
/// Update config
pub fn SettingsState::update_config(
  self : SettingsState,
  config : @types.MukuroConfig,
) -> Unit {
  self.config = Some(config)
}

///|
/// Create settings handlers with state
pub fn create_settings_handlers(
  state : SettingsState,
) -> @api.SettingsApiHandlers {
  {
    get_all: @api.RouteHandler(fn(ctx) { handle_get_all(state, ctx) }),
    update_all: @api.RouteHandler(fn(ctx) { handle_update_all(state, ctx) }),
    get_retry: @api.RouteHandler(fn(ctx) { handle_get_retry(state, ctx) }),
    update_retry: @api.RouteHandler(fn(ctx) { handle_update_retry(state, ctx) }),
    get_agent: @api.RouteHandler(fn(ctx) { handle_get_agent(state, ctx) }),
    update_agent: @api.RouteHandler(fn(ctx) { handle_update_agent(state, ctx) }),
    get_model_inference: @api.RouteHandler(fn(ctx) {
      handle_get_model_inference(state, ctx)
    }),
    update_model_inference: @api.RouteHandler(fn(ctx) {
      handle_update_model_inference(state, ctx)
    }),
    list_providers: @api.RouteHandler(fn(ctx) {
      handle_list_providers(state, ctx)
    }),
    update_provider: @api.RouteHandler(fn(ctx) {
      handle_update_provider(state, ctx)
    }),
  }
}

///|
/// GET /settings - Get all settings
fn handle_get_all(
  state : SettingsState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match state.config {
    None =>
      @api.error_response(
        503, "service_unavailable", "Configuration not initialized",
      )
    Some(config) => {
      let providers : Array[ProviderSettingsResponse] = []
      for p in config.providers {
        providers.push(ProviderSettingsResponse::from_config(p))
      }
      let response : AllSettingsResponse = {
        retry: RetrySettingsResponse::from_config(state.retry_config),
        agent: AgentSettingsResponse::from_config(config.agent),
        model: ModelSettingsResponse::from_config(config.agent.model_options),
        thinking: ThinkingSettingsResponse::from_config(config.thinking),
        providers,
      }
      @api.json_response(200, { "data": response.to_json() })
    }
  }
}

///|
/// PUT /settings - Update multiple settings
fn handle_update_all(
  state : SettingsState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) =>
      match state.config {
        None =>
          @api.error_response(
            503, "service_unavailable", "Configuration not initialized",
          )
        Some(config) => {
          let mut new_config = config
          // Update agent settings if provided
          match obj.get("agent") {
            Some(Object(agent_obj)) => {
              let mut agent = config.agent
              match agent_obj.get("max_iterations") {
                Some(Number(n, ..)) =>
                  agent = { ..agent, max_iterations: n.to_int() }
                _ => ()
              }
              match agent_obj.get("timeout_ms") {
                Some(Number(n, ..)) =>
                  agent = { ..agent, timeout_ms: n.to_int64() }
                _ => ()
              }
              match agent_obj.get("bootstrap") {
                Some(String(s)) => agent = { ..agent, bootstrap: s }
                _ => ()
              }
              new_config = { ..new_config, agent, }
            }
            _ => ()
          }
          // Update retry settings if provided
          match obj.get("retry") {
            Some(Object(retry_obj)) => {
              let mut retry = state.retry_config
              match retry_obj.get("max_retries") {
                Some(Number(n, ..)) =>
                  retry = { ..retry, max_retries: n.to_int() }
                _ => ()
              }
              match retry_obj.get("initial_backoff_ms") {
                Some(Number(n, ..)) =>
                  retry = { ..retry, initial_backoff_ms: n.to_int() }
                _ => ()
              }
              match retry_obj.get("max_backoff_ms") {
                Some(Number(n, ..)) =>
                  retry = { ..retry, max_backoff_ms: n.to_int() }
                _ => ()
              }
              match retry_obj.get("backoff_multiplier") {
                Some(Number(n, ..)) =>
                  retry = { ..retry, backoff_multiplier: n }
                _ => ()
              }
              state.retry_config = retry
            }
            _ => ()
          }
          state.config = Some(new_config)
          @api.json_response(200, { "ok": true })
        }
      }
  }
}

///|
/// GET /settings/retry - Get retry settings
fn handle_get_retry(
  state : SettingsState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let response = RetrySettingsResponse::from_config(state.retry_config)
  @api.json_response(200, { "data": response.to_json() })
}

///|
/// PUT /settings/retry - Update retry settings
fn handle_update_retry(
  state : SettingsState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) => {
      let mut retry = state.retry_config
      match obj.get("max_retries") {
        Some(Number(n, ..)) => retry = { ..retry, max_retries: n.to_int() }
        _ => ()
      }
      match obj.get("initial_backoff_ms") {
        Some(Number(n, ..)) =>
          retry = { ..retry, initial_backoff_ms: n.to_int() }
        _ => ()
      }
      match obj.get("max_backoff_ms") {
        Some(Number(n, ..)) => retry = { ..retry, max_backoff_ms: n.to_int() }
        _ => ()
      }
      match obj.get("backoff_multiplier") {
        Some(Number(n, ..)) => retry = { ..retry, backoff_multiplier: n }
        _ => ()
      }
      match obj.get("retry_status_codes") {
        Some(Array(arr)) => {
          let codes : Array[Int] = []
          for item in arr {
            match item {
              Number(n, ..) => codes.push(n.to_int())
              _ => ()
            }
          }
          if codes.length() > 0 {
            retry = { ..retry, retry_status_codes: codes }
          }
        }
        _ => ()
      }
      state.retry_config = retry
      @api.json_response(200, {
        "ok": true,
        "data": RetrySettingsResponse::from_config(retry).to_json(),
      })
    }
  }
}

///|
/// GET /settings/agent - Get agent settings
fn handle_get_agent(
  state : SettingsState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match state.config {
    None =>
      @api.error_response(
        503, "service_unavailable", "Configuration not initialized",
      )
    Some(config) => {
      let response = AgentSettingsResponse::from_config(config.agent)
      @api.json_response(200, { "data": response.to_json() })
    }
  }
}

///|
/// PUT /settings/agent - Update agent settings
fn handle_update_agent(
  state : SettingsState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) =>
      match state.config {
        None =>
          @api.error_response(
            503, "service_unavailable", "Configuration not initialized",
          )
        Some(config) => {
          let mut agent = config.agent
          match obj.get("max_iterations") {
            Some(Number(n, ..)) =>
              agent = { ..agent, max_iterations: n.to_int() }
            _ => ()
          }
          match obj.get("timeout_ms") {
            Some(Number(n, ..)) => agent = { ..agent, timeout_ms: n.to_int64() }
            _ => ()
          }
          match obj.get("bootstrap") {
            Some(String(s)) => agent = { ..agent, bootstrap: s }
            _ => ()
          }
          state.config = Some({ ..config, agent, })
          @api.json_response(200, {
            "ok": true,
            "data": AgentSettingsResponse::from_config(agent).to_json(),
          })
        }
      }
  }
}

///|
/// GET /settings/providers - List all providers
fn handle_list_providers(
  state : SettingsState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match state.config {
    None =>
      @api.error_response(
        503, "service_unavailable", "Configuration not initialized",
      )
    Some(config) => {
      let providers : Array[Json] = []
      for p in config.providers {
        providers.push(ProviderSettingsResponse::from_config(p).to_json())
      }
      @api.json_response(200, { "data": Json::array(providers) })
    }
  }
}

///|
/// PUT /settings/providers/{name} - Update provider settings
fn handle_update_provider(
  state : SettingsState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // Get provider name from path segments
  if ctx.segments.length() < 3 {
    return @api.error_response(400, "bad_request", "Provider name is required")
  }
  let provider_name = ctx.segments[2]
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) =>
      match state.config {
        None =>
          @api.error_response(
            503, "service_unavailable", "Configuration not initialized",
          )
        Some(config) => {
          let mut found = false
          let new_providers : Array[@types.ProviderConfig] = []
          for p in config.providers {
            if p.name == provider_name {
              found = true
              let mut updated = p
              match obj.get("base_url") {
                Some(String(s)) => updated = { ..updated, base_url: Some(s) }
                Some(Null) => updated = { ..updated, base_url: None }
                _ => ()
              }
              match obj.get("default_model") {
                Some(String(s)) => updated = { ..updated, default_model: s }
                _ => ()
              }
              match obj.get("timeout_ms") {
                Some(Number(n, ..)) =>
                  updated = { ..updated, timeout_ms: n.to_int() }
                _ => ()
              }
              match obj.get("max_retries") {
                Some(Number(n, ..)) =>
                  updated = { ..updated, max_retries: n.to_int() }
                _ => ()
              }
              match obj.get("api_key") {
                Some(String(s)) => updated = { ..updated, api_key: Some(s) }
                _ => ()
              }
              match obj.get("use_responses_api") {
                Some(True) => updated = { ..updated, use_responses_api: true }
                Some(False) => updated = { ..updated, use_responses_api: false }
                _ => ()
              }
              new_providers.push(updated)
            } else {
              new_providers.push(p)
            }
          }
          if not(found) {
            return @api.error_response(
              404,
              "not_found",
              "Provider '\{provider_name}' not found",
            )
          }
          state.config = Some({ ..config, providers: new_providers })
          state.persist()
          // Return the updated provider
          let updated_provider = new_providers.iter().find_first(fn(p) {
            p.name == provider_name
          })
          match updated_provider {
            Some(p) => @api.json_response(200, { "data": p.to_settings_json() })
            None => @api.json_response(200, { "ok": true })
          }
        }
      }
  }
}

///|
/// GET /settings/model-inference - Get merged model + thinking settings
fn handle_get_model_inference(
  state : SettingsState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match state.config {
    None =>
      @api.error_response(
        503, "service_unavailable", "Configuration not initialized",
      )
    Some(config) => {
      let response = ModelInferenceSettingsResponse::from_configs(
        config.agent.model_options,
        config.thinking,
      )
      @api.json_response(200, { "data": response.to_json() })
    }
  }
}

///|
/// PUT /settings/model-inference - Update merged model + thinking settings
fn handle_update_model_inference(
  state : SettingsState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) =>
      match state.config {
        None =>
          @api.error_response(
            503, "service_unavailable", "Configuration not initialized",
          )
        Some(config) => {
          // Update model options
          let mut model = config.agent.model_options
          match obj.get("model_name") {
            Some(String(s)) => model = { ..model, model_name: s }
            _ => ()
          }
          match obj.get("temperature") {
            Some(Number(n, ..)) => model = { ..model, temperature: Some(n) }
            Some(Null) => model = { ..model, temperature: None }
            _ => ()
          }
          match obj.get("max_tokens") {
            Some(Number(n, ..)) =>
              model = { ..model, max_tokens: Some(n.to_int()) }
            Some(Null) => model = { ..model, max_tokens: None }
            _ => ()
          }
          match obj.get("stop_sequences") {
            Some(Array(arr)) => {
              let seqs : Array[String] = []
              for item in arr {
                match item {
                  String(s) => seqs.push(s)
                  _ => ()
                }
              }
              model = {
                ..model,
                stop_sequences: if seqs.length() > 0 {
                  Some(seqs)
                } else {
                  None
                },
              }
            }
            Some(Null) => model = { ..model, stop_sequences: None }
            _ => ()
          }
          // Update thinking config
          let mut thinking = config.thinking
          match obj.get("thinking_enabled") {
            Some(True) => thinking = { ..thinking, enabled: true }
            Some(False) => thinking = { ..thinking, enabled: false }
            _ => ()
          }
          match obj.get("thinking_level") {
            Some(String(s)) =>
              thinking = {
                ..thinking,
                level: @types.ThinkingLevel::from_string(s),
              }
            _ => ()
          }
          match obj.get("thinking_budget_tokens") {
            Some(Number(n, ..)) =>
              thinking = { ..thinking, budget_tokens: Some(n.to_int()) }
            Some(Null) => thinking = { ..thinking, budget_tokens: None }
            _ => ()
          }
          // Persist both
          let new_agent = { ..config.agent, model_options: model }
          state.config = Some({ ..config, agent: new_agent, thinking })
          state.persist()
          let response = ModelInferenceSettingsResponse::from_configs(
            model, thinking,
          )
          @api.json_response(200, { "ok": true, "data": response.to_json() })
        }
      }
  }
}
