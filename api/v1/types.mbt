///|
/// REST API Common Types
/// API v1 共通型定義

///|
/// API Response structure
pub(all) struct ApiResponse {
  status : Int
  body : String
  headers : Map[String, String]
}

///|
/// API Error Response
pub(all) struct ApiErrorResponse {
  error : String
  message : String
  details : Map[String, Json]?
}

///|
/// API Success Response with data
pub(all) struct ApiSuccessResponse[T] {
  data : T
  meta : ApiMeta?
}

///|
/// API Response Metadata
pub(all) struct ApiMeta {
  /// Total count for paginated responses
  total : Int?
  /// Current page number
  page : Int?
  /// Items per page
  per_page : Int?
}

///|
/// API Role for authorization
pub(all) enum ApiRole {
  Admin
  Operator
  Viewer
  Anonymous
}

///|
/// Convert string to ApiRole
pub fn ApiRole::from_string(s : String) -> ApiRole {
  match s.to_lower() {
    "admin" => ApiRole::Admin
    "operator" => ApiRole::Operator
    "viewer" => ApiRole::Viewer
    _ => ApiRole::Anonymous
  }
}

///|
/// Convert ApiRole to string
pub fn ApiRole::to_string(self : ApiRole) -> String {
  match self {
    ApiRole::Admin => "admin"
    ApiRole::Operator => "operator"
    ApiRole::Viewer => "viewer"
    ApiRole::Anonymous => "anonymous"
  }
}

///|
/// API Route Action type for authorization
pub(all) enum ApiAction {
  /// Read-only operations
  Read
  /// Modify existing resources (enable/disable, update settings)
  Write
  /// Create or delete resources
  Admin
}

///|
/// Parsed API Request Context
pub(all) struct ApiRequestContext {
  /// HTTP method
  http_method : String
  /// Full path
  path : String
  /// Path segments after /api/v1/
  segments : Array[String]
  /// Query parameters
  query : Map[String, String]
  /// Request headers
  headers : Map[String, String]
  /// Request body
  body : String
  /// Authenticated role
  role : ApiRole
  /// Client ID
  client_id : String
}

///|
/// Create a new ApiRequestContext
/// Role is explicitly provided by the server after authentication,
/// NOT parsed from client headers (prevents role spoofing).
pub fn ApiRequestContext::new(
  meth~ : String,
  path~ : String,
  headers~ : Map[String, String],
  body~ : String,
  role? : ApiRole = ApiRole::Admin,
) -> ApiRequestContext {
  let segments = parse_path_segments(path)
  let query = @url.get_params(path)
  let client_id = parse_client_id_from_headers(headers)
  { http_method: meth, path, segments, query, headers, body, role, client_id }
}

///|
/// Parse path segments from /api/v1/xxx/yyy
/// Uses @url.path() to extract path before query string
fn parse_path_segments(path : String) -> Array[String] {
  let segments : Array[String] = []
  // Remove query string using @url.path()
  let path_only = @url.path(path)
  // Remove /api/v1/ prefix using char array to avoid raising slice
  let chars = path_only.to_array()
  let start = if path_only.has_prefix("/api/v1/") {
    8
  } else if path_only.has_prefix("/api/v1") {
    7
  } else {
    0
  }
  // Build trimmed string and split by /
  let mut segment = StringBuilder::new()
  for i = start; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if c == '/' {
      let s = segment.to_string()
      if s.length() > 0 {
        segments.push(s)
        segment = StringBuilder::new()
      }
    } else {
      segment.write_char(c)
    }
  }
  let last = segment.to_string()
  if last.length() > 0 {
    segments.push(last)
  }
  segments
}

///|
/// Parse client ID from headers
fn parse_client_id_from_headers(headers : Map[String, String]) -> String {
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
/// Minimal URL decode (%XX → character)
pub fn url_decode(s : String) -> String {
  let buf = StringBuilder::new()
  let chars = s.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    if chars[i] == '%' && i + 2 < len {
      let hi = hex_digit(chars[i + 1])
      let lo = hex_digit(chars[i + 2])
      match (hi, lo) {
        (Some(h), Some(l)) => {
          buf.write_char((h * 16 + l).unsafe_to_char())
          i = i + 3
          continue
        }
        _ => ()
      }
    }
    if chars[i] == '+' {
      buf.write_char(' ')
    } else {
      buf.write_char(chars[i])
    }
    i = i + 1
  }
  buf.to_string()
}

///|
fn hex_digit(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
/// Create JSON response
pub fn json_response(status : Int, body : Json) -> ApiResponse {
  let headers : Map[String, String] = {}
  headers["content-type"] = "application/json"
  { status, body: body.stringify(), headers }
}

///|
/// Create success response
pub fn[T : ToJson] success_response(status : Int, data : T) -> ApiResponse {
  json_response(status, { "data": data.to_json() })
}

///|
/// Create error response
pub fn error_response(
  status : Int,
  code : String,
  message : String,
) -> ApiResponse {
  json_response(status, { "error": code, "message": message })
}

///|
/// Create error response with details
pub fn error_response_with_details(
  status : Int,
  code : String,
  message : String,
  details : Map[String, Json],
) -> ApiResponse {
  json_response(status, {
    "error": code,
    "message": message,
    "details": Json::object(details),
  })
}

///|
/// Create paginated response
pub fn[T : ToJson] paginated_response(
  data : Array[T],
  total~ : Int,
  page~ : Int,
  per_page~ : Int,
) -> ApiResponse {
  let items : Array[Json] = []
  for item in data {
    items.push(item.to_json())
  }
  json_response(200, {
    "data": Json::array(items),
    "meta": {
      "total": total,
      "page": page,
      "per_page": per_page,
      "total_pages": (total + per_page - 1) / per_page,
    },
  })
}
