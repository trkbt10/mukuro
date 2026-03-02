///|
/// Control API (native)
/// 外部クライアント向けの HTTP ルーティングと Gateway 連携

///|
pub(all) struct ControlApiResponse {
  status : Int
  body : String
  headers : Map[String, String]
}

// =============================================================================
// API v1 State Management
// =============================================================================

///|
/// Global API v1 state
let api_v1_settings_state : @api_settings.SettingsState = @api_settings.SettingsState::new()

///|
let api_v1_plugins_state : @api_plugins.PluginManagerState = @api_plugins.PluginManagerState::new()

///|
let api_v1_providers_state : @api_providers.ProviderManagerState = @api_providers.ProviderManagerState::new()

///|
let api_v1_tools_state : @api_tools.ToolManagerState = @api_tools.ToolManagerState::new()

///|
/// Create context data I/O interface
fn create_context_data_io() -> @api_context.ContextDataIO {
  {
    read: fn(path) {
      match read_text_file_optional(path) {
        Some(content) =>
          if content.trim(chars=" \t\n\r").length() > 0 {
            Some(content)
          } else {
            None
          }
        None => None
      }
    },
    write: fn(path, content) {
      @native.c_write_text_file_bytes(
        @native.string_to_utf8_cstring(path),
        @native.string_to_utf8_cstring(content),
      ) ==
      0
    },
    delete: fn(path) {
      @native.c_remove_file_bytes(@native.string_to_utf8_cstring(path)) == 0
    },
    get_dir: fn() { get_workspace_context_dir() },
  }
}

///|
/// Create template resolver interface
fn create_template_resolver() -> @api_context.TemplateResolver {
  {
    read_installed: fn(filename) {
      // Read template from install directory
      let install_dir = @config.config_dir() + "/templates"
      let path = install_dir + "/" + filename
      read_text_file_optional(path)
    },
    get_embedded: fn(file_type) {
      // Return embedded fallback template based on file type
      file_type.default_template()
    },
  }
}

///|
/// Global context state
let api_v1_context_state : @api_context.ContextState = @api_context.ContextState::new(
  create_context_data_io(),
  create_template_resolver(),
)

///|
/// Global history reader（data_dir() を使ってレコーダーと同じパスを参照）
let global_history_reader : @native.NativeHistoryReader = @native.NativeHistoryReader::new(
  base_dir=@config.data_dir(),
)

///|
/// Get API v1 router with handlers configured
fn get_api_v1_router() -> @api.ApiRouter {
  let history_reader : &@interfaces.HistoryReader = global_history_reader
  {
    plugin_handlers: Some(
      @api_plugins.create_plugin_handlers(api_v1_plugins_state),
    ),
    plugin_action_dispatcher: Some(fn(ctx) {
      let segments = ctx.segments
      let meth = ctx.http_method.to_upper()
      // GET /plugins/{id}/actions - list actions
      if segments.length() == 3 && meth == "GET" {
        return @api_plugins.handle_list_actions(api_v1_plugins_state, ctx)
      }
      // POST /plugins/{id}/actions/{action} - invoke action
      if segments.length() == 4 && meth == "POST" {
        return @api_plugins.handle_invoke_action(api_v1_plugins_state, ctx)
      }
      @api.error_response(405, "method_not_allowed", "Method not allowed")
    }),
    context_handlers: Some(
      @api_context.create_context_handlers(api_v1_context_state),
    ),
    settings_handlers: Some(
      @api_settings.create_settings_handlers(api_v1_settings_state),
    ),
    config_handlers: None,
    provider_handlers: Some(
      @api_providers.create_provider_handlers(api_v1_providers_state),
    ),
    chat_handlers: Some(
      @api_chat.create_chat_handlers(
        @api_chat.ChatState::new_with_session_manager(global_session_manager, get_timestamp=fn() {
          @native.c_time() * 1000
        }),
      ),
    ),
    history_handlers: Some(
      @api_history.create_history_handlers(
        @api_history.HistoryState::new(history_reader),
      ),
    ),
    tool_handlers: Some(@api_tools.create_tool_handlers(api_v1_tools_state)),
  }
}

///|
/// Initialize API v1 state from config
pub fn init_api_v1_state(
  config : @types.MukuroConfig,
  config_path : String,
) -> Unit {
  api_v1_settings_state.init(config, config_path)
  api_v1_settings_state.set_persister(persist_config_to_file)
  // ビルトインプラグインを登録（全ビルトインツールを提供）
  api_v1_plugins_state.set_plugin(
    "builtin",
    @interfaces.PluginState::builtin(
      id="builtin",
      description="Built-in tools: datetime, memory, message, spawn, web, shell, filesystem",
    ),
  )
  // ビルトインツールをツール状態に登録（source: Plugin("builtin")）
  for def in @tools.all_tool_definitions() {
    api_v1_tools_state.set_tool(
      def.name,
      @interfaces.ToolState::builtin(
        id=def.name,
        name=def.name,
        description=def.description,
        parameters=def.parameters,
        settings_schema=@tools.get_settings_schema(def.name),
      ),
    )
  }
  // ユーザー定義ツールを {data_dir}/tools/ からロード
  for tool_state in @plugin_runtime.load_native_user_defined_tools() {
    api_v1_tools_state.set_tool(tool_state.id, tool_state)
  }
  // builtin プラグインにアクションを登録（定義から自動登録）
  for action in @builtin.get_all_builtin_actions(global_memory_store) {
    api_v1_plugins_state.register_action("builtin", action.name, action.handler)
  }
  // memory ツールにアクションを登録
  register_memory_tool_actions(api_v1_tools_state, global_memory_store)
}

///|
/// Register memory tool actions
fn register_memory_tool_actions(
  state : @api_tools.ToolManagerState,
  store : @tools.MemoryStore,
) -> Unit {
  // list - 全エントリを取得
  state.register_action(
    "memory",
    "list",
    @api_tools.ToolActionHandler(fn(_params) {
      let keys = store.keys()
      let entries : Array[Json] = []
      for key in keys {
        let entry : Map[String, Json] = {}
        entry["key"] = Json::string(key)
        match store.get(key) {
          Some(value) => entry["value"] = value
          None => ()
        }
        entries.push(Json::object(entry))
      }
      @api.json_response(200, {
        "data": { "entries": Json::array(entries), "count": keys.length() },
      })
    }),
  )
  // get - 単一エントリを取得
  state.register_action(
    "memory",
    "get",
    @api_tools.ToolActionHandler(fn(params) {
      let key = match params {
        { "key": String(k), .. } => k
        _ =>
          return @api.error_response(
            400, "bad_request", "Missing 'key' parameter",
          )
      }
      match store.get(key) {
        Some(value) =>
          @api.json_response(200, { "data": { "key": key, "value": value } })
        None => @api.error_response(404, "not_found", "Key '\{key}' not found")
      }
    }),
  )
  // set - エントリを設定
  state.register_action(
    "memory",
    "set",
    @api_tools.ToolActionHandler(fn(params) {
      let key = match params {
        { "key": String(k), .. } => k
        _ =>
          return @api.error_response(
            400, "bad_request", "Missing 'key' parameter",
          )
      }
      let value = match params {
        { "value": v, .. } => v
        _ =>
          return @api.error_response(
            400, "bad_request", "Missing 'value' parameter",
          )
      }
      store.set(key, value)
      @api.json_response(200, { "ok": true, "key": key })
    }),
  )
  // delete - エントリを削除
  state.register_action(
    "memory",
    "delete",
    @api_tools.ToolActionHandler(fn(params) {
      let key = match params {
        { "key": String(k), .. } => k
        _ =>
          return @api.error_response(
            400, "bad_request", "Missing 'key' parameter",
          )
      }
      let deleted = store.delete(key)
      @api.json_response(200, { "ok": true, "deleted": deleted })
    }),
  )
  // clear - 全エントリを削除
  state.register_action(
    "memory",
    "clear",
    @api_tools.ToolActionHandler(fn(_params) {
      store.clear()
      @api.json_response(200, { "ok": true })
    }),
  )
}

///|
/// Persist config to file
fn persist_config_to_file(config : @types.MukuroConfig, path : String) -> Unit {
  let json = config.to_json()
  let content = json.stringify(indent=2)
  write_config_file(path, content)
}

///|
/// Write config content to file
fn write_config_file(path : String, content : String) -> Unit {
  @native.native_write_file_text(path, content) catch {
    _ => ()
  }
}

///|
/// Convert ApiResponse to ControlApiResponse
fn api_response_to_control(resp : @api.ApiResponse) -> ControlApiResponse {
  add_cors_headers({
    status: resp.status,
    body: resp.body,
    headers: resp.headers,
  })
}

///|
fn json_response(status : Int, body : Json) -> ControlApiResponse {
  let headers : Map[String, String] = {}
  headers["content-type"] = "application/json"
  add_cors_headers({ status, body: body.stringify(), headers })
}

///|
fn error_response(
  status : Int,
  code : String,
  message : String,
) -> ControlApiResponse {
  json_response(status, { "error": code, "message": message })
}

///|
fn parse_client_id(headers : Map[String, String]) -> String {
  let candidate = match headers.get("x-mukuro-client-id") {
    Some(v) => v
    None =>
      match headers.get("X-Mukuro-Client-Id") {
        Some(v) => v
        None => "unknown"
      }
  }
  let trimmed = candidate.trim(chars=" \t\n\r").to_string()
  if trimmed.length() == 0 {
    "unknown"
  } else {
    trimmed
  }
}

///|
fn append_control_api_auth_audit(
  event : Int,
  value : Int,
  client_id : String,
  reason : String,
) -> Unit {
  ignore(
    @native.c_append_gateway_auth_audit_detail_bytes(
      @native.c_time(),
      event,
      value,
      @native.string_to_utf8_cstring("control_api"),
      @native.string_to_utf8_cstring(client_id),
      -1,
      @native.string_to_utf8_cstring(reason),
      -1,
      -1,
    ),
  )
}

///|
/// All authenticated requests are treated as admin.
/// Role is NOT read from client headers to prevent role spoofing.
fn validate_control_api_authorization() -> ControlApiResponse? {
  None
}

///|
fn parse_bearer_token(headers : Map[String, String]) -> String {
  let raw = match headers.get("authorization") {
    Some(v) => v
    None =>
      match headers.get("Authorization") {
        Some(v) => v
        None => ""
      }
  }
  match @interfaces.extract_bearer_token(raw) {
    Some(token) => token
    None => ""
  }
}

///|
fn status_json(status : @interfaces.GatewayStatus) -> Json {
  let channels : Array[Json] = []
  for ch in status.connected_channels {
    channels.push(Json::string(ch))
  }
  {
    "state": status.state.to_string(),
    "version": status.version,
    "active_sessions": status.active_sessions,
    "connected_channels": Json::array(channels),
    "started_at": match status.started_at {
      Some(v) => Json::number(v.to_double())
      None => Json::null()
    },
  }
}

///|
fn health_summary_json(status : @interfaces.GatewayStatus) -> Json {
  let health = match status.health {
    Some(h) => h.overall.to_string()
    None => "unknown"
  }
  { "status": health }
}

///|
fn health_live_json(status : @interfaces.GatewayStatus) -> Json {
  let live = status.state.is_running()
  { "status": if live { "ok" } else { "down" }, "live": live }
}

///|
fn health_ready_json(status : @interfaces.GatewayStatus) -> Json {
  let live = status.state.is_running()
  let ready = match status.health {
    Some(h) => live && h.overall.to_string() != "unhealthy"
    None => live
  }
  { "status": if ready { "ok" } else { "not_ready" }, "ready": ready }
}

///|
fn parse_metadata(value : Json?) -> Map[String, Json] {
  match value {
    Some(Object(obj)) => obj
    _ => {}
  }
}

///|
fn parse_dispatch_envelope(body : String) -> @types.InboundEnvelope? {
  let parsed : Json = @json.parse(body) catch { _ => return None }
  match parsed {
    Object(obj) => {
      let channel = match obj.get("channel") {
        Some(String(v)) => v
        _ => return None
      }
      let chat_id = match obj.get("chat_id") {
        Some(String(v)) => v
        _ => return None
      }
      let sender_id = match obj.get("sender_id") {
        Some(String(v)) => v
        _ => return None
      }
      let content = match obj.get("content") {
        Some(String(v)) => v
        _ => return None
      }
      let sender_name = match obj.get("sender_name") {
        Some(String(v)) => v
        _ => sender_id
      }
      let metadata = parse_metadata(obj.get("metadata"))
      Some({
        channel,
        chat_id,
        sender_id,
        sender_name,
        content,
        message_type: @types.MessageType::Text,
        metadata,
        timestamp: @native.c_time() * 1000,
      })
    }
    _ => None
  }
}

///|
fn parse_outbound_options(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Object(obj)) => Some(obj)
    Some(Null) => None
    None => None
    _ => None
  }
}

///|
fn parse_outbound_message(body : String) -> @types.OutboundMessage? {
  let parsed : Json = @json.parse(body) catch { _ => return None }
  match parsed {
    Object(obj) => {
      let channel = match obj.get("channel") {
        Some(String(v)) => v
        _ => return None
      }
      let chat_id = match obj.get("chat_id") {
        Some(String(v)) => v
        _ => return None
      }
      let content = match obj.get("content") {
        Some(String(v)) => v
        _ => return None
      }
      let reply_to = match obj.get("reply_to") {
        Some(String(v)) => Some(v)
        Some(Null) => None
        None => None
        _ => None
      }
      let options = parse_outbound_options(obj.get("options"))
      Some({ channel, chat_id, content, reply_to, attachments: None, options })
    }
    _ => None
  }
}

///|
fn control_error_to_response(
  err : @interfaces.ControlError,
) -> ControlApiResponse {
  match err {
    @interfaces.ControlError::Auth(@interfaces.AuthError::InvalidToken(msg)) =>
      error_response(401, "unauthorized", msg)
    @interfaces.ControlError::Auth(@interfaces.AuthError::TokenExpired) =>
      error_response(401, "token_expired", "Token expired")
    @interfaces.ControlError::Auth(@interfaces.AuthError::Unauthorized(msg)) =>
      error_response(401, "unauthorized", msg)
    @interfaces.ControlError::AlreadyRunning =>
      error_response(409, "already_running", "Gateway already running")
    @interfaces.ControlError::AlreadyStopped =>
      error_response(409, "already_stopped", "Gateway already stopped")
    @interfaces.ControlError::ConfigError(msg) =>
      error_response(500, "config_error", msg)
    @interfaces.ControlError::ChannelError(msg) =>
      error_response(502, "channel_error", msg)
    @interfaces.ControlError::InternalError(msg) =>
      error_response(500, "internal_error", msg)
  }
}

///|
fn validate_control_api_auth(
  gateway : @control.Gateway,
  headers : Map[String, String],
) -> ControlApiResponse? {
  let token = parse_bearer_token(headers)
  let client_id = parse_client_id(headers)
  match gateway.authenticate(token~) {
    @interfaces.AuthResult::Authenticated(_) => None
    @interfaces.AuthResult::Denied(msg) => {
      append_control_api_auth_audit(1, 1, client_id, "unauthorized")
      Some(error_response(401, "unauthorized", msg))
    }
    @interfaces.AuthResult::Expired => {
      append_control_api_auth_audit(1, 1, client_id, "token_expired")
      Some(error_response(401, "token_expired", "Token expired"))
    }
  }
}

///|
fn validate_control_api_access(
  gateway : @control.Gateway,
  headers : Map[String, String],
) -> ControlApiResponse? {
  match validate_control_api_auth(gateway, headers) {
    Some(resp) => Some(resp)
    None => validate_control_api_authorization()
  }
}

///|
/// Default base URLs for known providers
fn get_default_provider_base_url(provider_name : String) -> String? {
  match provider_name {
    "anthropic" => Some("https://api.anthropic.com")
    "openai" => Some("https://api.openai.com")
    "groq" => Some("https://api.groq.com/openai")
    _ => None
  }
}

///|
/// Fetch models from a provider's /v1/models endpoint
async fn fetch_live_provider_models(
  provider_name : String,
  api_key : String,
  base_url : String,
) -> Array[String] {
  let http = @native.NativeHttpClient::new(
    timeout_seconds=10,
    user_agent="mukuro/0.1.0",
  )
  let url = if base_url.has_suffix("/") {
    base_url + "v1/models"
  } else {
    base_url + "/v1/models"
  }
  let headers : Map[String, String] = {}
  headers["Accept"] = "application/json"
  if provider_name == "anthropic" {
    headers["x-api-key"] = api_key
    headers["anthropic-version"] = "2023-06-01"
  } else {
    headers["Authorization"] = "Bearer " + api_key
  }
  let response = http.do_request_async({
    url,
    http_method: @interfaces.HttpMethod::Get,
    headers,
    body: None,
  }) catch {
    _ => return []
  }
  if response.status != 200 {
    return []
  }
  let body_str = @bytes.decode_utf8_or(response.body[:], default="")
  let json : Json = @json.parse(body_str) catch { _ => return [] }
  let models : Array[String] = []
  match json {
    Object(obj) =>
      match obj.get("data") {
        Some(Array(arr)) =>
          for item in arr {
            match item {
              Object(model_obj) =>
                match model_obj.get("id") {
                  Some(String(id)) => models.push(id)
                  _ => ()
                }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  models
}

///|
/// Async handler for GET /api/v1/settings/providers/{name}/models.
/// Fetches live models from the provider API. Returns empty array on failure.
async fn try_fetch_provider_models(path : String) -> ControlApiResponse? {
  let views = path.split("/").collect()
  // ["", "api", "v1", "settings", "providers", "{name}", "models"]
  if views.length() < 7 || views[4] != "providers" || views[6] != "models" {
    return None
  }
  let provider_name = views[5].to_string()
  if provider_name.length() == 0 {
    return None
  }
  let empty = Some(json_response(200, { "data": Json::array([]) }))
  let config = match api_v1_settings_state.get_config() {
    Some(c) => c
    None => return empty
  }
  for p in config.providers {
    if p.name == provider_name {
      let base_url = match p.base_url {
        Some(url) => url
        None =>
          match get_default_provider_base_url(provider_name) {
            Some(url) => url
            None => return empty
          }
      }
      let api_key = match p.api_key {
        Some(key) => key
        None => return empty
      }
      let models = fetch_live_provider_models(provider_name, api_key, base_url)
      let arr : Array[Json] = models.map(fn(m) { Json::string(m) })
      return Some(json_response(200, { "data": Json::array(arr) }))
    }
  }
  empty
}

///|
/// Add CORS headers to a response
fn add_cors_headers(resp : ControlApiResponse) -> ControlApiResponse {
  resp.headers["Access-Control-Allow-Origin"] = "http://localhost:3000"
  resp.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
  resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Mukuro-Client-Id"
  resp.headers["Access-Control-Max-Age"] = "3600"
  resp
}

///|
pub async fn handle_control_api_request(
  gateway : @control.Gateway,
  meth : @xhttp.RequestMethod,
  path : String,
  headers : Map[String, String],
  body : String,
) -> ControlApiResponse {
  // Handle CORS preflight
  if meth is @xhttp.RequestMethod::Options {
    return add_cors_headers(json_response(204, Json::null()))
  }
  // Route /api/v1/* to API v1 router
  if path.has_prefix("/api/v1") {
    // Validate auth first
    match validate_control_api_auth(gateway, headers) {
      Some(resp) => return resp
      None => ()
    }
    // Create API context
    let meth_str = match meth {
      @xhttp.RequestMethod::Get => "GET"
      @xhttp.RequestMethod::Post => "POST"
      @xhttp.RequestMethod::Put => "PUT"
      @xhttp.RequestMethod::Delete => "DELETE"
      _ => "GET"
    }
    // Async intercept: live model fetch from provider APIs
    if meth_str == "GET" {
      match try_fetch_provider_models(path) {
        Some(resp) => return resp
        None => ()
      }
    }
    // Async intercept: onboard context generation via LLM
    if meth_str == "POST" && path == "/api/v1/onboard/generate" {
      return try_onboard_generate(body)
    }
    let ctx = @api.ApiRequestContext::new(
      meth=meth_str,
      path~,
      headers~,
      body~,
      role=@api.ApiRole::Admin,
    )
    let router = get_api_v1_router()
    let resp = router.route(ctx)
    return api_response_to_control(resp)
  }
  match meth {
    @xhttp.RequestMethod::Get =>
      if path == "/status" {
        match validate_control_api_access(gateway, headers) {
          Some(resp) => return resp
          None => ()
        }
        return json_response(200, status_json(gateway.status()))
      } else if path == "/health" {
        match validate_control_api_access(gateway, headers) {
          Some(resp) => return resp
          None => ()
        }
        return json_response(200, health_summary_json(gateway.status()))
      } else if path == "/health/live" {
        match validate_control_api_access(gateway, headers) {
          Some(resp) => return resp
          None => ()
        }
        return json_response(200, health_live_json(gateway.status()))
      } else if path == "/health/ready" {
        match validate_control_api_access(gateway, headers) {
          Some(resp) => return resp
          None => ()
        }
        return json_response(200, health_ready_json(gateway.status()))
      } else {
        return error_response(404, "not_found", "Unknown endpoint")
      }
    @xhttp.RequestMethod::Post =>
      if path != "/dispatch" && path != "/dispatch/outbound" {
        return error_response(404, "not_found", "Unknown endpoint")
      }
    _ => return error_response(405, "method_not_allowed", "Unsupported method")
  }

  match validate_control_api_access(gateway, headers) {
    Some(resp) => return resp
    None => ()
  }

  let token = parse_bearer_token(headers)
  let auth = @interfaces.AuthContext::token_only(token)
  if path == "/dispatch/outbound" {
    let outbound = parse_outbound_message(body)
    match outbound {
      Some(msg) =>
        gateway.dispatch_outbound(auth~, message=msg) catch {
          e => return control_error_to_response(e)
        }
      None =>
        return error_response(
          400, "bad_request", "Invalid outbound dispatch payload",
        )
    }
  } else {
    let envelope = parse_dispatch_envelope(body)
    match envelope {
      Some(env) =>
        gateway.dispatch_inbound(auth~, envelope=env) catch {
          e => return control_error_to_response(e)
        }
      None =>
        return error_response(400, "bad_request", "Invalid dispatch payload")
    }
  }
  json_response(200, { "ok": true })
}

///|
async fn handle_control_api_dispatch_async(
  gateway : @control.Gateway,
  headers : Map[String, String],
  body : String,
) -> ControlApiResponse {
  match validate_control_api_access(gateway, headers) {
    Some(resp) => return resp
    None => ()
  }
  let envelope = parse_dispatch_envelope(body)
  let auth = @interfaces.AuthContext::token_only(parse_bearer_token(headers))
  match envelope {
    Some(env) => {
      // SessionManager handles all history recording - no separate recorder needed
      let outbound = handle_inbound_with_agent_loop(env, None) catch {
        e =>
          match e {
            @agent.AgentLoopError::ModelCallFailed(msg) =>
              return error_response(
                500,
                "model_call_failed",
                "Agent handler failed: \{msg}",
              )
            _ =>
              return error_response(
                500,
                "internal_error",
                "Agent handler failed: \{e}",
              )
          }
      }
      gateway.dispatch_outbound(auth~, message=outbound) catch {
        e => return control_error_to_response(e)
      }
      json_response(200, {
        "ok": true,
        "response": {
          "channel": outbound.channel.to_json(),
          "chat_id": outbound.chat_id.to_json(),
          "content": outbound.content.to_json(),
        },
      })
    }
    None => error_response(400, "bad_request", "Invalid dispatch payload")
  }
}

///|
pub fn control_api_healthcheck_message() -> String {
  "control-api-native-ready"
}

///|
pub async fn run_control_api_server_blocking(
  gateway : @control.Gateway,
  host : String,
  port : Int,
) -> Unit {
  run_control_api_server_with_tick_blocking(gateway, host, port, fn() { true })
}

///|
pub async fn run_control_api_server_with_tick_blocking(
  gateway : @control.Gateway,
  host : String,
  port : Int,
  on_tick : () -> Bool,
) -> Unit {
  @async.with_task_group(group => {
    let server = @xhttp.Server::new(host~, port~) catch { e => raise e }
    defer server.close()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((req, body_reader, conn) => {
        // Check for WebSocket upgrade to /ws/chat
        if req.path.has_prefix("/ws/chat") && is_websocket_upgrade(req.headers) {
          let http_req = to_async_http_request(req)
          let ws = @async_ws.from_http_server(http_req, conn.inner) catch {
            _ => return
          }
          defer ws.close()
          // Extract chat_id query parameter for resume
          let resume_chat_id = @url.get_param(req.path, "chat_id")
          let handler = ChatWsHandler::new(resume_chat_id~)
          handler.handle_connection(ws) catch {
            _ => ()
          }
          return
        }
        let body_data = @io.Reader::read_all(body_reader) catch {
          _ => {
            conn.send_response(400, "Bad Request", extra_headers={
              "content-type": "application/json",
            })
            conn.write(
              "{\"error\":\"bad_request\",\"message\":\"Failed to read request body\"}",
            )
            conn.end_response()
            return
          }
        }
        let body_text = body_data.text() catch { _ => "" }
        let response = if req.meth == @xhttp.RequestMethod::Post &&
          req.path == "/dispatch" {
          handle_control_api_dispatch_async(gateway, req.headers, body_text)
        } else {
          handle_control_api_request(
            gateway,
            req.meth,
            req.path,
            req.headers,
            body_text,
          )
        }
        conn.send_response(
          response.status,
          "OK",
          extra_headers=response.headers,
        )
        conn.write(response.body)
        conn.end_response()
      })
    })
    while true {
      @async.sleep(100)
      if !on_tick() {
        server.close()
        break
      }
    }
  })
}

// =============================================================================
// WebSocket Chat Helpers
// =============================================================================

///|
/// Check if request is a WebSocket upgrade
fn is_websocket_upgrade(headers : Map[String, String]) -> Bool {
  let upgrade = match headers.get("upgrade") {
    Some(u) => Some(u)
    None => headers.get("Upgrade")
  }
  let connection = match headers.get("connection") {
    Some(c) => Some(c)
    None => headers.get("Connection")
  }
  match (upgrade, connection) {
    (Some(u), Some(c)) =>
      u.to_lower() == "websocket" && c.to_lower().contains("upgrade")
    _ => false
  }
}

///|
/// Convert @xhttp.Request to @async_http.Request for WebSocket upgrade
fn to_async_http_request(req : @xhttp.Request) -> @async_http.Request {
  let meth = match req.meth {
    @xhttp.RequestMethod::Get => @async_http.RequestMethod::Get
    @xhttp.RequestMethod::Post => @async_http.RequestMethod::Post
    @xhttp.RequestMethod::Put => @async_http.RequestMethod::Put
    @xhttp.RequestMethod::Delete => @async_http.RequestMethod::Delete
    @xhttp.RequestMethod::Head => @async_http.RequestMethod::Head
    @xhttp.RequestMethod::Options => @async_http.RequestMethod::Options
    @xhttp.RequestMethod::Patch => @async_http.RequestMethod::Patch
    @xhttp.RequestMethod::Trace => @async_http.RequestMethod::Trace
    @xhttp.RequestMethod::Connect => @async_http.RequestMethod::Connect
  }
  @async_http.Request::{ meth, path: req.path, headers: req.headers }
}

///|
/// グローバルカウンター（UUID生成ごとにインクリメント）
let ws_chat_id_counter : Ref[Int] = { val: 0 }

///|
/// Generate UUID v4 for chat_id using non-deterministic seed
/// Uses system time, PID, and a counter to ensure uniqueness
fn generate_ws_chat_id() -> String {
  // シードを構築: 時刻 + PID + カウンター
  let now = @native.c_time()
  let pid = @native.c_getpid()
  ws_chat_id_counter.val = ws_chat_id_counter.val + 1
  let counter = ws_chat_id_counter.val

  // 32バイトのシードを作成（makei で各バイトを計算）
  let seed = Bytes::makei(32, fn(i) {
    match i {
      // 時刻（8バイト）
      0 => (now & 0xFFL).to_byte()
      1 => ((now >> 8) & 0xFFL).to_byte()
      2 => ((now >> 16) & 0xFFL).to_byte()
      3 => ((now >> 24) & 0xFFL).to_byte()
      4 => ((now >> 32) & 0xFFL).to_byte()
      5 => ((now >> 40) & 0xFFL).to_byte()
      6 => ((now >> 48) & 0xFFL).to_byte()
      7 => ((now >> 56) & 0xFFL).to_byte()
      // PID（4バイト）
      8 => (pid & 0xFF).to_byte()
      9 => ((pid >> 8) & 0xFF).to_byte()
      10 => ((pid >> 16) & 0xFF).to_byte()
      11 => ((pid >> 24) & 0xFF).to_byte()
      // カウンター（4バイト）
      12 => (counter & 0xFF).to_byte()
      13 => ((counter >> 8) & 0xFF).to_byte()
      14 => ((counter >> 16) & 0xFF).to_byte()
      15 => ((counter >> 24) & 0xFF).to_byte()
      // 残りはゼロ
      _ => b'\x00'
    }
  })

  let random = @random.Rand::chacha8(seed~)
  let bytes = Bytes::makei(16, fn(_i) { random.uint(limit=256U).to_byte() })
  @uuid.from_bytes(bytes).as_version(@uuid.V4).to_string() catch {
    _ => abort("unreachable: 16-byte UUID input is always valid")
  }
}
