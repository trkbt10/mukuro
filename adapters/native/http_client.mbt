///|
/// Native HTTP Client 実装
/// mizchi/x の HTTP クライアントを利用する

///|
pub struct NativeHttpClient {
  timeout_seconds : Int
  user_agent : String
}

///|
pub fn NativeHttpClient::new(
  timeout_seconds~ : Int,
  user_agent~ : String,
) -> NativeHttpClient {
  { timeout_seconds, user_agent }
}

///|
pub fn NativeHttpClient::default() -> NativeHttpClient {
  { timeout_seconds: 30, user_agent: "mukuro/0.1.0" }
}

///|
fn map_http_error(err : @xhttp.HttpError) -> @interfaces.HttpError {
  match err {
    @xhttp.HttpError::InvalidUrl(url) => @interfaces.HttpError::InvalidUrl(url)
    @xhttp.HttpError::TimeoutError => @interfaces.HttpError::Timeout
    @xhttp.HttpError::NetworkError(msg) =>
      @interfaces.HttpError::ConnectionError(msg)
    @xhttp.HttpError::NotSupported =>
      @interfaces.HttpError::ConnectionError("HTTP operation is not supported")
  }
}

///|
fn method_name(http_method : @interfaces.HttpMethod) -> String {
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
fn response_from_x(
  response : @xhttp.Response,
  body_data : &@io.Data,
) -> @interfaces.HttpResponse {
  let body = Bytes::from_iter(body_data.binary().iter())
  { status: response.code, headers: response.headers, body }
}

///|
fn NativeHttpClient::request_with_x(
  self : NativeHttpClient,
  request : @interfaces.HttpRequest,
) -> @interfaces.HttpResponse raise @interfaces.HttpError {
  let mut out : @interfaces.HttpResponse? = None
  let headers : Map[String, String] = {}
  for key, value in request.headers {
    headers[key] = value
  }
  headers["User-Agent"] = self.user_agent
  // with_event_loop は native 同期コードから async HTTP を使うために利用
  @async.with_event_loop(fn(_group) {
    match request.http_method {
      @interfaces.HttpMethod::Get => {
        let (resp, body_data) = @xhttp.get(request.url, headers~) catch {
          e => raise map_http_error(e)
        }
        out = Some(response_from_x(resp, body_data))
      }
      @interfaces.HttpMethod::Post => {
        let body = request.body.unwrap_or(Bytes::new(0))
        let body_text = body.to_unchecked_string()
        let (resp, body_data) = @xhttp.post(request.url, body_text, headers~) catch {
          e => raise map_http_error(e)
        }
        out = Some(response_from_x(resp, body_data))
      }
      @interfaces.HttpMethod::Put => {
        let body = request.body.unwrap_or(Bytes::new(0))
        let body_text = body.to_unchecked_string()
        let (resp, body_data) = @xhttp.put(request.url, body_text, headers~) catch {
          e => raise map_http_error(e)
        }
        out = Some(response_from_x(resp, body_data))
      }
      _ =>
        raise @interfaces.HttpError::ConnectionError(
          "Unsupported HTTP method for NativeHttpClient: \{method_name(request.http_method)}",
        )
    }
  }) catch {
    e => raise @interfaces.HttpError::ConnectionError(e.to_string())
  }
  out.unwrap_or({ status: 500, headers: {}, body: Bytes::new(0) })
}

///|
/// Internal request implementation
pub fn NativeHttpClient::do_request(
  self : NativeHttpClient,
  request : @interfaces.HttpRequest,
) -> @interfaces.HttpResponse raise @interfaces.HttpError {
  ignore(self.timeout_seconds)
  self.request_with_x(request)
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
) -> @interfaces.HttpResponse raise @interfaces.HttpError {
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
) -> Json raise @interfaces.HttpError {
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
    _ =>
      raise @interfaces.HttpError::StatusError(
        response.status,
        "Invalid JSON response",
      )
  }
}
