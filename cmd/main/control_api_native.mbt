///|
/// Control API (native)
/// 外部クライアント向けの HTTP ルーティングと Gateway 連携

///|
pub(all) struct ControlApiResponse {
  status : Int
  body : String
  headers : Map[String, String]
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
pub fn handle_control_api_request(
  gateway : @control.Gateway,
  meth : @xhttp.RequestMethod,
  path : String,
  headers : Map[String, String],
  body : String,
) -> ControlApiResponse {
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
        return json_response(200, status_json(gateway.status()))
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
        return json_response(200, health_summary_json(gateway.status()))
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
        return json_response(200, health_live_json(gateway.status()))
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
pub fn run_control_api_server_blocking(
  gateway : @control.Gateway,
  host : String,
  port : Int,
) -> Unit raise {
  run_control_api_server_with_tick_blocking(gateway, host, port, fn() { true })
}

///|
pub fn run_control_api_server_with_tick_blocking(
  gateway : @control.Gateway,
  host : String,
  port : Int,
  on_tick : () -> Bool,
) -> Unit raise {
  @async.with_event_loop(fn(group) {
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
