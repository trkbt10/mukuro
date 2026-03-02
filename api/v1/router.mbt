///|
/// REST API Router
/// Main routing logic for /api/v1/* endpoints

///|
/// Route handler function type
pub(all) struct RouteHandler((ApiRequestContext) -> ApiResponse)

///|
/// Registered routes
pub(all) struct ApiRouter {
  /// Plugin handlers
  plugin_handlers : PluginApiHandlers?
  /// Plugin action dispatcher (handles /plugins/{id}/actions/*)
  plugin_action_dispatcher : ((ApiRequestContext) -> ApiResponse)?
  /// Context handlers (file-based context management)
  context_handlers : ContextApiHandlers?
  /// Settings handlers
  settings_handlers : SettingsApiHandlers?
  /// Config handlers
  config_handlers : ConfigApiHandlers?
  /// Message provider handlers
  provider_handlers : ProviderApiHandlers?
  /// Chat handlers
  chat_handlers : ChatApiHandlers?
  /// History handlers
  history_handlers : HistoryApiHandlers?
  /// Tool handlers
  tool_handlers : ToolApiHandlers?
}

///|
/// Plugin API handlers interface
pub(all) struct PluginApiHandlers {
  /// GET /plugins - list all plugins
  list : RouteHandler
  /// GET /plugins/{id} - get plugin details
  get : RouteHandler
  /// POST /plugins - add plugin from manifest
  add : RouteHandler
  /// DELETE /plugins/{id} - remove plugin
  remove : RouteHandler
  /// PUT /plugins/{id}/enable - enable plugin
  enable : RouteHandler
  /// PUT /plugins/{id}/disable - disable plugin
  disable : RouteHandler
  /// POST /plugins/{id}/reload - reload plugin
  reload : RouteHandler
  /// POST /plugins/upload - upload plugin ZIP
  upload : RouteHandler
  /// GET /plugins/{id}/settings - get plugin settings
  get_settings : RouteHandler
  /// PUT /plugins/{id}/settings - update plugin settings
  update_settings : RouteHandler
}

///|
/// Context API handlers interface
pub(all) struct ContextApiHandlers {
  /// GET /context/data - list all context data files
  data_list : RouteHandler
  /// GET /context/data/{name} - get context data file
  data_get : RouteHandler
  /// PUT /context/data/{name} - update context data file
  data_update : RouteHandler
  /// DELETE /context/data/{name} - delete context data file
  data_delete : RouteHandler
  /// GET /context/templates - list all templates
  templates_list : RouteHandler
  /// GET /context/templates/{name} - get template
  templates_get : RouteHandler
}

///|
/// Settings API handlers interface
pub(all) struct SettingsApiHandlers {
  /// GET /settings - get all settings
  get_all : RouteHandler
  /// PUT /settings - update multiple settings
  update_all : RouteHandler
  /// GET /settings/retry - get retry settings
  get_retry : RouteHandler
  /// PUT /settings/retry - update retry settings
  update_retry : RouteHandler
  /// GET /settings/agent - get agent settings
  get_agent : RouteHandler
  /// PUT /settings/agent - update agent settings
  update_agent : RouteHandler
  /// GET /settings/model-inference - get merged model + thinking
  get_model_inference : RouteHandler
  /// PUT /settings/model-inference - update merged model + thinking
  update_model_inference : RouteHandler
  /// GET /settings/providers - list providers
  list_providers : RouteHandler
  /// PUT /settings/providers/{name} - update provider
  update_provider : RouteHandler
}

///|
/// Config API handlers interface
pub(all) struct ConfigApiHandlers {
  /// GET /config - get current config
  get : RouteHandler
  /// PUT /config - update config
  update : RouteHandler
  /// POST /config/reload - reload config from file
  reload : RouteHandler
  /// GET /config/file - get config file path
  get_file : RouteHandler
}

///|
/// Chat API handlers interface
pub(all) struct ChatApiHandlers {
  /// POST /chat/sessions - create new chat session
  create_session : RouteHandler
  /// GET /chat/sessions - list web chat sessions
  list_sessions : RouteHandler
  /// GET /chat/sessions/{chat_id}/history - get session history
  get_history : RouteHandler
  /// DELETE /chat/sessions/{chat_id} - delete a chat session
  delete_session : RouteHandler
  /// POST /chat/resume - resume from history session
  resume_session : RouteHandler
}

///|
/// History API handlers interface
pub(all) struct HistoryApiHandlers {
  /// GET /history/dates - list dates with history
  list_dates : RouteHandler
  /// GET /history/sessions?year=&month=&day= - list sessions for date
  list_sessions : RouteHandler
  /// GET /history/sessions/{session_id} - get session detail
  get_session : RouteHandler
}

///|
/// Message Provider API handlers interface
pub(all) struct ProviderApiHandlers {
  /// GET /providers - list all providers
  list : RouteHandler
  /// GET /providers/{id} - get provider details
  get : RouteHandler
  /// POST /providers - add new provider
  add : RouteHandler
  /// PUT /providers/{id} - update provider
  update : RouteHandler
  /// DELETE /providers/{id} - remove provider
  remove : RouteHandler
  /// PUT /providers/{id}/enable - enable provider
  enable : RouteHandler
  /// PUT /providers/{id}/disable - disable provider
  disable : RouteHandler
  /// POST /providers/{id}/connect - connect provider
  connect : RouteHandler
  /// POST /providers/{id}/disconnect - disconnect provider
  disconnect : RouteHandler
  /// POST /providers/{id}/test - test provider connection
  test_connection : RouteHandler
  /// GET /providers/types - get available provider types
  get_types : RouteHandler
  /// GET /providers/schema/{type} - get settings schema for provider type
  get_schema : RouteHandler
}

///|
/// Tool API handlers interface
pub(all) struct ToolApiHandlers {
  /// GET /tools - list all tools
  list : RouteHandler
  /// GET /tools/{id} - get tool details
  get : RouteHandler
  /// PUT /tools/{id}/enable - enable tool
  enable : RouteHandler
  /// PUT /tools/{id}/disable - disable tool
  disable : RouteHandler
  /// DELETE /tools/{id} - remove tool (user-defined only)
  remove : RouteHandler
}

///|
/// Create empty router
pub fn ApiRouter::new() -> ApiRouter {
  {
    plugin_handlers: None,
    plugin_action_dispatcher: None,
    context_handlers: None,
    settings_handlers: None,
    config_handlers: None,
    provider_handlers: None,
    chat_handlers: None,
    history_handlers: None,
    tool_handlers: None,
  }
}

///|
/// Route an API request
pub fn ApiRouter::route(
  self : ApiRouter,
  ctx : ApiRequestContext,
) -> ApiResponse {
  // Check body size limit
  match validate_body_size(ctx.body) {
    Some(resp) => return resp
    None => ()
  }
  // Check authorization first
  match validate_authorization(ctx) {
    Some(resp) => return resp
    None => ()
  }
  // Route based on first segment
  if ctx.segments.is_empty() {
    return api_index_handler(ctx)
  }
  let resource = ctx.segments[0]
  match resource {
    "plugins" => self.route_plugins(ctx)
    "context" => self.route_context(ctx)
    "settings" => self.route_settings(ctx)
    "config" => self.route_config(ctx)
    "providers" => self.route_providers(ctx)
    "chat" => self.route_chat(ctx)
    "history" => self.route_history(ctx)
    "tools" => self.route_tools(ctx)
    _ =>
      error_response(
        404,
        "not_found",
        "Unknown API endpoint: /api/v1/\{resource}",
      )
  }
}

///|
/// API index handler - returns API info
fn api_index_handler(_ctx : ApiRequestContext) -> ApiResponse {
  json_response(200, {
    "version": "v1",
    "endpoints": Json::array(
      [
        "/api/v1/plugins", "/api/v1/context", "/api/v1/settings", "/api/v1/config",
        "/api/v1/providers", "/api/v1/chat", "/api/v1/history", "/api/v1/tools",
      ].map(fn(s) { Json::string(s) }),
    ),
  })
}

///|
/// Route plugin API requests
fn ApiRouter::route_plugins(
  self : ApiRouter,
  ctx : ApiRequestContext,
) -> ApiResponse {
  // Check for action routes: /plugins/{id}/actions or /plugins/{id}/actions/{action}
  let segments = ctx.segments
  if segments.length() >= 3 && segments[2] == "actions" {
    match self.plugin_action_dispatcher {
      Some(dispatcher) => return dispatcher(ctx)
      None =>
        return error_response(
          501, "not_implemented", "Plugin actions not configured",
        )
    }
  }
  match self.plugin_handlers {
    None => error_response(501, "not_implemented", "Plugin API not configured")
    Some(handlers) => route_plugin_endpoint(handlers, ctx)
  }
}

///|
/// Route plugin endpoint
fn route_plugin_endpoint(
  handlers : PluginApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /plugins
  if segments.length() == 1 {
    match meth {
      "GET" => return (handlers.list.0)(ctx)
      "POST" => return (handlers.add.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  // /plugins/upload
  if segments.length() == 2 && segments[1] == "upload" {
    if meth == "POST" {
      return (handlers.upload.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /plugins/{id}
  if segments.length() == 2 {
    match meth {
      "GET" => return (handlers.get.0)(ctx)
      "DELETE" => return (handlers.remove.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  // /plugins/{id}/enable, /plugins/{id}/disable, /plugins/{id}/reload
  if segments.length() == 3 {
    let action = segments[2]
    match (meth, action) {
      ("PUT", "enable") => return (handlers.enable.0)(ctx)
      ("PUT", "disable") => return (handlers.disable.0)(ctx)
      ("POST", "reload") => return (handlers.reload.0)(ctx)
      ("GET", "settings") => return (handlers.get_settings.0)(ctx)
      ("PUT", "settings") => return (handlers.update_settings.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  error_response(404, "not_found", "Unknown plugin endpoint")
}

///|
/// Route context API requests
fn ApiRouter::route_context(
  self : ApiRouter,
  ctx : ApiRequestContext,
) -> ApiResponse {
  match self.context_handlers {
    None => error_response(501, "not_implemented", "Context API not configured")
    Some(handlers) => route_context_endpoint(handlers, ctx)
  }
}

///|
/// Route context endpoint
fn route_context_endpoint(
  handlers : ContextApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /context - index
  if segments.length() == 1 {
    if meth == "GET" {
      return json_response(200, {
        "endpoints": Json::array([
          Json::string("/api/v1/context/data"),
          Json::string("/api/v1/context/templates"),
        ]),
      })
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /context/data or /context/templates
  if segments.length() >= 2 {
    let sub = segments[1]
    match sub {
      "data" => route_context_data_endpoint(handlers, ctx)
      "templates" => route_context_templates_endpoint(handlers, ctx)
      _ =>
        error_response(
          404,
          "not_found",
          "Unknown context sub-endpoint: /context/\{sub}",
        )
    }
  } else {
    error_response(404, "not_found", "Unknown context endpoint")
  }
}

///|
/// Route /context/data/* endpoints
fn route_context_data_endpoint(
  handlers : ContextApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /context/data - list all
  if segments.length() == 2 {
    if meth == "GET" {
      return (handlers.data_list.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /context/data/{name}
  if segments.length() == 3 {
    match meth {
      "GET" => return (handlers.data_get.0)(ctx)
      "PUT" => return (handlers.data_update.0)(ctx)
      "DELETE" => return (handlers.data_delete.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  error_response(404, "not_found", "Unknown context data endpoint")
}

///|
/// Route /context/templates/* endpoints
fn route_context_templates_endpoint(
  handlers : ContextApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /context/templates - list all
  if segments.length() == 2 {
    if meth == "GET" {
      return (handlers.templates_list.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /context/templates/{name}
  if segments.length() == 3 {
    if meth == "GET" {
      return (handlers.templates_get.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  error_response(404, "not_found", "Unknown context templates endpoint")
}

///|
/// Route settings API requests
fn ApiRouter::route_settings(
  self : ApiRouter,
  ctx : ApiRequestContext,
) -> ApiResponse {
  match self.settings_handlers {
    None =>
      error_response(501, "not_implemented", "Settings API not configured")
    Some(handlers) => route_settings_endpoint(handlers, ctx)
  }
}

///|
/// Route settings endpoint
fn route_settings_endpoint(
  handlers : SettingsApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /settings
  if segments.length() == 1 {
    match meth {
      "GET" => return (handlers.get_all.0)(ctx)
      "PUT" => return (handlers.update_all.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  // /settings/retry, /settings/agent, /settings/model-inference, /settings/providers
  if segments.length() == 2 {
    let setting_type = segments[1]
    match (meth, setting_type) {
      ("GET", "retry") => return (handlers.get_retry.0)(ctx)
      ("PUT", "retry") => return (handlers.update_retry.0)(ctx)
      ("GET", "agent") => return (handlers.get_agent.0)(ctx)
      ("PUT", "agent") => return (handlers.update_agent.0)(ctx)
      ("GET", "model-inference") => return (handlers.get_model_inference.0)(ctx)
      ("PUT", "model-inference") =>
        return (handlers.update_model_inference.0)(ctx)
      ("GET", "providers") => return (handlers.list_providers.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  // /settings/providers/{name}
  if segments.length() == 3 && segments[1] == "providers" {
    if meth == "PUT" {
      return (handlers.update_provider.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  error_response(404, "not_found", "Unknown settings endpoint")
}

///|
/// Route config API requests
fn ApiRouter::route_config(
  self : ApiRouter,
  ctx : ApiRequestContext,
) -> ApiResponse {
  match self.config_handlers {
    None => error_response(501, "not_implemented", "Config API not configured")
    Some(handlers) => route_config_endpoint(handlers, ctx)
  }
}

///|
/// Route config endpoint
fn route_config_endpoint(
  handlers : ConfigApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /config
  if segments.length() == 1 {
    match meth {
      "GET" => return (handlers.get.0)(ctx)
      "PUT" => return (handlers.update.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  // /config/reload
  if segments.length() == 2 && segments[1] == "reload" {
    if meth == "POST" {
      return (handlers.reload.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /config/file
  if segments.length() == 2 && segments[1] == "file" {
    if meth == "GET" {
      return (handlers.get_file.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  error_response(404, "not_found", "Unknown config endpoint")
}

///|
/// Route provider API requests
fn ApiRouter::route_providers(
  self : ApiRouter,
  ctx : ApiRequestContext,
) -> ApiResponse {
  match self.provider_handlers {
    None =>
      error_response(501, "not_implemented", "Provider API not configured")
    Some(handlers) => route_provider_endpoint(handlers, ctx)
  }
}

///|
/// Route provider endpoint
fn route_provider_endpoint(
  handlers : ProviderApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /providers
  if segments.length() == 1 {
    match meth {
      "GET" => return (handlers.list.0)(ctx)
      "POST" => return (handlers.add.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  // /providers/types
  if segments.length() == 2 && segments[1] == "types" {
    if meth == "GET" {
      return (handlers.get_types.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /providers/schema/{type}
  if segments.length() == 3 && segments[1] == "schema" {
    if meth == "GET" {
      return (handlers.get_schema.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /providers/{id}
  if segments.length() == 2 {
    match meth {
      "GET" => return (handlers.get.0)(ctx)
      "PUT" => return (handlers.update.0)(ctx)
      "DELETE" => return (handlers.remove.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  // /providers/{id}/enable, /providers/{id}/disable, etc.
  if segments.length() == 3 {
    let action = segments[2]
    match (meth, action) {
      ("PUT", "enable") => return (handlers.enable.0)(ctx)
      ("PUT", "disable") => return (handlers.disable.0)(ctx)
      ("POST", "connect") => return (handlers.connect.0)(ctx)
      ("POST", "disconnect") => return (handlers.disconnect.0)(ctx)
      ("POST", "test") => return (handlers.test_connection.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  error_response(404, "not_found", "Unknown provider endpoint")
}

///|
/// Route chat API requests
fn ApiRouter::route_chat(
  self : ApiRouter,
  ctx : ApiRequestContext,
) -> ApiResponse {
  match self.chat_handlers {
    None => error_response(501, "not_implemented", "Chat API not configured")
    Some(handlers) => route_chat_endpoint(handlers, ctx)
  }
}

///|
/// Route chat endpoint
fn route_chat_endpoint(
  handlers : ChatApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /chat/sessions
  if segments.length() == 2 && segments[1] == "sessions" {
    match meth {
      "GET" => return (handlers.list_sessions.0)(ctx)
      "POST" => return (handlers.create_session.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  // /chat/resume
  if segments.length() == 2 && segments[1] == "resume" {
    if meth == "POST" {
      return (handlers.resume_session.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /chat/sessions/{chat_id}
  if segments.length() == 3 && segments[1] == "sessions" {
    if meth == "DELETE" {
      return (handlers.delete_session.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /chat/sessions/{chat_id}/history
  if segments.length() == 4 &&
    segments[1] == "sessions" &&
    segments[3] == "history" {
    if meth == "GET" {
      return (handlers.get_history.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  error_response(404, "not_found", "Unknown chat endpoint")
}

///|
/// Route history API requests
fn ApiRouter::route_history(
  self : ApiRouter,
  ctx : ApiRequestContext,
) -> ApiResponse {
  match self.history_handlers {
    None => error_response(501, "not_implemented", "History API not configured")
    Some(handlers) => route_history_endpoint(handlers, ctx)
  }
}

///|
/// Route history endpoint
fn route_history_endpoint(
  handlers : HistoryApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /history/dates
  if segments.length() == 2 && segments[1] == "dates" {
    if meth == "GET" {
      return (handlers.list_dates.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /history/sessions (with query params)
  if segments.length() == 2 && segments[1] == "sessions" {
    if meth == "GET" {
      return (handlers.list_sessions.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /history/sessions/{session_id}
  if segments.length() == 3 && segments[1] == "sessions" {
    if meth == "GET" {
      return (handlers.get_session.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  error_response(404, "not_found", "Unknown history endpoint")
}

///|
/// Route tool API requests
fn ApiRouter::route_tools(
  self : ApiRouter,
  ctx : ApiRequestContext,
) -> ApiResponse {
  match self.tool_handlers {
    None => error_response(501, "not_implemented", "Tool API not configured")
    Some(handlers) => route_tool_endpoint(handlers, ctx)
  }
}

///|
/// Route tool endpoint
fn route_tool_endpoint(
  handlers : ToolApiHandlers,
  ctx : ApiRequestContext,
) -> ApiResponse {
  let meth = ctx.http_method.to_upper()
  let segments = ctx.segments
  // /tools - list all
  if segments.length() == 1 {
    if meth == "GET" {
      return (handlers.list.0)(ctx)
    }
    return error_response(405, "method_not_allowed", "Method not allowed")
  }
  // /tools/{id}
  if segments.length() == 2 {
    match meth {
      "GET" => return (handlers.get.0)(ctx)
      "DELETE" => return (handlers.remove.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  // /tools/{id}/enable, /tools/{id}/disable
  if segments.length() == 3 {
    let action = segments[2]
    match (meth, action) {
      ("PUT", "enable") => return (handlers.enable.0)(ctx)
      ("PUT", "disable") => return (handlers.disable.0)(ctx)
      _ =>
        return error_response(405, "method_not_allowed", "Method not allowed")
    }
  }
  error_response(404, "not_found", "Unknown tool endpoint")
}
