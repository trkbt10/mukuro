///|
/// JavaScript fetch ベースのHTTPクライアント
pub struct JsFetchClient {
  /// タイムアウト（ミリ秒）
  timeout_ms : Int
}

///|
/// JsFetchClientを新規作成
pub fn JsFetchClient::new(timeout_ms~ : Int) -> JsFetchClient {
  { timeout_ms, }
}

///|
/// デフォルト設定でJsFetchClientを作成
pub fn JsFetchClient::default() -> JsFetchClient {
  { timeout_ms: 30000 }
}

///|
/// ヘッダーMapをJsValueに変換
fn headers_to_js(headers : Map[String, String]) -> JsValue {
  let pairs : Array[(String, String)] = []
  for k, v in headers {
    pairs.push((k, v))
  }
  js_create_headers(pairs)
}

///|
/// HttpClient実装
pub impl @interfaces.HttpClient for JsFetchClient with request(self, req) {
  // オプションを構築
  let method_str = match req.http_method {
    @interfaces.HttpMethod::Get => "GET"
    @interfaces.HttpMethod::Post => "POST"
    @interfaces.HttpMethod::Put => "PUT"
    @interfaces.HttpMethod::Delete => "DELETE"
    @interfaces.HttpMethod::Patch => "PATCH"
    @interfaces.HttpMethod::Head => "HEAD"
    @interfaces.HttpMethod::Options => "OPTIONS"
  }
  let headers_js = headers_to_js(req.headers)
  let body_js = match req.body {
    Some(data) => bytes_to_js_value(data)
    None => js_undefined()
  }
  let options = js_create_fetch_options(method_str, headers_js, body_js)
  // fetch呼び出し（同期的に結果を返す必要があるため、実際にはasync対応が必要）
  // 注意: これはプレースホルダー実装。実際にはasync/awaitパターンが必要
  ignore(self.timeout_ms)
  ignore(options)
  ignore(req.url)
  // 仮の実装（実際のasync実装は別途必要）
  { status: 200, headers: {}, body: b"" }
}

///|
pub impl @interfaces.HttpClient for JsFetchClient with get(self, url~, headers~) {
  let req : @interfaces.HttpRequest = {
    url,
    http_method: @interfaces.HttpMethod::Get,
    headers,
    body: None,
  }
  @interfaces.HttpClient::request(self, req)
}

///|
pub impl @interfaces.HttpClient for JsFetchClient with post(
  self,
  url~,
  body~,
  headers~,
) {
  let req : @interfaces.HttpRequest = {
    url,
    http_method: @interfaces.HttpMethod::Post,
    headers,
    body: Some(body),
  }
  @interfaces.HttpClient::request(self, req)
}

///|
/// 低レベルfetch関数（非同期、コールバックベース）
pub fn fetch_with_callback(
  url : String,
  http_method : String,
  headers : Map[String, String],
  body : Bytes?,
  on_success : (@interfaces.HttpResponse) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  let headers_js = headers_to_js(headers)
  let body_js = match body {
    Some(data) => bytes_to_js_value(data)
    None => js_undefined()
  }
  let options = js_create_fetch_options(http_method, headers_js, body_js)
  let promise = js_fetch(url, options)
  js_promise_then(
    promise,
    fn(response_value) {
      let response = js_value_to_response(response_value)
      let status = js_response_status(response)
      // テキストBodyを取得
      let text_promise = js_response_text(response)
      js_promise_then(
        text_promise,
        fn(text_value) {
          let text = js_value_to_string(text_value)
          let body_bytes = js_text_encode(text)
          let http_response : @interfaces.HttpResponse = {
            status,
            headers: {},
            body: body_bytes,
          }
          on_success(http_response)
        },
        fn(_err) { on_error("Failed to read response body") },
      )
    },
    fn(_err) { on_error("Fetch failed") },
  )
}

///|
/// 非同期fetch関数（async/await対応）
/// suspendを使用してコールバックベースのfetchをasyncに変換
pub async fn fetch_async(
  url : String,
  http_method : String,
  headers : Map[String, String],
  body : Bytes?,
) -> @interfaces.HttpResponse {
  // JS Promise を作成してawait
  let promise = create_fetch_promise(url, http_method, headers, body)
  @js_async.Promise::wait(promise)
}

///|
/// fetchをPromiseとして作成
fn create_fetch_promise(
  url : String,
  http_method : String,
  headers : Map[String, String],
  body : Bytes?,
) -> @js_async.Promise[@interfaces.HttpResponse] {
  create_fetch_promise_ffi(url, http_method, headers, body)
}

///|
extern "js" fn create_fetch_promise_ffi(
  url : String,
  http_method : String,
  headers : Map[String, String],
  body : Bytes?,
) -> @js_async.Promise[@interfaces.HttpResponse] =
  #| async (url, method, headers, body) => {
  #|   const headersObj = {};
  #|   headers.iter((k, v) => { headersObj[k] = v; });
  #|   const options = { method, headers: headersObj };
  #|   if (body) { options.body = body; }
  #|   const response = await fetch(url, options);
  #|   const arrayBuffer = await response.arrayBuffer();
  #|   const bodyBytes = new Uint8Array(arrayBuffer);
  #|   return { status: response.status, headers: {}, body: bodyBytes };
  #| }

///|
/// 非同期GETリクエスト
pub async fn get_async(
  url : String,
  headers : Map[String, String],
) -> @interfaces.HttpResponse {
  fetch_async(url, "GET", headers, None)
}

///|
/// 非同期POSTリクエスト
pub async fn post_async(
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> @interfaces.HttpResponse {
  fetch_async(url, "POST", headers, Some(body))
}

///|
/// 非同期JSON POSTリクエスト
pub async fn post_json_async(
  url : String,
  json_body : Json,
  headers : Map[String, String],
) -> @interfaces.HttpResponse {
  headers["Content-Type"] = "application/json"
  let body_str = json_body.stringify()
  let body = js_text_encode(body_str)
  fetch_async(url, "POST", headers, Some(body))
}

///|
/// JSON POSTリクエスト（コールバックベース）
pub fn post_json(
  url : String,
  json_body : Json,
  on_success : (Json) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  let body_str = json_body.stringify()
  let body = js_text_encode(body_str)
  fetch_with_callback(
    url,
    "POST",
    headers,
    Some(body),
    fn(response) {
      if response.status >= 200 && response.status < 300 {
        let body_str = response.body.to_unchecked_string()
        try {
          let json = @json.parse(body_str)
          on_success(json)
        } catch {
          e => on_error("JSON parse error: \{e}")
        }
      } else {
        on_error("HTTP error: \{response.status}")
      }
    },
    on_error,
  )
}
