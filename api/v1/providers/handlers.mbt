///|
/// Message Provider API Handlers
/// HTTP handlers for /api/v1/providers/* endpoints

///|
/// Provider manager state holder
pub(all) struct ProviderManagerState {
  /// Provider states
  mut providers : Map[String, @interfaces.MessageProviderState]
}

///|
/// Create new provider manager state
pub fn ProviderManagerState::new() -> ProviderManagerState {
  { providers: {} }
}

///|
/// Add or update provider state
pub fn ProviderManagerState::set_provider(
  self : ProviderManagerState,
  id : String,
  state : @interfaces.MessageProviderState,
) -> Unit {
  self.providers[id] = state
}

///|
/// Get provider state
pub fn ProviderManagerState::get_provider(
  self : ProviderManagerState,
  id : String,
) -> @interfaces.MessageProviderState? {
  self.providers.get(id)
}

///|
/// Remove provider
pub fn ProviderManagerState::remove_provider(
  self : ProviderManagerState,
  id : String,
) -> Unit {
  ignore(self.providers.remove(id))
}

///|
/// Create provider handlers with state
pub fn create_provider_handlers(
  state : ProviderManagerState,
) -> @api.ProviderApiHandlers {
  {
    list: @api.RouteHandler(fn(ctx) { handle_list(state, ctx) }),
    get: @api.RouteHandler(fn(ctx) { handle_get(state, ctx) }),
    add: @api.RouteHandler(fn(ctx) { handle_add(state, ctx) }),
    update: @api.RouteHandler(fn(ctx) { handle_update(state, ctx) }),
    remove: @api.RouteHandler(fn(ctx) { handle_remove(state, ctx) }),
    enable: @api.RouteHandler(fn(ctx) { handle_enable(state, ctx) }),
    disable: @api.RouteHandler(fn(ctx) { handle_disable(state, ctx) }),
    connect: @api.RouteHandler(fn(ctx) { handle_connect(state, ctx) }),
    disconnect: @api.RouteHandler(fn(ctx) { handle_disconnect(state, ctx) }),
    test_connection: @api.RouteHandler(fn(ctx) { handle_test(state, ctx) }),
    get_types: @api.RouteHandler(fn(_ctx) { handle_get_types() }),
    get_schema: @api.RouteHandler(fn(ctx) { handle_get_schema(ctx) }),
  }
}

///|
/// GET /providers - List all providers
fn handle_list(
  state : ProviderManagerState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let items : Array[Json] = []
  for id, provider_state in state.providers {
    let item : ProviderListItem = {
      id,
      name: provider_state.config.name,
      provider_type: provider_state.config.provider_type.to_string(),
      enabled: provider_state.config.enabled,
      status: provider_state.status.to_string(),
      messages_sent: provider_state.messages_sent,
      messages_received: provider_state.messages_received,
    }
    items.push(item.to_json())
  }
  @api.json_response(200, { "data": Json::array(items) })
}

///|
/// GET /providers/{id} - Get provider details
fn handle_get(
  state : ProviderManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Provider ID is required")
  }
  let provider_id = ctx.segments[1]
  match state.get_provider(provider_id) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Provider '\{provider_id}' not found",
      )
    Some(provider_state) => {
      let caps = provider_state.config.capabilities
      let response : ProviderDetailResponse = {
        id: provider_id,
        name: provider_state.config.name,
        provider_type: provider_state.config.provider_type.to_string(),
        enabled: provider_state.config.enabled,
        auto_connect: provider_state.config.auto_connect,
        status: provider_state.status.to_string(),
        last_connected_at: provider_state.last_connected_at,
        last_error: provider_state.last_error,
        messages_sent: provider_state.messages_sent,
        messages_received: provider_state.messages_received,
        settings: provider_state.config.settings,
        capabilities: {
          can_send: caps.can_send,
          can_receive: caps.can_receive,
          supports_rich_text: caps.supports_rich_text,
          supports_attachments: caps.supports_attachments,
          supports_reactions: caps.supports_reactions,
          supports_threads: caps.supports_threads,
          supports_edit: caps.supports_edit,
          supports_delete: caps.supports_delete,
        },
      }
      @api.json_response(200, { "data": response.to_json() })
    }
  }
}

///|
/// POST /providers - Add new provider
fn handle_add(
  state : ProviderManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) =>
      match ProviderAddRequest::from_json(obj) {
        None =>
          @api.error_response(
            400,
            "bad_request",
            "Invalid request. Required: id, name, provider_type",
          )
        Some(request) => {
          // Check if already exists
          match state.get_provider(request.id) {
            Some(_) =>
              @api.error_response(
                409,
                "conflict",
                "Provider '\{request.id}' already exists",
              )
            None => {
              // Create provider config
              let provider_type = @interfaces.MessageProviderType::from_string(
                request.provider_type,
              )
              let capabilities = match provider_type {
                @interfaces.MessageProviderType::Slack =>
                  @interfaces.ProviderCapabilities::slack()
                @interfaces.MessageProviderType::Discord =>
                  @interfaces.ProviderCapabilities::discord()
                _ => @interfaces.ProviderCapabilities::default()
              }
              let config : @interfaces.MessageProviderConfig = {
                id: request.id,
                name: request.name,
                provider_type,
                enabled: request.enabled.unwrap_or(true),
                auto_connect: request.auto_connect.unwrap_or(true),
                settings: request.settings,
                capabilities,
              }
              let provider_state = @interfaces.MessageProviderState::from_config(
                config,
              )
              state.set_provider(request.id, provider_state)
              @api.json_response(201, { "ok": true, "id": request.id })
            }
          }
        }
      }
  }
}

///|
/// PUT /providers/{id} - Update provider
fn handle_update(
  state : ProviderManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Provider ID is required")
  }
  let provider_id = ctx.segments[1]
  match state.get_provider(provider_id) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Provider '\{provider_id}' not found",
      )
    Some(provider_state) =>
      match @api.require_json_object(ctx.body) {
        Err(resp) => resp
        Ok(obj) => {
          let request = ProviderUpdateRequest::from_json(obj)
          // Update config fields
          let old_config = provider_state.config
          let new_name = request.name.unwrap_or(old_config.name)
          let new_enabled = request.enabled.unwrap_or(old_config.enabled)
          let new_auto_connect = request.auto_connect.unwrap_or(
            old_config.auto_connect,
          )
          let new_settings = match request.settings {
            Some(s) => {
              // Merge settings
              let merged = old_config.settings
              for key, value in s {
                merged[key] = value
              }
              merged
            }
            None => old_config.settings
          }
          let new_config : @interfaces.MessageProviderConfig = {
            id: old_config.id,
            name: new_name,
            provider_type: old_config.provider_type,
            enabled: new_enabled,
            auto_connect: new_auto_connect,
            settings: new_settings,
            capabilities: old_config.capabilities,
          }
          let new_state : @interfaces.MessageProviderState = {
            ..provider_state,
            config: new_config,
          }
          state.set_provider(provider_id, new_state)
          @api.json_response(200, { "ok": true })
        }
      }
  }
}

///|
/// DELETE /providers/{id} - Remove provider
fn handle_remove(
  state : ProviderManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Provider ID is required")
  }
  let provider_id = ctx.segments[1]
  match state.get_provider(provider_id) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Provider '\{provider_id}' not found",
      )
    Some(_) => {
      state.remove_provider(provider_id)
      @api.json_response(200, { "ok": true })
    }
  }
}

///|
/// PUT /providers/{id}/enable - Enable provider
fn handle_enable(
  state : ProviderManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Provider ID is required")
  }
  let provider_id = ctx.segments[1]
  match state.get_provider(provider_id) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Provider '\{provider_id}' not found",
      )
    Some(provider_state) => {
      let new_config : @interfaces.MessageProviderConfig = {
        ..provider_state.config,
        enabled: true,
      }
      let new_state : @interfaces.MessageProviderState = {
        ..provider_state,
        config: new_config,
      }
      state.set_provider(provider_id, new_state)
      @api.json_response(200, { "ok": true })
    }
  }
}

///|
/// PUT /providers/{id}/disable - Disable provider
fn handle_disable(
  state : ProviderManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Provider ID is required")
  }
  let provider_id = ctx.segments[1]
  match state.get_provider(provider_id) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Provider '\{provider_id}' not found",
      )
    Some(provider_state) => {
      let new_config : @interfaces.MessageProviderConfig = {
        ..provider_state.config,
        enabled: false,
      }
      let new_state : @interfaces.MessageProviderState = {
        ..provider_state,
        config: new_config,
        status: @interfaces.ProviderConnectionStatus::Disconnected,
      }
      state.set_provider(provider_id, new_state)
      @api.json_response(200, { "ok": true })
    }
  }
}

///|
/// POST /providers/{id}/connect - Connect provider
fn handle_connect(
  state : ProviderManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Provider ID is required")
  }
  let provider_id = ctx.segments[1]
  match state.get_provider(provider_id) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Provider '\{provider_id}' not found",
      )
    Some(provider_state) => {
      if not(provider_state.config.enabled) {
        return @api.error_response(
          400,
          "bad_request",
          "Provider is disabled. Enable it first.",
        )
      }
      // Update status to connecting
      let new_state : @interfaces.MessageProviderState = {
        ..provider_state,
        status: @interfaces.ProviderConnectionStatus::Connecting,
      }
      state.set_provider(provider_id, new_state)
      // TODO: Actual connection logic would be async
      @api.json_response(200, { "ok": true, "status": "connecting" })
    }
  }
}

///|
/// POST /providers/{id}/disconnect - Disconnect provider
fn handle_disconnect(
  state : ProviderManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Provider ID is required")
  }
  let provider_id = ctx.segments[1]
  match state.get_provider(provider_id) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Provider '\{provider_id}' not found",
      )
    Some(provider_state) => {
      let new_state : @interfaces.MessageProviderState = {
        ..provider_state,
        status: @interfaces.ProviderConnectionStatus::Disconnected,
      }
      state.set_provider(provider_id, new_state)
      @api.json_response(200, { "ok": true })
    }
  }
}

///|
/// POST /providers/{id}/test - Test provider connection
fn handle_test(
  state : ProviderManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Provider ID is required")
  }
  let provider_id = ctx.segments[1]
  match state.get_provider(provider_id) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Provider '\{provider_id}' not found",
      )
    Some(provider_state) => {
      // TODO: Actual test logic would be async
      // For now, just validate required settings are present
      let provider_type = provider_state.config.provider_type
      let schema = @interfaces.ProviderSettingsSchema::for_type(provider_type)
      let settings = provider_state.config.settings
      let missing : Array[String] = []
      for field in schema.fields {
        if field.required {
          match settings.get(field.key) {
            None => missing.push(field.key)
            Some(String(s)) => if s.length() == 0 { missing.push(field.key) }
            _ => ()
          }
        }
      }
      if missing.length() > 0 {
        let missing_str = missing.join(", ")
        @api.json_response(
          200,
          {
            "ok": false,
            "error": "Missing required settings: \{missing_str}",
            "missing_fields": missing_str,
          },
        )
      } else {
        @api.json_response(200, { "ok": true, "message": "Configuration valid" })
      }
    }
  }
}

///|
/// GET /providers/types - Get available provider types
fn handle_get_types() -> @api.ApiResponse {
  let types = get_provider_types()
  let arr : Array[Json] = []
  for t in types {
    arr.push(t.to_json())
  }
  @api.json_response(200, { "data": Json::array(arr) })
}

///|
/// GET /providers/schema/{type} - Get settings schema for provider type
fn handle_get_schema(ctx : @api.ApiRequestContext) -> @api.ApiResponse {
  if ctx.segments.length() < 3 {
    return @api.error_response(400, "bad_request", "Provider type is required")
  }
  let provider_type_str = ctx.segments[2]
  let provider_type = @interfaces.MessageProviderType::from_string(
    provider_type_str,
  )
  let schema = @interfaces.ProviderSettingsSchema::for_type(provider_type)
  let response = settings_schema_to_response(schema)
  @api.json_response(200, { "data": response.to_json() })
}
