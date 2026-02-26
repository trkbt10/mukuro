///|
/// HTTP Helpers for Model Providers
/// Common header construction and request utilities

///|
/// Build Anthropic-style headers
pub fn build_anthropic_headers(
  api_key : String,
  api_version : String,
) -> Map[String, String] {
  {
    "x-api-key": api_key,
    "anthropic-version": api_version,
    "Content-Type": "application/json",
  }
}

///|
/// Build OpenAI-style headers (Bearer token)
pub fn build_openai_headers(api_key : String) -> Map[String, String] {
  { "Authorization": "Bearer \{api_key}", "Content-Type": "application/json" }
}

///|
/// Build OpenAI headers with organization
pub fn build_openai_headers_with_org(
  api_key : String,
  organization : String,
) -> Map[String, String] {
  {
    "Authorization": "Bearer \{api_key}",
    "OpenAI-Organization": organization,
    "Content-Type": "application/json",
  }
}

///|
/// Build generic API key header (for other providers)
pub fn build_api_key_header(
  api_key : String,
  header_name : String,
) -> Map[String, String] {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  headers[header_name] = api_key
  headers
}

///|
/// Build Bearer token header
pub fn build_bearer_header(token : String) -> Map[String, String] {
  { "Authorization": "Bearer \{token}", "Content-Type": "application/json" }
}
