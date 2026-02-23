///|
/// Anthropic Claude プロバイダ設定
pub(all) struct AnthropicConfig {
  /// APIキー
  api_key : String
  /// ベースURL
  base_url : String
  /// APIバージョン
  api_version : String
  /// タイムアウト（ミリ秒）
  timeout_ms : Int
}

///|
/// デフォルト設定
pub fn AnthropicConfig::default(api_key~ : String) -> AnthropicConfig {
  {
    api_key,
    base_url: "https://api.anthropic.com",
    api_version: "2023-06-01",
    timeout_ms: 60000,
  }
}

///|
/// Anthropic Claude プロバイダ
pub struct AnthropicProvider {
  config : AnthropicConfig
}

///|
/// AnthropicProviderを新規作成
pub fn AnthropicProvider::new(config : AnthropicConfig) -> AnthropicProvider {
  { config, }
}

///|
/// APIキーから簡易作成
pub fn AnthropicProvider::from_api_key(api_key : String) -> AnthropicProvider {
  { config: AnthropicConfig::default(api_key~) }
}

///|
/// ModelProvider実装
pub impl @interfaces.ModelProvider for AnthropicProvider with name(_self) {
  "anthropic"
}

///|
pub impl @interfaces.ModelProvider for AnthropicProvider with is_available(self) {
  self.config.api_key.length() > 0
}

///|
pub impl @interfaces.ModelProvider for AnthropicProvider with invoke(
  self,
  messages~,
  tools~,
  options~,
) {
  // リクエストボディを構築
  let request_body = self.build_request(messages, tools, options)
  // 注意: 同期的なHTTP呼び出しはJavaScriptでは直接サポートされないため、
  // 実際にはコールバックベースまたはasync実装が必要
  // これはプレースホルダー実装
  ignore(request_body)
  @types.ModelResponse::ModelError("Synchronous HTTP not supported in JS")
}

///|
/// リクエストボディを構築
pub fn AnthropicProvider::build_request(
  self : AnthropicProvider,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  options : @types.ModelOptions,
) -> Json {
  // システムメッセージを分離
  let system_message = extract_system_message(messages)
  let non_system_messages = filter_non_system_messages(messages)
  // メッセージをJSON形式に変換
  let messages_json : Array[Json] = []
  for msg in non_system_messages {
    messages_json.push(message_to_anthropic_json(msg))
  }
  // ツールをJSON形式に変換
  let tools_json : Array[Json] = []
  for tool in tools {
    tools_json.push(tool_to_anthropic_json(tool))
  }
  // リクエストボディを構築
  let mut body : Json = {
    "model": options.model_name,
    "messages": Json::array(messages_json),
  }
  // システムメッセージを追加
  if system_message.length() > 0 {
    body = body.set_field("system", Json::string(system_message))
  }
  // max_tokensを追加
  match options.max_tokens {
    Some(max) =>
      body = body.set_field("max_tokens", Json::number(max.to_double()))
    None => body = body.set_field("max_tokens", Json::number(4096.0))
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
/// システムメッセージを抽出
fn extract_system_message(messages : Array[@types.ModelMessage]) -> String {
  for msg in messages {
    match msg {
      @types.ModelMessage::System(content) => return content
      _ => ()
    }
  }
  ""
}

///|
/// システムメッセージ以外をフィルタ
fn filter_non_system_messages(
  messages : Array[@types.ModelMessage],
) -> Array[@types.ModelMessage] {
  let result : Array[@types.ModelMessage] = []
  for msg in messages {
    match msg {
      @types.ModelMessage::System(_) => ()
      _ => result.push(msg)
    }
  }
  result
}

///|
/// Anthropicレスポンスをパース
pub fn parse_anthropic_response(response_json : Json) -> @types.ModelResponse {
  match response_json {
    { "content": content, "stop_reason": String(stop_reason), .. } => {
      // ツール使用をチェック
      if stop_reason == "tool_use" {
        let tool_calls = parse_anthropic_tool_calls(content)
        if tool_calls.length() > 0 {
          return @types.ModelResponse::ToolCalls(tool_calls)
        }
      }
      // テキスト応答を抽出
      match content {
        Array(blocks) => {
          let text = StringBuilder::new()
          for block in blocks {
            match block {
              { "type": String("text"), "text": String(t), .. } => {
                if text.to_string().length() > 0 {
                  text.write_char('\n')
                }
                text.write_string(t)
              }
              _ => ()
            }
          }
          @types.ModelResponse::Text(text.to_string())
        }
        _ => @types.ModelResponse::ModelError("Invalid content format")
      }
    }
    { "error": { "message": String(msg), .. }, .. } =>
      @types.ModelResponse::ModelError(msg)
    _ => @types.ModelResponse::ModelError("Unknown response format")
  }
}

///|
/// JSONにフィールドを設定するヘルパー
fn Json::set_field(self : Json, key : String, value : Json) -> Json {
  match self {
    Object(map) => {
      map[key] = value
      Json::object(map)
    }
    _ => self
  }
}

///|
/// 非同期でAnthropicを呼び出す（コールバックベース）
pub fn call_anthropic_async(
  provider : AnthropicProvider,
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  options : @types.ModelOptions,
  on_success : (@types.ModelResponse) -> Unit,
  on_error : (String) -> Unit,
) -> Unit {
  let request_body = provider.build_request(messages, tools, options)
  let url = "\{provider.config.base_url}/v1/messages"
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "x-api-key": provider.config.api_key,
    "anthropic-version": provider.config.api_version,
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
          on_success(parse_anthropic_response(json))
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
