///|
/// mukuro WASM Entry Point
/// Web/Node.js両対応のWASMモジュール

///|
/// グローバル設定
struct GlobalConfig {
  mut api_key : String
  mut provider : String
  mut system_prompt : String
  mut initialized : Bool
}

///|
let global_config : GlobalConfig = {
  api_key: "",
  provider: "anthropic",
  system_prompt: "You are a helpful assistant.",
  initialized: false,
}

///|
/// シンプルなインメモリセッションストア
struct SimpleSessionStore {
  sessions : Map[String, Array[Json]]
}

///|
let session_store : SimpleSessionStore = { sessions: {} }

///|
/// 初期化（JavaScript から呼び出し）
pub fn init_agent(
  api_key : String,
  provider : String,
  system_prompt : String,
) -> Bool {
  global_config.api_key = api_key
  global_config.provider = provider
  global_config.system_prompt = system_prompt
  global_config.initialized = true
  js_console_log("Agent initialized with provider: \{provider}")
  true
}

///|
/// メッセージを処理（JavaScript から呼び出し）
pub fn process_message(
  channel : String,
  chat_id : String,
  _sender_id : String,
  content : String,
  on_response : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  if not(global_config.initialized) {
    on_error("Agent not initialized. Call init_agent first.")
    return
  }
  // セッションキーを生成
  let session_key = "\{channel}:\{chat_id}"
  // セッション履歴を取得または作成
  let history = match session_store.sessions.get(session_key) {
    Some(h) => h
    None => {
      let h : Array[Json] = []
      session_store.sessions[session_key] = h
      h
    }
  }
  // ユーザーメッセージを履歴に追加
  history.push({ "role": "user", "content": content })
  // メッセージ配列を構築
  let messages : Array[Json] = [
    { "role": "system", "content": global_config.system_prompt },
  ]
  for msg in history {
    messages.push(msg)
  }
  // ツール定義を取得
  let tools = @tools.all_tool_definitions()
  let tools_json : Array[Json] = tools.map(fn(tool) {
    {
      "name": tool.name,
      "description": tool.description,
      "input_schema": tool.parameters,
    }
  })
  // モデルを呼び出し
  call_model(
    global_config.api_key,
    global_config.provider,
    messages,
    tools_json,
    fn(response) {
      // アシスタントの応答を履歴に追加
      history.push({ "role": "assistant", "content": response })
      // レスポンスJSONを生成
      let result : Json = {
        "channel": channel,
        "chat_id": chat_id,
        "content": response,
      }
      on_response(result.stringify())
    },
    on_error,
  )
}

///|
/// モデル呼び出し
fn call_model(
  api_key : String,
  provider : String,
  messages : Array[Json],
  tools : Array[Json],
  on_success : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  match provider {
    "anthropic" =>
      call_anthropic(api_key, messages, tools, on_success, on_error)
    "openai" => call_openai(api_key, messages, tools, on_success, on_error)
    _ => call_anthropic(api_key, messages, tools, on_success, on_error)
  }
}

///|
/// Anthropic API呼び出し
fn call_anthropic(
  api_key : String,
  messages : Array[Json],
  tools : Array[Json],
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
  // リクエストボディを構築
  let request_body : Json = {
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 4096,
    "system": system_content,
    "messages": Json::array(api_messages),
    "tools": Json::array(tools),
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
        let text = extract_anthropic_text(result)
        on_success(text)
      } else {
        on_error("API error: \{response.status}")
      }
    },
    fn(error) { on_error("Request failed: \{error}") },
  )
}

///|
/// Anthropicレスポンスからテキストを抽出
fn extract_anthropic_text(response : Json) -> String {
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
/// OpenAI API呼び出し（スタブ）
fn call_openai(
  api_key : String,
  messages : Array[Json],
  tools : Array[Json],
  on_success : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  // OpenAI形式でツールを変換
  let openai_tools : Array[Json] = tools.map(fn(tool) {
    match tool {
      { "name": name, "description": description, "input_schema": schema, .. } =>
        {
          "type": "function",
          "function": {
            "name": name,
            "description": description,
            "parameters": schema,
          },
        }
      _ => tool
    }
  })
  let request_body : Json = {
    "model": "gpt-4o",
    "messages": Json::array(messages),
    "tools": Json::array(openai_tools),
  }
  let headers : Map[String, String] = {}
  headers["Authorization"] = "Bearer \{api_key}"
  headers["Content-Type"] = "application/json"
  @js.fetch_with_callback(
    "https://api.openai.com/v1/chat/completions",
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
        let text = extract_openai_text(result)
        on_success(text)
      } else {
        on_error("API error: \{response.status}")
      }
    },
    fn(error) { on_error("Request failed: \{error}") },
  )
}

///|
/// OpenAIレスポンスからテキストを抽出
fn extract_openai_text(response : Json) -> String {
  match response {
    { "choices": Array(choices), .. } =>
      match choices[0] {
        { "message": { "content": String(text), .. }, .. } => text
        _ => "[No response text]"
      }
    _ => "[No response text]"
  }
}

///|
/// セッションをクリア
pub fn clear_session(channel : String, chat_id : String) -> Bool {
  let session_key = "\{channel}:\{chat_id}"
  match session_store.sessions.get(session_key) {
    Some(_) => {
      session_store.sessions.remove(session_key)
      true
    }
    None => false
  }
}

///|
/// ツール一覧を取得
pub fn get_available_tools() -> String {
  let tools = @tools.all_tool_definitions()
  let tool_list : Array[Json] = tools.map(fn(tool) {
    { "name": tool.name, "description": tool.description }
  })
  Json::array(tool_list).stringify()
}

///|
/// ヘルスチェック
pub fn health_check() -> String {
  let status = if global_config.initialized {
    "ready"
  } else {
    "not_initialized"
  }
  let result : Json = {
    "status": status,
    "version": "0.1.0",
    "provider": global_config.provider,
    "timestamp": @js.js_date_now().to_int(),
  }
  result.stringify()
}

///|
/// メイン関数
fn main {
  js_console_log("mukuro WASM module loaded")
}

///|
/// コンソールログ
extern "js" fn js_console_log(message : String) -> Unit =
  #|(message) => console.log('[mukuro]', message)
