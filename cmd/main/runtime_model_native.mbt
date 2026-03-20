///|
/// RuntimeModelOrchestrator（Native実装）
/// config は常に api_v1_settings_state.get_config() から取得する。
/// RuntimeModelOrchestrator は http_client と provider_resolver を保持し、ProviderConfig はキャッシュしない。

///|
fn is_openai_compatible_provider(provider : String) -> Bool {
  provider != "anthropic"
}

///|
/// Groq プロバイダーは Responses API をネイティブサポートしていないため、
/// use_responses_api: true の場合でも Chat Completions に翻訳する必要がある
fn needs_harmony_translation(provider : @types.ProviderConfig) -> Bool {
  // use_responses_api が true でも、プロバイダーが Responses API をサポートしていない場合
  // Chat Completions にフォールバックし、HarmonyToResponsesTranslator で翻訳する
  if not(provider.use_responses_api) {
    return false
  }
  // Groq は Responses API 未対応
  if provider.name == "groq" {
    return true
  }
  // base_url に "groq" が含まれる場合も翻訳が必要
  match provider.base_url {
    Some(url) => url.contains("groq")
    None => false
  }
}

///|
fn validate_provider_config(p : @types.ProviderConfig) -> String? {
  if p.name.is_empty() {
    return Some(
      "provider is required\n\nRun 'mukuro onboard --provider <provider> --api-key <key>' to initialize configuration.",
    )
  }
  if is_openai_compatible_provider(p.name) {
    match p.base_url {
      None =>
        return Some(
          "base_url is required for openai-compatible providers (e.g. OpenAI/Groq/Ollama)",
        )
      Some(url) =>
        if url.trim(chars=" \t\n\r").is_empty() {
          return Some(
            "base_url is required for openai-compatible providers (e.g. OpenAI/Groq/Ollama)",
          )
        }
    }
    if p.default_model.is_empty() {
      return Some("model is required for openai-compatible providers")
    }
    None
  } else {
    match p.api_key {
      None => return Some("api_key is required for anthropic provider")
      Some(k) =>
        if k.is_empty() {
          return Some("api_key is required for anthropic provider")
        }
    }
    if p.default_model.is_empty() {
      return Some("model is required for anthropic provider")
    }
    None
  }
}

///|
/// config から ProviderConfig を解決する実装
pub struct ConfigProviderResolver {
  _unit : Unit
}

///|
pub fn ConfigProviderResolver::new() -> ConfigProviderResolver {
  { _unit: () }
}

///|
pub impl @interfaces.ProviderResolver for ConfigProviderResolver with resolve(
  self,
) {
  ignore(self)
  let config = match api_v1_settings_state.get_config() {
    Some(c) => c
    None => return None
  }
  if config.providers.is_empty() {
    None
  } else {
    Some(config.providers[0])
  }
}

///|
pub struct RuntimeModelOrchestrator {
  http_client : @native.NativeHttpClient
  provider_resolver : &@interfaces.ProviderResolver
}

///|
pub fn RuntimeModelOrchestrator::new(
  provider_resolver : &@interfaces.ProviderResolver,
) -> RuntimeModelOrchestrator {
  { http_client: @native.NativeHttpClient::default(), provider_resolver }
}

///|
struct TestToggle {
  mut forced_response : String?
}

///|
let test_toggle : TestToggle = { forced_response: None }

///|
pub fn set_forced_response_for_test(response : String?) -> Unit {
  test_toggle.forced_response = response
}

///|
fn string_to_body_bytes(s : String) -> Bytes {
  @utf8.encode(s.view())
}

///|
fn body_bytes_to_string(body : Bytes) -> String {
  @utf8.decode(body[:]) catch {
    _ => "<UTF-8 decode error: \{body.length()} bytes>"
  }
}

///|
fn normalize_base_url(base_url : String) -> String {
  let trimmed = base_url.trim(chars=" \t\n\r").to_string()
  if trimmed.has_suffix("/") {
    trimmed.unsafe_substring(start=0, end=trimmed.length() - 1)
  } else {
    trimmed
  }
}

///|
fn parse_openai_response(body : String) -> @llm_types.ModelResponse {
  let json : Json = @json.parse(body) catch {
    _ => return @llm_types.ModelResponse::ModelError("Invalid OpenAI response JSON")
  }
  @openai.parse_chat_response(json)
}

///|
fn parse_openai_responses_response(body : String) -> @llm_types.ModelResponse {
  let json : Json = @json.parse(body) catch {
    _ =>
      return @llm_types.ModelResponse::ModelError(
        "Invalid OpenAI Responses response JSON",
      )
  }
  @openai.parse_responses_api_response(json)
}

///|
fn parse_anthropic_response(body : String) -> @llm_types.ModelResponse {
  let json : Json = @json.parse(body) catch {
    _ =>
      return @llm_types.ModelResponse::ModelError("Invalid Anthropic response JSON")
  }
  @anthropic.parse_response(json)
}

///|
async fn call_openai_impl(
  provider : @types.ProviderConfig,
  http_client : @native.NativeHttpClient,
  messages : Array[@llm_types.ModelMessage],
  options : @types.ModelOptions,
  tools : Array[@llm_types.ToolDefinition],
) -> @llm_types.ModelResponse {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  let api_key = provider.api_key.unwrap_or("")
  if api_key.length() > 0 {
    headers["Authorization"] = "Bearer \{api_key}"
  }
  let model = options.model_name
  let use_responses_api = provider.use_responses_api
  // Harmony Translation: use_responses_api: true だが Responses API 未対応のプロバイダーの場合
  // Chat Completions を使用してリクエストを送信し、レスポンスを翻訳する
  let use_translation = needs_harmony_translation(provider)
  // use_translation が true の場合、Chat Completions を使用
  let use_chat_completions_internally = use_translation || not(use_responses_api)
  let body = (if use_chat_completions_internally {
    @openai.build_chat_body(
      model,
      messages,
      tools,
      max_tokens=options.max_tokens,
      temperature=options.temperature,
    )
  } else {
    @openai.build_responses_api_body(model, messages, tools)
  }).stringify()
  let base = normalize_base_url(provider.base_url.unwrap_or(""))
  let path = if use_chat_completions_internally {
    "/v1/chat/completions"
  } else {
    "/v1/responses"
  }
  let req : @interfaces.HttpRequest = {
    url: "\{base}\{path}",
    http_method: @interfaces.HttpMethod::Post,
    headers,
    body: Some(string_to_body_bytes(body)),
  }
  let response = @interfaces.HttpClient::request(http_client, req) catch {
    _ => return @llm_types.ModelResponse::ModelError("OpenAI request failed")
  }
  if response.status == 429 {
    return @llm_types.ModelResponse::RateLimited(retry_after=60)
  }
  if response.status < 200 || response.status >= 300 {
    let err_body = body_bytes_to_string(response.body)
    return @llm_types.ModelResponse::ModelError(
      "OpenAI HTTP error: \{response.status}; body=\{err_body}",
    )
  }
  // Responses API モードでも、翻訳が必要な場合は Chat Completions レスポンスをパース
  if use_chat_completions_internally {
    parse_openai_response(body_bytes_to_string(response.body))
  } else {
    parse_openai_responses_response(body_bytes_to_string(response.body))
  }
}

///|
async fn call_anthropic_impl(
  provider : @types.ProviderConfig,
  http_client : @native.NativeHttpClient,
  messages : Array[@llm_types.ModelMessage],
  options : @types.ModelOptions,
  tools : Array[@llm_types.ToolDefinition],
) -> @llm_types.ModelResponse {
  let api_key = provider.api_key.unwrap_or("")
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "x-api-key": api_key,
    "anthropic-version": "2023-06-01",
  }
  let model = options.model_name
  let system = @anthropic.extract_system_message(messages)
  let body = @anthropic.build_body(
    model,
    messages,
    tools,
    system~,
    max_tokens=options.max_tokens,
    temperature=options.temperature,
  ).stringify()
  let req : @interfaces.HttpRequest = {
    url: "https://api.anthropic.com/v1/messages",
    http_method: @interfaces.HttpMethod::Post,
    headers,
    body: Some(string_to_body_bytes(body)),
  }
  let response = @interfaces.HttpClient::request(http_client, req) catch {
    _ => return @llm_types.ModelResponse::ModelError("Anthropic request failed")
  }
  if response.status == 429 {
    return @llm_types.ModelResponse::RateLimited(retry_after=60)
  }
  if response.status < 200 || response.status >= 300 {
    return @llm_types.ModelResponse::ModelError(
      "Anthropic HTTP error: \{response.status}",
    )
  }
  parse_anthropic_response(body_bytes_to_string(response.body))
}

///|
pub impl @interfaces.ModelOrchestrator for RuntimeModelOrchestrator with call(
  self,
  messages~,
  tools~,
  options~,
) {
  match test_toggle.forced_response {
    Some(content) => return @llm_types.ModelResponse::Text(content)
    None => ()
  }
  let provider = match self.provider_resolver.resolve() {
    Some(p) => p
    None =>
      return @llm_types.ModelResponse::ModelError(
        "Configuration not initialized or no providers configured",
      )
  }
  match validate_provider_config(provider) {
    Some(msg) => return @llm_types.ModelResponse::ModelError(msg)
    None => ()
  }
  if is_openai_compatible_provider(provider.name) {
    call_openai_impl(provider, self.http_client, messages, options, tools)
  } else {
    call_anthropic_impl(provider, self.http_client, messages, options, tools)
  }
}

// =============================================================================
// Streaming API with Harmony Translation
// =============================================================================

///|
/// ストリーミングイベントの型
pub(all) enum StreamEvent {
  /// Responses API フォーマットのイベント (event_type, data)
  ResponsesEvent(String, Json)
  /// ストリーミング完了
  Done(@llm_types.ModelResponse)
  /// エラー
  Error(String)
}

///|
/// SSE JSONL をパースして Responses API イベントに翻訳
/// Chat Completions SSE フォーマットから Responses API イベントを生成
pub fn translate_sse_jsonl_to_responses_events(
  jsonl : String,
) -> Array[(String, Json)] {
  let translator = @harmony.HarmonyToResponsesTranslator::new(response_id="resp_generated")
  let events = @sse.parse_jsonl(jsonl) catch { _ => return [] }
  let result : Array[(String, Json)] = []
  for event in events {
    let translated = translator.translate(event)
    for evt in translated {
      result.push(evt)
    }
  }
  result
}

///|
/// 非ストリーミングレスポンスを Responses API イベント形式に変換
/// 翻訳レイヤーの検証に使用
pub fn model_response_to_stream_events(
  response : @llm_types.ModelResponse,
) -> Array[(String, Json)] {
  let events : Array[(String, Json)] = []
  // response.created
  events.push((
    "response.created",
    { "type": "response.created", "response": { "id": "resp_generated" } },
  ))
  match response {
    @llm_types.ModelResponse::Text(content) | @llm_types.ModelResponse::RichText({ content, .. }) => {
      // response.output_text.delta (full content)
      events.push((
        "response.output_text.delta",
        { "type": "response.output_text.delta", "delta": content, "output_index": 0 },
      ))
      // response.output_text.done
      events.push((
        "response.output_text.done",
        { "type": "response.output_text.done", "text": content, "output_index": 0 },
      ))
    }
    @llm_types.ModelResponse::ToolCalls(calls) =>
      for i, call in calls {
        // response.output_item.added
        events.push((
          "response.output_item.added",
          {
            "type": "response.output_item.added",
            "output_index": i,
            "item": {
              "type": "function_call",
              "id": call.id.to_json(),
              "call_id": call.id.to_json(),
              "name": call.name.to_json(),
              "arguments": call.arguments.stringify().to_json(),
            },
          },
        ))
      }
    _ => ()
  }
  // response.completed
  events.push(("response.completed", { "type": "response.completed" }))
  events
}
