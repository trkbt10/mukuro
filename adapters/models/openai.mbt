///|
/// OpenAI プロバイダ設定
pub(all) struct OpenAIConfig {
  /// APIキー
  api_key : String
  /// ベースURL
  base_url : String
  /// 組織ID（オプション）
  organization : String?
  /// タイムアウト（ミリ秒）
  timeout_ms : Int
}

///|
/// デフォルト設定
pub fn OpenAIConfig::default(api_key~ : String) -> OpenAIConfig {
  {
    api_key,
    base_url: "https://api.openai.com",
    organization: None,
    timeout_ms: 60000,
  }
}

///|
/// OpenAI プロバイダ
pub struct OpenAIProvider {
  config : OpenAIConfig
}

///|
/// OpenAIProviderを新規作成
pub fn OpenAIProvider::new(config : OpenAIConfig) -> OpenAIProvider {
  { config, }
}

///|
/// APIキーから簡易作成
pub fn OpenAIProvider::from_api_key(api_key : String) -> OpenAIProvider {
  { config: OpenAIConfig::default(api_key~) }
}

///|
/// ModelProvider実装
pub impl @interfaces.ModelProvider for OpenAIProvider with name(_self) {
  "openai"
}

///|
pub impl @interfaces.ModelProvider for OpenAIProvider with is_available(self) {
  self.config.api_key.length() > 0
}

///|
pub impl @interfaces.ModelProvider for OpenAIProvider with invoke(
  self,
  messages~,
  tools~,
  options~,
) {
  // プレースホルダー実装（同期HTTPはJSでサポートされない）
  ignore(messages)
  ignore(tools)
  ignore(options)
  ignore(self)
  @types.ModelResponse::ModelError("Synchronous HTTP not supported in JS")
}

///|
/// リクエストボディを構築
pub fn OpenAIProvider::build_request(
  self : OpenAIProvider,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  options : @types.ModelOptions,
) -> Json {
  // メッセージをJSON形式に変換
  let messages_json : Array[Json] = []
  for msg in messages {
    messages_json.push(message_to_openai_json(msg))
  }
  // ツールをJSON形式に変換
  let tools_json : Array[Json] = []
  for tool in tools {
    tools_json.push(tool_to_openai_json(tool))
  }
  // リクエストボディを構築
  let mut body : Json = {
    "model": options.model_name,
    "messages": Json::array(messages_json),
  }
  // max_tokensを追加
  match options.max_tokens {
    Some(max) =>
      body = body.set_field("max_tokens", Json::number(max.to_double()))
    None => ()
  }
  // temperatureを追加
  match options.temperature {
    Some(temp) => body = body.set_field("temperature", Json::number(temp))
    None => ()
  }
  // ツールを追加
  if tools.length() > 0 {
    body = body.set_field("tools", Json::array(tools_json))
  }
  ignore(self.config)
  body
}

///|
/// OpenAIレスポンスをパース
pub fn parse_openai_response(response_json : Json) -> @types.ModelResponse {
  match response_json {
    { "choices": Array(choices), .. } => {
      if choices.length() == 0 {
        return @types.ModelResponse::ModelError("No choices in response")
      }
      let choice = choices[0]
      match choice {
        { "message": message, "finish_reason": String(finish_reason), .. } => {
          // ツール呼び出しをチェック
          if finish_reason == "tool_calls" {
            match message {
              { "tool_calls": tool_calls, .. } => {
                let calls = parse_openai_tool_calls(tool_calls)
                if calls.length() > 0 {
                  return @types.ModelResponse::ToolCalls(calls)
                }
              }
              _ => ()
            }
          }
          // テキスト応答を抽出
          match message {
            { "content": String(content), .. } =>
              @types.ModelResponse::Text(content)
            { "content": Null, "tool_calls": tool_calls, .. } => {
              let calls = parse_openai_tool_calls(tool_calls)
              if calls.length() > 0 {
                @types.ModelResponse::ToolCalls(calls)
              } else {
                @types.ModelResponse::Text("")
              }
            }
            _ => @types.ModelResponse::ModelError("Invalid message format")
          }
        }
        _ => @types.ModelResponse::ModelError("Invalid choice format")
      }
    }
    { "error": { "message": String(msg), .. }, .. } =>
      @types.ModelResponse::ModelError(msg)
    _ => @types.ModelResponse::ModelError("Unknown response format")
  }
}

///|
/// 非同期でOpenAIを呼び出す（async/await版）
pub async fn invoke_openai_async(
  provider : OpenAIProvider,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  options : @types.ModelOptions,
) -> @types.ModelResponse {
  let request_body = provider.build_request(messages, tools, options)
  let url = "\{provider.config.base_url}/v1/chat/completions"
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "Authorization": "Bearer \{provider.config.api_key}",
  }
  // 組織IDを追加
  match provider.config.organization {
    Some(org) => headers["OpenAI-Organization"] = org
    None => ()
  }
  let body = @js.js_text_encode(request_body.stringify())
  let response = @js.fetch_async(url, "POST", headers, Some(body))
  if response.status >= 200 && response.status < 300 {
    let body_str = response.body.to_unchecked_string()
    try {
      let json = @json.parse(body_str)
      parse_openai_response(json)
    } catch {
      e => @types.ModelResponse::ModelError("JSON parse error: \{e}")
    }
  } else if response.status == 429 {
    @types.ModelResponse::RateLimited(retry_after=60)
  } else {
    let body_str = response.body.to_unchecked_string()
    @types.ModelResponse::ModelError("API error \{response.status}: \{body_str}")
  }
}

///|
/// 非同期でOpenAIを呼び出す（コールバックベース）
pub fn call_openai_async(
  provider : OpenAIProvider,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  options : @types.ModelOptions,
  on_success : (@types.ModelResponse) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  let request_body = provider.build_request(messages, tools, options)
  let url = "\{provider.config.base_url}/v1/chat/completions"
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "Authorization": "Bearer \{provider.config.api_key}",
  }
  // 組織IDを追加
  match provider.config.organization {
    Some(org) => headers["OpenAI-Organization"] = org
    None => ()
  }
  let body = @js.js_text_encode(request_body.stringify())
  @js.fetch_with_callback(
    url,
    "POST",
    headers,
    Some(body),
    fn(response) {
      if response.status >= 200 && response.status < 300 {
        let body_str = response.body.to_unchecked_string()
        try {
          let json = @json.parse(body_str)
          on_success(parse_openai_response(json))
        } catch {
          e => on_error("JSON parse error: \{e}")
        }
      } else if response.status == 429 {
        on_success(@types.ModelResponse::RateLimited(retry_after=60))
      } else {
        let body_str = response.body.to_unchecked_string()
        on_error("API error \{response.status}: \{body_str}")
      }
    },
    on_error,
  )
}
