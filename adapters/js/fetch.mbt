///|
/// JavaScript外部参照型
#external
pub type JsValue

///|
/// JavaScript Promiseを表す型
#external
pub type JsPromise

///|
/// JavaScript Response を表す型
#external
pub type JsResponse

///|
/// undefined を取得
extern "js" fn js_undefined() -> JsValue =
  #|() => undefined

///|
/// null を取得
extern "js" fn _js_null() -> JsValue =
  #|() => null

///|
/// 値がundefinedかどうか
extern "js" fn js_is_undefined(value : JsValue) -> Bool =
  #|(v) => Object.is(v, undefined)

///|
/// 値がnullかどうか
extern "js" fn _js_is_null(value : JsValue) -> Bool =
  #|(v) => Object.is(v, null)

///|
/// fetch API呼び出し
extern "js" fn js_fetch(url : String, options : JsValue) -> JsPromise =
  #|(url, options) => fetch(url, options)

///|
/// Promiseのthen
extern "js" fn js_promise_then(
  promise : JsPromise,
  on_resolve : (JsValue) -> Unit,
  on_reject : (JsValue) -> Unit,
) -> Unit =
  #|(p, resolve, reject) => p.then(resolve).catch(reject)

///|
/// Responseからステータスを取得
extern "js" fn js_response_status(response : JsResponse) -> Int =
  #|(r) => r.status

///|
/// ResponseからテキストBodyを取得（Promise）
extern "js" fn js_response_text(response : JsResponse) -> JsPromise =
  #|(r) => r.text()

///|
/// ResponseからJSONBodyを取得（Promise）
extern "js" fn _js_response_json(response : JsResponse) -> JsPromise =
  #|(r) => r.json()

///|
/// Responseからヘッダーを取得
extern "js" fn _js_response_headers(response : JsResponse) -> JsValue =
  #|(r) => Object.fromEntries(r.headers.entries())

///|
/// JsValueをResponseにキャスト
fn js_value_to_response(value : JsValue) -> JsResponse = "%identity"

///|
/// JsValueをStringにキャスト
fn js_value_to_string(value : JsValue) -> String = "%identity"

///|
/// StringをJsValueにキャスト
fn _string_to_js_value(s : String) -> JsValue = "%identity"

///|
/// fetchオプションを作成
extern "js" fn js_create_fetch_options(
  http_method : String,
  headers : JsValue,
  body : JsValue,
) -> JsValue =
  #|(http_method, headers, body) => ({
  #|  method: http_method,
  #|  headers,
  #|  body: Object.is(body, undefined) ? undefined : body
  #|})

///|
/// ヘッダーオブジェクトを作成
extern "js" fn js_create_headers(pairs : Array[(String, String)]) -> JsValue =
  #|(pairs) => Object.fromEntries(pairs)

///|
/// BytesをJsValueに変換
extern "js" fn bytes_to_js_value(data : Bytes) -> JsValue =
  #|(data) => data

///|
/// JsValueをBytesに変換
extern "js" fn _js_value_to_bytes(value : JsValue) -> Bytes =
  #|(value) => {
  #|  if (value instanceof Uint8Array) return value;
  #|  if (typeof value === 'string') return new TextEncoder().encode(value);
  #|  return new Uint8Array(0);
  #|}

///|
/// コンソールログ
extern "js" fn _js_console_log(message : String) -> Unit =
  #|(msg) => console.log(msg)

///|
/// コンソールエラー
extern "js" fn _js_console_error(message : String) -> Unit =
  #|(msg) => console.error(msg)

///|
/// JSONをStringに変換
extern "js" fn _js_json_stringify(value : JsValue) -> String =
  #|(v) => JSON.stringify(v)

///|
/// StringをJSONにパース
extern "js" fn _js_json_parse(s : String) -> JsValue =
  #|(s) => JSON.parse(s)

///|
/// 現在時刻をミリ秒で取得
pub extern "js" fn js_date_now() -> Int64 =
  #|() => Date.now()

///|
/// TextEncoderでStringをBytesに変換
pub extern "js" fn js_text_encode(text : String) -> Bytes =
  #|(text) => new TextEncoder().encode(text)

///|
/// TextDecoderでBytesをStringに変換
pub extern "js" fn js_text_decode(bytes : Bytes) -> String =
  #|(bytes) => new TextDecoder().decode(bytes)
