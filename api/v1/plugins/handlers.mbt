///|
/// Plugin API Handlers
/// HTTP handlers for /api/v1/plugins/* endpoints

///|
/// Plugin manager state holder
pub(all) struct PluginManagerState {
  /// Plugin states
  mut plugins : Map[String, @interfaces.PluginState]
  /// Plugin settings
  mut settings : Map[String, Map[String, Json]]
}

///|
/// Create new plugin manager state
pub fn PluginManagerState::new() -> PluginManagerState {
  { plugins: {}, settings: {} }
}

///|
/// Initialize with builtin tools
pub fn PluginManagerState::init_builtins(self : PluginManagerState) -> Unit {
  // datetime tool
  self.plugins["datetime"] = @interfaces.PluginState::builtin(
    id="datetime",
    description="Get current date and time in various formats",
  )
  // memory tool
  self.plugins["memory"] = @interfaces.PluginState::builtin(
    id="memory",
    description="Store and retrieve information across conversation turns",
  )
  // message tool
  self.plugins["message"] = @interfaces.PluginState::builtin(
    id="message",
    description="Send messages to users or other systems",
  )
  // spawn tool
  self.plugins["spawn"] = @interfaces.PluginState::builtin(
    id="spawn",
    description="Spawn sub-agents for parallel task execution",
  )
}

///|
/// Add or update plugin state
pub fn PluginManagerState::set_plugin(
  self : PluginManagerState,
  id : String,
  state : @interfaces.PluginState,
) -> Unit {
  self.plugins[id] = state
}

///|
/// Get plugin state
pub fn PluginManagerState::get_plugin(
  self : PluginManagerState,
  id : String,
) -> @interfaces.PluginState? {
  self.plugins.get(id)
}

///|
/// Remove plugin
pub fn PluginManagerState::remove_plugin(
  self : PluginManagerState,
  id : String,
) -> Unit {
  ignore(self.plugins.remove(id))
  ignore(self.settings.remove(id))
}

///|
/// Get plugin settings
pub fn PluginManagerState::get_settings(
  self : PluginManagerState,
  id : String,
) -> Map[String, Json]? {
  self.settings.get(id)
}

///|
/// Set plugin settings
pub fn PluginManagerState::set_settings(
  self : PluginManagerState,
  id : String,
  settings : Map[String, Json],
) -> Unit {
  self.settings[id] = settings
}

///|
/// Create plugin handlers with state
pub fn create_plugin_handlers(
  state : PluginManagerState,
) -> @api.PluginApiHandlers {
  {
    list: @api.RouteHandler(fn(ctx) { handle_list(state, ctx) }),
    get: @api.RouteHandler(fn(ctx) { handle_get(state, ctx) }),
    add: @api.RouteHandler(fn(ctx) { handle_add(state, ctx) }),
    remove: @api.RouteHandler(fn(ctx) { handle_remove(state, ctx) }),
    enable: @api.RouteHandler(fn(ctx) { handle_enable(state, ctx) }),
    disable: @api.RouteHandler(fn(ctx) { handle_disable(state, ctx) }),
    reload: @api.RouteHandler(fn(ctx) { handle_reload(state, ctx) }),
    upload: @api.RouteHandler(fn(ctx) { handle_upload(state, ctx) }),
    get_settings: @api.RouteHandler(fn(ctx) { handle_get_settings(state, ctx) }),
    update_settings: @api.RouteHandler(fn(ctx) { handle_update_settings(state, ctx) }),
  }
}

///|
/// GET /plugins - List all plugins
fn handle_list(
  state : PluginManagerState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let items : Array[Json] = []
  for id, plugin_state in state.plugins {
    let item : PluginListItem = {
      id,
      name: id,
      version: if plugin_state.is_builtin { "builtin" } else { "1.0.0" },
      description: plugin_state.description,
      enabled: plugin_state.enabled,
      status: plugin_state.status.to_string(),
      loaded_at: plugin_state.loaded_at,
      is_builtin: plugin_state.is_builtin,
    }
    items.push(item.to_json())
  }
  @api.json_response(200, { "data": Json::array(items) })
}

///|
/// GET /plugins/{id} - Get plugin details
fn handle_get(
  state : PluginManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Plugin ID is required")
  }
  let plugin_id = ctx.segments[1]
  match state.get_plugin(plugin_id) {
    None =>
      @api.error_response(404, "not_found", "Plugin '\{plugin_id}' not found")
    Some(plugin_state) => {
      let response : PluginDetailResponse = {
        id: plugin_id,
        name: plugin_id,
        version: if plugin_state.is_builtin { "builtin" } else { "1.0.0" },
        description: plugin_state.description,
        author: None,
        enabled: plugin_state.enabled,
        status: plugin_state.status.to_string(),
        loaded_at: plugin_state.loaded_at,
        modified_at: plugin_state.modified_at,
        permissions: [],
        settings_schema: None,
        is_builtin: plugin_state.is_builtin,
      }
      @api.json_response(200, { "data": response.to_json() })
    }
  }
}

///|
/// POST /plugins - Add plugin from manifest
fn handle_add(
  state : PluginManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  match @api.require_json_object(ctx.body) {
    Err(resp) => resp
    Ok(obj) =>
      match PluginAddRequest::from_json(obj) {
        None =>
          @api.error_response(
            400,
            "bad_request",
            "Invalid plugin add request. Required: manifest_path",
          )
        Some(request) => {
          // Generate plugin ID from manifest path
          let plugin_id = generate_plugin_id(request.manifest_path)
          // Check if already exists
          match state.get_plugin(plugin_id) {
            Some(_) =>
              @api.error_response(
                409,
                "conflict",
                "Plugin '\{plugin_id}' already exists",
              )
            None => {
              // Create new plugin state
              let new_state : @interfaces.PluginState = {
                id: plugin_id,
                enabled: request.enabled.unwrap_or(true),
                auto_start: request.auto_start.unwrap_or(true),
                status: @interfaces.PluginStatus::Stopped,
                loaded_at: 0L,
                modified_at: 0L,
                is_builtin: false,
                description: "",
              }
              state.set_plugin(plugin_id, new_state)
              @api.json_response(201, { "ok": true, "id": plugin_id })
            }
          }
        }
      }
  }
}

///|
/// Generate plugin ID from manifest path
fn generate_plugin_id(path : String) -> String {
  // Extract filename without extension
  let chars = path.to_array()
  let mut last_slash = -1
  let mut last_dot = chars.length()
  for i, c in chars {
    if c == '/' || c == '\\' {
      last_slash = i
    }
    if c == '.' {
      last_dot = i
    }
  }
  let start = last_slash + 1
  let end = if last_dot > start { last_dot } else { chars.length() }
  let mut result = ""
  for i in start..<end {
    result = result + chars[i].to_string()
  }
  if result.length() == 0 {
    "plugin-\{path.length()}"
  } else {
    result
  }
}

///|
/// DELETE /plugins/{id} - Remove plugin
fn handle_remove(
  state : PluginManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Plugin ID is required")
  }
  let plugin_id = ctx.segments[1]
  match state.get_plugin(plugin_id) {
    None =>
      @api.error_response(404, "not_found", "Plugin '\{plugin_id}' not found")
    Some(plugin_state) =>
      if plugin_state.is_builtin {
        @api.error_response(
          403,
          "forbidden",
          "Cannot remove builtin plugin '\{plugin_id}'",
        )
      } else {
        state.remove_plugin(plugin_id)
        @api.json_response(200, { "ok": true })
      }
  }
}

///|
/// PUT /plugins/{id}/enable - Enable plugin
fn handle_enable(
  state : PluginManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Plugin ID is required")
  }
  let plugin_id = ctx.segments[1]
  match state.get_plugin(plugin_id) {
    None =>
      @api.error_response(404, "not_found", "Plugin '\{plugin_id}' not found")
    Some(plugin_state) => {
      let updated = { ..plugin_state, enabled: true }
      state.set_plugin(plugin_id, updated)
      @api.json_response(200, { "ok": true })
    }
  }
}

///|
/// PUT /plugins/{id}/disable - Disable plugin
fn handle_disable(
  state : PluginManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Plugin ID is required")
  }
  let plugin_id = ctx.segments[1]
  match state.get_plugin(plugin_id) {
    None =>
      @api.error_response(404, "not_found", "Plugin '\{plugin_id}' not found")
    Some(plugin_state) => {
      let updated = { ..plugin_state, enabled: false }
      state.set_plugin(plugin_id, updated)
      @api.json_response(200, { "ok": true })
    }
  }
}

///|
/// POST /plugins/{id}/reload - Reload plugin
fn handle_reload(
  state : PluginManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Plugin ID is required")
  }
  let plugin_id = ctx.segments[1]
  match state.get_plugin(plugin_id) {
    None =>
      @api.error_response(404, "not_found", "Plugin '\{plugin_id}' not found")
    Some(plugin_state) => {
      // Update modified_at to simulate reload
      let updated = { ..plugin_state, modified_at: plugin_state.modified_at + 1L }
      state.set_plugin(plugin_id, updated)
      @api.json_response(200, { "ok": true, "reloaded": true })
    }
  }
}

///|
/// POST /plugins/upload - Upload plugin ZIP
fn handle_upload(
  _state : PluginManagerState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // ZIP upload requires multipart/form-data parsing
  // This is a placeholder - actual implementation would need FFI for ZIP extraction
  @api.error_response(
    501,
    "not_implemented",
    "ZIP upload requires native FFI support",
  )
}

///|
/// GET /plugins/{id}/settings - Get plugin settings
fn handle_get_settings(
  state : PluginManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Plugin ID is required")
  }
  let plugin_id = ctx.segments[1]
  match state.get_plugin(plugin_id) {
    None =>
      @api.error_response(404, "not_found", "Plugin '\{plugin_id}' not found")
    Some(_) => {
      let settings = state.get_settings(plugin_id).unwrap_or({})
      let response : PluginSettingsResponse = { plugin_id, settings }
      @api.json_response(200, { "data": response.to_json() })
    }
  }
}

///|
/// PUT /plugins/{id}/settings - Update plugin settings
fn handle_update_settings(
  state : PluginManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Plugin ID is required")
  }
  let plugin_id = ctx.segments[1]
  match state.get_plugin(plugin_id) {
    None =>
      @api.error_response(404, "not_found", "Plugin '\{plugin_id}' not found")
    Some(_) =>
      match @api.require_json_object(ctx.body) {
        Err(resp) => resp
        Ok(obj) => {
          state.set_settings(plugin_id, obj)
          @api.json_response(200, { "ok": true })
        }
      }
  }
}
