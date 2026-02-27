///|
/// Prompt API Handlers
/// HTTP handlers for /api/v1/prompts/* endpoints

///|
/// Prompt state holder
pub(all) struct PromptState {
  /// System prompt config
  mut system_prompt : @types.SystemPromptConfig
  /// Bootstrap prompt (from agent config)
  mut bootstrap : String
  /// Channel-specific prompts
  mut channel_prompts : Map[String, String]
  /// Channel prompt enabled flags
  mut channel_enabled : Map[String, Bool]
}

///|
/// Create new prompt state
pub fn PromptState::new() -> PromptState {
  {
    system_prompt: @types.SystemPromptConfig::default(),
    bootstrap: "",
    channel_prompts: {},
    channel_enabled: {},
  }
}

///|
/// Initialize from config
pub fn PromptState::from_config(
  self : PromptState,
  config : @types.MukuroConfig,
) -> Unit {
  self.bootstrap = config.agent.bootstrap
}

///|
/// Create prompt handlers with state
pub fn create_prompt_handlers(state : PromptState) -> @api.PromptApiHandlers {
  {
    get_system: @api.RouteHandler(fn(ctx) { handle_get_system(state, ctx) }),
    update_system: @api.RouteHandler(fn(ctx) { handle_update_system(state, ctx) }),
    get_bootstrap: @api.RouteHandler(fn(ctx) { handle_get_bootstrap(state, ctx) }),
    update_bootstrap: @api.RouteHandler(fn(ctx) { handle_update_bootstrap(state, ctx) }),
    append_bootstrap: @api.RouteHandler(fn(ctx) { handle_append_bootstrap(state, ctx) }),
    get_channel: @api.RouteHandler(fn(ctx) { handle_get_channel(state, ctx) }),
    update_channel: @api.RouteHandler(fn(ctx) { handle_update_channel(state, ctx) }),
    create_channel: @api.RouteHandler(fn(ctx) { handle_create_channel(state, ctx) }),
    delete_channel: @api.RouteHandler(fn(ctx) { handle_delete_channel(state, ctx) }),
  }
}

///|
/// GET /prompts/system - Get system prompt
fn handle_get_system(
  state : PromptState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let response : SystemPromptResponse = {
    content: state.system_prompt.content,
    mode: state.system_prompt.mode.to_string(),
    when: state.system_prompt.when.to_string(),
  }
  @api.json_response(200, { "data": response.to_json() })
}

///|
/// PUT /prompts/system - Update system prompt
fn handle_update_system(
  state : PromptState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) => {
      let mut config = state.system_prompt
      match obj.get("content") {
        Some(String(s)) => config = { ..config, content: s }
        _ => ()
      }
      match obj.get("mode") {
        Some(String(s)) =>
          match s.to_lower() {
            "append" => config = { ..config, mode: @types.SystemPromptMode::Append }
            "replace" =>
              config = { ..config, mode: @types.SystemPromptMode::Replace }
            _ => ()
          }
        _ => ()
      }
      match obj.get("when") {
        Some(String(s)) =>
          match s.to_lower() {
            "first" => config = { ..config, when: @types.SystemPromptWhen::First }
            "always" =>
              config = { ..config, when: @types.SystemPromptWhen::Always }
            "never" => config = { ..config, when: @types.SystemPromptWhen::Never }
            _ => ()
          }
        _ => ()
      }
      state.system_prompt = config
      let response : SystemPromptResponse = {
        content: config.content,
        mode: config.mode.to_string(),
        when: config.when.to_string(),
      }
      @api.json_response(200, { "ok": true, "data": response.to_json() })
    }
  }
}

///|
/// GET /prompts/bootstrap - Get bootstrap prompt
fn handle_get_bootstrap(
  state : PromptState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let response : BootstrapPromptResponse = { content: state.bootstrap }
  @api.json_response(200, { "data": response.to_json() })
}

///|
/// PUT /prompts/bootstrap - Update bootstrap prompt
fn handle_update_bootstrap(
  state : PromptState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) =>
      match obj.get("content") {
        Some(String(content)) => {
          state.bootstrap = content
          let response : BootstrapPromptResponse = { content, }
          @api.json_response(200, { "ok": true, "data": response.to_json() })
        }
        _ =>
          @api.error_response(
            400,
            "bad_request",
            "Field 'content' is required and must be a string",
          )
      }
  }
}

///|
/// POST /prompts/bootstrap/append - Append to bootstrap prompt
fn handle_append_bootstrap(
  state : PromptState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) =>
      match obj.get("content") {
        Some(String(content)) => {
          // Append with newline if bootstrap is not empty
          if state.bootstrap.length() > 0 {
            state.bootstrap = state.bootstrap + "\n" + content
          } else {
            state.bootstrap = content
          }
          let response : BootstrapPromptResponse = { content: state.bootstrap }
          @api.json_response(200, { "ok": true, "data": response.to_json() })
        }
        _ =>
          @api.error_response(
            400,
            "bad_request",
            "Field 'content' is required and must be a string",
          )
      }
  }
}

///|
/// GET /prompts/channels/{name} - Get channel prompt
fn handle_get_channel(
  state : PromptState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 3 {
    return @api.error_response(400, "bad_request", "Channel name is required")
  }
  let channel_name = ctx.segments[2]
  let content = state.channel_prompts.get(channel_name).unwrap_or("")
  let enabled = state.channel_enabled.get(channel_name).unwrap_or(true)
  let response : ChannelPromptResponse = { channel: channel_name, content, enabled }
  @api.json_response(200, { "data": response.to_json() })
}

///|
/// PUT /prompts/channels/{name} - Update channel prompt
fn handle_update_channel(
  state : PromptState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 3 {
    return @api.error_response(400, "bad_request", "Channel name is required")
  }
  let channel_name = ctx.segments[2]
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) => {
      match obj.get("content") {
        Some(String(content)) => state.channel_prompts[channel_name] = content
        _ => ()
      }
      match obj.get("enabled") {
        Some(True) => state.channel_enabled[channel_name] = true
        Some(False) => state.channel_enabled[channel_name] = false
        _ => ()
      }
      let content = state.channel_prompts.get(channel_name).unwrap_or("")
      let enabled = state.channel_enabled.get(channel_name).unwrap_or(true)
      let response : ChannelPromptResponse = { channel: channel_name, content, enabled }
      @api.json_response(200, { "ok": true, "data": response.to_json() })
    }
  }
}

///|
/// POST /prompts/channels - Create channel prompt
fn handle_create_channel(
  state : PromptState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) =>
      match obj.get("channel") {
        Some(String(channel_name)) => {
          // Check if channel already exists
          if state.channel_prompts.contains(channel_name) {
            return @api.error_response(
              409,
              "conflict",
              "Channel '\{channel_name}' already exists",
            )
          }
          // Get content (default to empty string)
          let content = match obj.get("content") {
            Some(String(s)) => s
            _ => ""
          }
          // Get enabled (default to true)
          let enabled = match obj.get("enabled") {
            Some(False) => false
            _ => true
          }
          state.channel_prompts[channel_name] = content
          state.channel_enabled[channel_name] = enabled
          let response : ChannelPromptResponse = { channel: channel_name, content, enabled }
          @api.json_response(201, { "ok": true, "data": response.to_json() })
        }
        _ =>
          @api.error_response(
            400,
            "bad_request",
            "Field 'channel' is required and must be a string",
          )
      }
  }
}

///|
/// DELETE /prompts/channels/{name} - Delete channel prompt
fn handle_delete_channel(
  state : PromptState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 3 {
    return @api.error_response(400, "bad_request", "Channel name is required")
  }
  let channel_name = ctx.segments[2]
  // Check if channel exists
  if not(state.channel_prompts.contains(channel_name)) {
    return @api.error_response(
      404,
      "not_found",
      "Channel '\{channel_name}' not found",
    )
  }
  // Remove channel
  state.channel_prompts.remove(channel_name)
  state.channel_enabled.remove(channel_name)
  @api.json_response(200, { "ok": true })
}
