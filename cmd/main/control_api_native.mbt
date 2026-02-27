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
/// Create context file I/O interface
fn create_context_file_io() -> @api_context.ContextFileIO {
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
      @native.c_write_text_file(
        @native.string_to_cstring(path),
        @native.string_to_cstring(content),
      ) ==
      0
    },
    delete: fn(path) { @native.c_remove_file(@native.string_to_cstring(path)) == 0 },
    get_dir: fn() { get_workspace_context_dir() },
  }
}

///|
/// Global context state
let api_v1_context_state : @api_context.ContextState = @api_context.ContextState::new(
  create_context_file_io(),
)

///|
/// Get API v1 router with handlers configured
fn get_api_v1_router() -> @api.ApiRouter {
  {
    plugin_handlers: Some(@api_plugins.create_plugin_handlers(api_v1_plugins_state)),
    context_handlers: Some(@api_context.create_context_handlers(api_v1_context_state)),
    settings_handlers: Some(@api_settings.create_settings_handlers(api_v1_settings_state)),
    config_handlers: None,
    provider_handlers: Some(@api_providers.create_provider_handlers(api_v1_providers_state)),
  }
}

///|
/// Initialize API v1 state from config
pub fn init_api_v1_state(config : @types.MukuroConfig, config_path : String) -> Unit {
  api_v1_settings_state.init(config, config_path)
  api_v1_settings_state.set_persister(persist_config_to_file)
  api_v1_plugins_state.init_builtins()
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
  let cpath = @native.string_to_cstring(path)
  let mode = @native.string_to_cstring("w")
  let file = @native.c_fopen(cpath, mode)
  match file {
    Some(f) => {
      let bytes = content.to_bytes()
      ignore(@native.c_fwrite(bytes, 1, bytes.length(), f))
      ignore(@native.c_fclose(f))
    }
    None => () // Failed to open file, silently ignore
  }
}

///|
/// Convert ApiResponse to ControlApiResponse
fn api_response_to_control(resp : @api.ApiResponse) -> ControlApiResponse {
  { status: resp.status, body: resp.body, headers: resp.headers }
}

///|
enum ControlAction {
  ReadStatus
  ReadHealth
  Dispatch
}

///|
fn json_response(status : Int, body : Json) -> ControlApiResponse {
  let headers : Map[String, String] = {}
  headers["content-type"] = "application/json"
  { status, body: body.stringify(), headers }
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
fn parse_role(headers : Map[String, String]) -> String? {
  match headers.get("x-mukuro-role") {
    Some(v) => Some(v.trim(chars=" \t\n\r").to_string().to_lower())
    None =>
      match headers.get("X-Mukuro-Role") {
        Some(v) => Some(v.trim(chars=" \t\n\r").to_string().to_lower())
        None => None
      }
  }
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
    @native.c_append_gateway_auth_audit_detail(
      @native.c_time(),
      event,
      value,
      @native.string_to_cstring("control_api"),
      @native.string_to_cstring(client_id),
      -1,
      @native.string_to_cstring(reason),
      -1,
      -1,
    ),
  )
}

///|
fn is_action_allowed(role : String, action : ControlAction) -> Bool {
  match role {
    "admin" => true
    "operator" =>
      match action {
        ControlAction::ReadStatus => true
        ControlAction::ReadHealth => true
        ControlAction::Dispatch => true
      }
    "viewer" =>
      match action {
        ControlAction::ReadStatus => true
        ControlAction::ReadHealth => true
        ControlAction::Dispatch => false
      }
    _ => false
  }
}

///|
fn validate_control_api_authorization(
  headers : Map[String, String],
  action : ControlAction,
) -> ControlApiResponse? {
  let client_id = parse_client_id(headers)
  match parse_role(headers) {
    None => None
    Some(role) =>
      if is_action_allowed(role, action) {
        None
      } else {
        append_control_api_auth_audit(4, 1, client_id, "forbidden")
        Some(error_response(403, "forbidden", "Role is not allowed"))
      }
  }
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
  action : ControlAction,
) -> ControlApiResponse? {
  match validate_control_api_auth(gateway, headers) {
    Some(resp) => Some(resp)
    None => validate_control_api_authorization(headers, action)
  }
}


///|
pub async fn handle_control_api_request(
  gateway : @control.Gateway,
  meth : @xhttp.RequestMethod,
  path : String,
  headers : Map[String, String],
  body : String,
) -> ControlApiResponse {
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
    let ctx = @api.ApiRequestContext::new(meth=meth_str, path~, headers~, body~)
    let router = get_api_v1_router()
    let resp = router.route(ctx)
    return api_response_to_control(resp)
  }
  match meth {
    @xhttp.RequestMethod::Get =>
      if path == "/status" {
        match
          validate_control_api_access(
            gateway,
            headers,
            ControlAction::ReadStatus,
          ) {
          Some(resp) => return resp
          None => ()
        }
        return json_response(
          200,
          status_json(gateway.status()),
        )
      } else if path == "/health" {
        match
          validate_control_api_access(
            gateway,
            headers,
            ControlAction::ReadHealth,
          ) {
          Some(resp) => return resp
          None => ()
        }
        return json_response(
          200,
          health_summary_json(gateway.status()),
        )
      } else if path == "/health/live" {
        match
          validate_control_api_access(
            gateway,
            headers,
            ControlAction::ReadHealth,
          ) {
          Some(resp) => return resp
          None => ()
        }
        return json_response(
          200,
          health_live_json(gateway.status()),
        )
      } else if path == "/health/ready" {
        match
          validate_control_api_access(
            gateway,
            headers,
            ControlAction::ReadHealth,
          ) {
          Some(resp) => return resp
          None => ()
        }
        return json_response(
          200,
          health_ready_json(gateway.status()),
        )
      } else {
        return error_response(404, "not_found", "Unknown endpoint")
      }
    @xhttp.RequestMethod::Post =>
      if path != "/dispatch" && path != "/dispatch/outbound" {
        return error_response(404, "not_found", "Unknown endpoint")
      }
    _ => return error_response(405, "method_not_allowed", "Unsupported method")
  }

  match validate_control_api_access(gateway, headers, ControlAction::Dispatch) {
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
  match validate_control_api_access(gateway, headers, ControlAction::Dispatch) {
    Some(resp) => return resp
    None => ()
  }
  let envelope = parse_dispatch_envelope(body)
  let auth = @interfaces.AuthContext::token_only(parse_bearer_token(headers))
  match envelope {
    Some(env) => {
      let outbound = handle_inbound_with_agent_loop_async(env) catch {
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
      json_response(200, { "ok": true })
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
) -> Unit raise {
  run_control_api_server_with_tick_blocking(gateway, host, port, fn() { true })
}

///|
pub async fn run_control_api_server_with_tick_blocking(
  gateway : @control.Gateway,
  host : String,
  port : Int,
  on_tick : () -> Bool,
) -> Unit raise {
  @async.with_task_group((group) => {
    let server = @xhttp.Server::new(host~, port~) catch { e => raise e }
    defer server.close()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((req, body_reader, conn) => {
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
