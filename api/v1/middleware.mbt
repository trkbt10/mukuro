///|
/// REST API Middleware
/// Authentication, Authorization, and Request Validation

///|
/// Maximum request body size (1MB)
let max_body_size : Int = 1048576

///|
/// Middleware: Validate request body size
/// Returns None if within limit, Some(ApiResponse) if too large
pub fn validate_body_size(body : String) -> ApiResponse? {
  if body.length() > max_body_size {
    Some(
      error_response(
        413, "payload_too_large", "Request body exceeds maximum size of 1MB",
      ),
    )
  } else {
    None
  }
}

///|
/// Check if action is allowed for role
pub fn is_action_allowed(role : ApiRole, action : ApiAction) -> Bool {
  match role {
    ApiRole::Admin => true
    ApiRole::Operator =>
      match action {
        ApiAction::Read => true
        ApiAction::Write => true
        ApiAction::Admin => false
      }
    ApiRole::Viewer =>
      match action {
        ApiAction::Read => true
        ApiAction::Write => false
        ApiAction::Admin => false
      }
    ApiRole::Anonymous => false
  }
}

///|
/// Determine required action for endpoint
pub fn get_required_action(
  meth : String,
  segments : Array[String],
) -> ApiAction {
  // POST/PUT/DELETE require at least Write
  // Some POST endpoints (create) require Admin
  match meth.to_upper() {
    "GET" | "HEAD" | "OPTIONS" => ApiAction::Read
    "POST" =>
      // Check if it's a creation or action endpoint
      if segments.length() > 0 {
        let last = segments[segments.length() - 1]
        // Actions like reload, enable, disable are Write
        if last == "reload" || last == "enable" || last == "disable" {
          ApiAction::Write
        } else if last == "upload" {
          // Upload is Admin
          ApiAction::Admin
        } else {
          // Creation is Admin
          ApiAction::Admin
        }
      } else {
        ApiAction::Admin
      }
    "PUT" | "PATCH" => ApiAction::Write
    "DELETE" => ApiAction::Admin
    _ => ApiAction::Admin
  }
}

///|
/// Middleware: Validate authorization
/// Returns None if authorized, Some(ApiResponse) if not authorized
pub fn validate_authorization(ctx : ApiRequestContext) -> ApiResponse? {
  let action = get_required_action(ctx.http_method, ctx.segments)
  if is_action_allowed(ctx.role, action) {
    None
  } else {
    Some(
      error_response(
        403,
        "forbidden",
        "Role '\{ctx.role.to_string()}' is not allowed for this operation",
      ),
    )
  }
}

///|
/// Middleware: Validate JSON body
pub fn validate_json_body(body : String) -> Result[Json, ApiResponse] {
  if body.length() == 0 {
    return Ok(Json::null())
  }
  let parsed : Json = @json.parse(body) catch {
    _ =>
      return Err(
        error_response(400, "invalid_json", "Request body is not valid JSON"),
      )
  }
  Ok(parsed)
}

///|
/// Middleware: Require non-empty JSON object body
pub fn require_json_object(
  body : String,
) -> Result[Map[String, Json], ApiResponse] {
  if body.length() == 0 {
    return Err(error_response(400, "missing_body", "Request body is required"))
  }
  let parsed = validate_json_body(body)
  match parsed {
    Err(resp) => Err(resp)
    Ok(json) =>
      match json {
        Object(obj) => Ok(obj)
        _ =>
          Err(
            error_response(
              400, "invalid_body", "Request body must be a JSON object",
            ),
          )
      }
  }
}

///|
/// Middleware: Extract required string field from JSON
pub fn require_string_field(
  obj : Map[String, Json],
  field : String,
) -> Result[String, ApiResponse] {
  match obj.get(field) {
    Some(String(v)) => Ok(v)
    Some(_) =>
      Err(
        error_response(
          400,
          "invalid_field",
          "Field '\{field}' must be a string",
        ),
      )
    None =>
      Err(error_response(400, "missing_field", "Field '\{field}' is required"))
  }
}

///|
/// Middleware: Extract optional string field from JSON
pub fn get_optional_string_field(
  obj : Map[String, Json],
  field : String,
) -> String? {
  match obj.get(field) {
    Some(String(v)) => Some(v)
    _ => None
  }
}

///|
/// Middleware: Extract required int field from JSON
pub fn require_int_field(
  obj : Map[String, Json],
  field : String,
) -> Result[Int, ApiResponse] {
  match obj.get(field) {
    Some(Number(v, ..)) => Ok(v.to_int())
    Some(_) =>
      Err(
        error_response(
          400,
          "invalid_field",
          "Field '\{field}' must be a number",
        ),
      )
    None =>
      Err(error_response(400, "missing_field", "Field '\{field}' is required"))
  }
}

///|
/// Middleware: Extract optional int field from JSON
pub fn get_optional_int_field(obj : Map[String, Json], field : String) -> Int? {
  match obj.get(field) {
    Some(Number(v, ..)) => Some(v.to_int())
    _ => None
  }
}

///|
/// Middleware: Extract required bool field from JSON
pub fn require_bool_field(
  obj : Map[String, Json],
  field : String,
) -> Result[Bool, ApiResponse] {
  match obj.get(field) {
    Some(True) => Ok(true)
    Some(False) => Ok(false)
    Some(_) =>
      Err(
        error_response(
          400,
          "invalid_field",
          "Field '\{field}' must be a boolean",
        ),
      )
    None =>
      Err(error_response(400, "missing_field", "Field '\{field}' is required"))
  }
}

///|
/// Middleware: Extract optional bool field from JSON
pub fn get_optional_bool_field(
  obj : Map[String, Json],
  field : String,
) -> Bool? {
  match obj.get(field) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
/// Middleware: Extract bearer token from Authorization header
pub fn extract_bearer_token(headers : Map[String, String]) -> String? {
  let raw = match headers.get("authorization") {
    Some(v) => v
    None =>
      match headers.get("Authorization") {
        Some(v) => v
        None => return None
      }
  }
  @interfaces.extract_bearer_token(raw)
}

///|
/// Middleware: Validate content type is JSON
pub fn validate_json_content_type(
  headers : Map[String, String],
) -> ApiResponse? {
  let content_type = match headers.get("content-type") {
    Some(v) => v
    None =>
      match headers.get("Content-Type") {
        Some(v) => v
        None => ""
      }
  }
  // Accept if content-type starts with application/json or is empty
  if content_type.length() == 0 || content_type.has_prefix("application/json") {
    None
  } else {
    Some(
      error_response(
        415, "unsupported_media_type", "Content-Type must be application/json",
      ),
    )
  }
}

///|
/// Middleware: Rate limiting state
pub(all) struct RateLimitState {
  /// Request counts per client
  mut counts : Map[String, Int]
  /// Window start time per client
  mut window_start : Map[String, Int64]
  /// Max requests per window
  max_requests : Int
  /// Window duration in seconds
  window_seconds : Int64
}

///|
/// Create new rate limit state
pub fn RateLimitState::new(
  max_requests~ : Int,
  window_seconds~ : Int64,
) -> RateLimitState {
  { counts: {}, window_start: {}, max_requests, window_seconds }
}

///|
/// Default rate limit (100 requests per minute)
pub fn RateLimitState::default() -> RateLimitState {
  RateLimitState::new(max_requests=100, window_seconds=60L)
}
