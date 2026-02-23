///|
/// Native HTTP Client 実装
/// curl コマンドを使用

///|
pub(all) suberror HttpError {
  ConnectionFailed(String)
  Timeout
  InvalidUrl(String)
  StatusError(Int, String)
}

///|
pub struct NativeHttpClient {
  timeout_seconds : Int
  user_agent : String
  process : NativeProcessExecutor
}

///|
pub fn NativeHttpClient::new(
  timeout_seconds~ : Int,
  user_agent~ : String,
) -> NativeHttpClient {
  { timeout_seconds, user_agent, process: NativeProcessExecutor::default() }
}

///|
pub fn NativeHttpClient::default() -> NativeHttpClient {
  {
    timeout_seconds: 30,
    user_agent: "mukuro/0.1.0",
    process: NativeProcessExecutor::default(),
  }
}

///|
fn method_to_string(http_method : @interfaces.HttpMethod) -> String {
  match http_method {
    @interfaces.HttpMethod::Get => "GET"
    @interfaces.HttpMethod::Post => "POST"
    @interfaces.HttpMethod::Put => "PUT"
    @interfaces.HttpMethod::Delete => "DELETE"
    @interfaces.HttpMethod::Patch => "PATCH"
    @interfaces.HttpMethod::Head => "HEAD"
    @interfaces.HttpMethod::Options => "OPTIONS"
  }
}

///|
fn NativeHttpClient::build_curl_command(
  self : NativeHttpClient,
  request : @interfaces.HttpRequest,
) -> String {
  let mut cmd = "curl -s -S -w '\\n%{http_code}'"
  cmd = cmd + " --max-time \{self.timeout_seconds}"
  cmd = cmd + " -X \{method_to_string(request.http_method)}"
  cmd = cmd + " -A '\{self.user_agent}'"
  for name, value in request.headers {
    let escaped_value = escape_shell(value)
    cmd = cmd + " -H '\{name}: \{escaped_value}'"
  }
  match request.body {
    Some(body) => {
      let body_str = body.to_unchecked_string()
      let escaped_body = escape_shell(body_str)
      cmd = cmd + " -d '\{escaped_body}'"
    }
    None => ()
  }
  let escaped_url = escape_shell(request.url)
  cmd = cmd + " '\{escaped_url}'"
  cmd
}

///|
fn escape_shell(s : String) -> String {
  s.split("'").collect().join("'\\''")
}

///|
fn parse_curl_response(
  output : Bytes,
) -> @interfaces.HttpResponse raise HttpError {
  let output_str = output.to_unchecked_string()
  let lines = output_str.split("\n").collect()
  if lines.length() < 1 {
    raise HttpError::ConnectionFailed("Empty response")
  }
  let last_line = lines[lines.length() - 1].to_string()
  let parsed : Json = @json.parse(last_line) catch {
    _ => raise HttpError::ConnectionFailed("Invalid status code: \{last_line}")
  }
  let status = match parsed {
    Number(n, ..) => n.to_int()
    _ => raise HttpError::ConnectionFailed("Invalid status code: \{last_line}")
  }
  let body_lines : Array[String] = []
  for i in 0..<(lines.length() - 1) {
    body_lines.push(lines[i].to_string())
  }
  let body_str = body_lines.join("\n")
  let body = Bytes::from_iter(
    body_str.iter().map(fn(c) { c.to_int().land(0xFF).to_byte() }),
  )
  { status, headers: {}, body }
}

///|
/// Internal request implementation (avoids trait dispatch for error types)
pub fn NativeHttpClient::do_request(
  self : NativeHttpClient,
  request : @interfaces.HttpRequest,
) -> @interfaces.HttpResponse raise HttpError {
  let cmd = self.build_curl_command(request)
  let result = self.process.shell(cmd) catch {
    _ => raise HttpError::ConnectionFailed("Failed to execute curl")
  }
  if result.exit_code != 0 {
    raise HttpError::ConnectionFailed(
      "curl failed with exit code: \{result.exit_code}",
    )
  }
  parse_curl_response(result.stdout)
}

///|
pub impl @interfaces.HttpClient for NativeHttpClient with request(self, request) {
  self.do_request(request)
}

///|
pub impl @interfaces.HttpClient for NativeHttpClient with get(
  self,
  url~,
  headers~,
) {
  self.request({
    url,
    http_method: @interfaces.HttpMethod::Get,
    headers,
    body: None,
  })
}

///|
pub impl @interfaces.HttpClient for NativeHttpClient with post(
  self,
  url~,
  body~,
  headers~,
) {
  self.request({
    url,
    http_method: @interfaces.HttpMethod::Post,
    headers,
    body: Some(body),
  })
}

///|
pub fn NativeHttpClient::post_json(
  self : NativeHttpClient,
  url : String,
  json : Json,
) -> @interfaces.HttpResponse raise HttpError {
  let headers : Map[String, String] = {}
  headers["Content-Type"] = "application/json"
  let body = Bytes::from_iter(
    json.stringify().iter().map(fn(c) { c.to_int().land(0xFF).to_byte() }),
  )
  self.do_request({
    url,
    http_method: @interfaces.HttpMethod::Post,
    headers,
    body: Some(body),
  })
}

///|
pub fn NativeHttpClient::get_json(
  self : NativeHttpClient,
  url : String,
) -> Json raise HttpError {
  let headers : Map[String, String] = {}
  headers["Accept"] = "application/json"
  let response = self.do_request({
    url,
    http_method: @interfaces.HttpMethod::Get,
    headers,
    body: None,
  })
  let body_str = response.body.to_unchecked_string()
  @json.parse(body_str) catch {
    _ => raise HttpError::StatusError(response.status, "Invalid JSON response")
  }
}
