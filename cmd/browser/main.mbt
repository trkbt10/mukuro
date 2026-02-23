///|
/// mukuro Browser Entry Point
/// ブラウザ向けデモ用エントリーポイント

///|
/// DOM要素型
#external
type JsElement

///|
/// DOM要素を取得
extern "js" fn js_get_element(id : String) -> JsElement? =
  #|(id) => document.getElementById(id)

///|
/// 要素の値を取得
extern "js" fn _js_get_value(element : JsElement) -> String =
  #|(el) => el.value || ''

///|
/// 要素の値を設定
extern "js" fn js_set_value(element : JsElement, value : String) -> Unit =
  #|(el, value) => { el.value = value; }

///|
/// 要素のinnerHTMLを設定
extern "js" fn js_set_html(element : JsElement, html : String) -> Unit =
  #|(el, html) => { el.innerHTML = html; }

///|
/// 要素にHTMLを追加
extern "js" fn js_append_html(element : JsElement, html : String) -> Unit =
  #|(el, html) => { el.innerHTML += html; }

///|
/// 要素を下にスクロール
extern "js" fn js_scroll_to_bottom(element : JsElement) -> Unit =
  #|(el) => { el.scrollTop = el.scrollHeight; }

///|
/// コンソールログ
extern "js" fn browser_log(message : String) -> Unit =
  #|(message) => console.log('[mukuro]', message)

///|
/// コンソールエラー
extern "js" fn browser_error(message : String) -> Unit =
  #|(message) => console.error('[mukuro]', message)

///|
/// グローバル設定
struct BrowserConfig {
  mut api_key : String
  mut system_prompt : String
  mut initialized : Bool
}

///|
let browser_config : BrowserConfig = {
  api_key: "",
  system_prompt: "You are a helpful AI assistant.",
  initialized: false,
}

///|
/// セッション履歴
let browser_history : Array[Json] = []

///|
/// ブラウザ向けエージェント初期化
pub fn browser_init(api_key : String, system_prompt : String) -> Bool {
  browser_config.api_key = api_key
  browser_config.system_prompt = system_prompt
  browser_config.initialized = true
  browser_log("Agent initialized")
  true
}

///|
/// チャットメッセージを送信
pub fn browser_send_message(content : String) -> Unit {
  if not(browser_config.initialized) {
    browser_error("Agent not initialized")
    return
  }
  // チャットログに送信メッセージを追加
  let chat_log = match js_get_element("chat-log") {
    Some(el) => el
    None => {
      browser_error("chat-log element not found")
      return
    }
  }
  let escaped_content = escape_html(content)
  js_append_html(
    chat_log,
    "<div class=\"message user\"><strong>You:</strong> \{escaped_content}</div>",
  )
  js_scroll_to_bottom(chat_log)
  // 入力欄をクリア
  match js_get_element("message-input") {
    Some(el) => js_set_value(el, "")
    None => ()
  }
  // 履歴にユーザーメッセージを追加
  browser_history.push({ "role": "user", "content": content })
  // メッセージ配列を構築
  let messages : Array[Json] = [
    { "role": "system", "content": browser_config.system_prompt },
  ]
  for msg in browser_history {
    messages.push(msg)
  }
  // API呼び出し
  call_anthropic_browser(
    browser_config.api_key,
    messages,
    fn(response) {
      // 履歴にアシスタント応答を追加
      browser_history.push({ "role": "assistant", "content": response })
      // 応答を表示
      let escaped_response = escape_html(response)
      js_append_html(
        chat_log,
        "<div class=\"message assistant\"><strong>Assistant:</strong> \{escaped_response}</div>",
      )
      js_scroll_to_bottom(chat_log)
    },
    fn(error) {
      // エラーを表示
      let escaped_error = escape_html(error)
      js_append_html(
        chat_log,
        "<div class=\"message error\"><strong>Error:</strong> \{escaped_error}</div>",
      )
      js_scroll_to_bottom(chat_log)
      browser_error(error)
    },
  )
}

///|
/// Anthropic API呼び出し（ブラウザ版）
fn call_anthropic_browser(
  api_key : String,
  messages : Array[Json],
  on_success : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  // システムメッセージを分離
  let mut system_content = ""
  let api_messages : Array[Json] = []
  for msg in messages {
    match msg {
      { "role": String(role), "content": String(content), .. } =>
        if role == "system" {
          system_content = content
        } else {
          api_messages.push(msg)
        }
      _ => ()
    }
  }
  let request_body : Json = {
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 4096,
    "system": system_content,
    "messages": Json::array(api_messages),
  }
  let headers : Map[String, String] = {}
  headers["x-api-key"] = api_key
  headers["anthropic-version"] = "2023-06-01"
  headers["content-type"] = "application/json"
  @js.fetch_with_callback(
    "https://api.anthropic.com/v1/messages",
    "POST",
    headers,
    Some(@js.js_text_encode(request_body.stringify())),
    fn(response) {
      if response.status >= 200 && response.status < 300 {
        let body_str = response.body.to_unchecked_string()
        let result = @json.parse(body_str) catch {
          _ => {
            on_error("Failed to parse response")
            return
          }
        }
        // 応答テキストを抽出
        let text = extract_text(result)
        on_success(text)
      } else {
        let body_str = response.body.to_unchecked_string()
        on_error("API error \{response.status}: \{body_str}")
      }
    },
    fn(error) { on_error("Request failed: \{error}") },
  )
}

///|
/// レスポンスからテキストを抽出
fn extract_text(response : Json) -> String {
  match response {
    { "content": Array(contents), .. } =>
      for content in contents {
        match content {
          { "type": String("text"), "text": String(text), .. } => return text
          _ => ()
        }
      }
    _ => ()
  }
  "[No response text]"
}

///|
/// セッションをクリア
pub fn browser_clear_session() -> Unit {
  browser_history.clear()
  match js_get_element("chat-log") {
    Some(el) =>
      js_set_html(
        el, "<div class=\"message system\">Session cleared. Start a new conversation.</div>",
      )
    None => ()
  }
  browser_log("Session cleared")
}

///|
/// HTMLエスケープ
fn escape_html(text : String) -> String {
  let mut result = text
  result = result.replace_string("&", "&amp;")
  result = result.replace_string("<", "&lt;")
  result = result.replace_string(">", "&gt;")
  result = result.replace_string("\"", "&quot;")
  result
}

///|
/// String::replace_string ヘルパー
fn String::replace_string(self : String, from : String, to : String) -> String {
  let parts = self.split(from).collect()
  parts.join(to)
}

///|
/// メイン関数
fn main {
  browser_log("mukuro browser module loaded")
  // グローバルに関数を公開
  js_expose_functions()
}

///|
/// JavaScript グローバルに関数を公開
extern "js" fn js_expose_functions() -> Unit =
  #|() => {
  #|  window.mukuro = {
  #|    init: (apiKey, systemPrompt) => {
  #|      const mod = globalThis._moonbit_module;
  #|      if (mod && mod.browser_init) {
  #|        return mod.browser_init(apiKey, systemPrompt || 'You are a helpful assistant.');
  #|      }
  #|      console.error('MoonBit module not loaded');
  #|      return false;
  #|    },
  #|    send: (message) => {
  #|      const mod = globalThis._moonbit_module;
  #|      if (mod && mod.browser_send_message) {
  #|        mod.browser_send_message(message);
  #|      }
  #|    },
  #|    clear: () => {
  #|      const mod = globalThis._moonbit_module;
  #|      if (mod && mod.browser_clear_session) {
  #|        mod.browser_clear_session();
  #|      }
  #|    }
  #|  };
  #|  console.log('[mukuro] API exposed as window.mukuro');
  #|}
