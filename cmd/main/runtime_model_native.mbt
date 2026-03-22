///|
/// RuntimeModelOrchestrator（Native実装）
/// config は常に api_v1_settings_state.get_config() から取得する。
/// RuntimeModelOrchestrator は http_client と provider_resolver を保持し、ProviderConfig はキャッシュしない。
/// LLM プロトコルロジックは llm_interop に委譲する。

// =============================================================================
// NativeHttpTransport — llm_interop の HttpTransport を NativeHttpClient で実装
// =============================================================================

///|
pub struct NativeHttpTransport {
  client : @native.NativeHttpClient
}

///|
pub fn NativeHttpTransport::new(
  client : @native.NativeHttpClient,
) -> NativeHttpTransport {
  { client, }
}

///|
fn build_transport_headers(
  req : @llm_client.TransportRequest,
) -> Map[String, String] {
  let headers : Map[String, String] = {}
  for key, value in req.headers {
    headers[key] = value
  }
  headers
}

///|
pub impl @llm_client.HttpTransport for NativeHttpTransport with request(
  self,
  req,
) {
  ignore(self)
  let headers = build_transport_headers(req)
  let body_text = req.body.unwrap_or("")
  let (resp, body_data) = @xhttp.post(req.url, body_text, headers~) catch {
    e => raise @llm_client.transport_network_error("HTTP request failed: \{e}")
  }
  {
    status: resp.code,
    body: body_bytes_to_string(Bytes::from_iter(body_data.binary().iter())),
  }
}

///|
/// Stream reader wrapping mizchi/x/http Stream
struct NativeStreamReader {
  stream : @xhttp.Stream
}

///|
pub impl @llm_client.StreamReader for NativeStreamReader with read(self) {
  self.stream.read_some() catch {
    e => raise @llm_client.transport_network_error("Stream read failed: \{e}")
  }
}

///|
pub impl @llm_client.StreamingHttpTransport for NativeHttpTransport with request_stream(
  self,
  req,
) {
  ignore(self)
  let headers = build_transport_headers(req)
  let body_text = req.body.unwrap_or("")
  let (resp, stream) = @xhttp.post_stream(req.url, body_text, headers~) catch {
    e => raise @llm_client.transport_network_error("HTTP request failed: \{e}")
  }
  let reader : NativeStreamReader = { stream, }
  { status: resp.code, reader }
}

// =============================================================================
// mukuro ProviderConfig → llm_interop gateway ProviderConfig 変換
// =============================================================================

///|
/// mukuro のプロバイダ名から ModelApi を解決する
fn resolve_model_api(provider : @types.ProviderConfig) -> @gateway.ModelApi {
  // use_responses_api フラグによる OpenAI Responses API の選択
  // use_harmony_parser=true: プロバイダは Chat Completions のみ対応（Groq, Ollama 等）
  //   → OpenAICompletions のまま送信し、Harmony パイプラインで Responses API 表現に変換
  // use_harmony_parser=false: プロバイダが Responses API をネイティブサポート（OpenAI）
  //   → OpenAIResponses に切り替えて /v1/responses に直接送信
  if provider.use_responses_api && not(provider.use_harmony_parser) {
    let api = @gateway.ModelApi::from_string(provider.name)
    match api {
      Some(@gateway.ModelApi::OpenAICompletions) =>
        return @gateway.OpenAIResponses
      _ => ()
    }
  }
  // 標準的な変換: プロバイダ名 → ModelApi
  match @gateway.ModelApi::from_string(provider.name) {
    Some(api) => api
    None =>
      // 未知のプロバイダは OpenAI Compatible として扱う
      @gateway.OpenAICompletions
  }
}

///|
/// mukuro の ProviderConfig → llm_interop の gateway.ProviderConfig に変換
fn to_gateway_provider_config(
  p : @types.ProviderConfig,
) -> @gateway.ProviderConfig {
  let api = resolve_model_api(p)
  let base_url = match p.base_url {
    Some(url) => {
      let trimmed = url.trim(chars=" \t\n\r").to_string()
      if trimmed.has_suffix("/") {
        trimmed.unsafe_substring(start=0, end=trimmed.length() - 1)
      } else {
        trimmed
      }
    }
    None => api.default_base_url()
  }
  {
    ..@gateway.ProviderConfig::new(p.name, api),
    base_url,
    api_key: p.api_key.unwrap_or(""),
  }
}

// =============================================================================
// Validation
// =============================================================================

///|
fn validate_provider_config(p : @types.ProviderConfig) -> String? {
  if p.name.is_empty() {
    return Some(
      "provider is required\n\nRun 'mukuro onboard --provider <provider> --api-key <key>' to initialize configuration.",
    )
  }
  let api = resolve_model_api(p)
  let surface = api.to_dialect()
  match surface {
    @gateway.Gemini => {
      match p.api_key {
        None => return Some("api_key is required for gemini provider")
        Some(k) =>
          if k.is_empty() {
            return Some("api_key is required for gemini provider")
          }
      }
      if p.default_model.is_empty() {
        return Some("model is required for gemini provider")
      }
      None
    }
    @gateway.Anthropic => {
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
    // OpenAI, Codex — OpenAI-compatible providers
    _ => {
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
    }
  }
}

// =============================================================================
// ConfigProviderResolver
// =============================================================================

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

// =============================================================================
// RuntimeModelOrchestrator
// =============================================================================

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
/// 単一プロバイダでの LLM 呼び出し（llm_interop 経由）
/// 全経路 Responses API 中間層 + ストリーミング
async fn call_provider_via_gateway(
  provider : @types.ProviderConfig,
  transport : NativeHttpTransport,
  messages : Array[@llm_types.ModelMessage],
  options : @types.ModelOptions,
  tools : Array[@llm_types.ToolDefinition],
) -> @llm_types.ModelResponse {
  let gw_provider = to_gateway_provider_config(provider)
  @llm_client.chat_gateway_responses_stream(
    gw_provider,
    transport,
    messages,
    tools,
    options.model_name,
    on_event=fn(_event) {  },
    max_tokens=options.max_tokens,
    temperature=options.temperature,
  ) catch {
    @llm_client.ClientError::ApiError(code~, message~) =>
      if code == 429 {
        @llm_types.ModelResponse::RateLimited(retry_after=60)
      } else {
        @llm_types.ModelResponse::ModelError(
          "HTTP error: \{code}; body=\{message}",
        )
      }
    @llm_client.ClientError::HttpError(msg) =>
      @llm_types.ModelResponse::ModelError("Request failed: \{msg}")
    @llm_client.ClientError::ParseError(msg) =>
      @llm_types.ModelResponse::ModelError("Parse error: \{msg}")
  }
}

///|
/// config から名前でプロバイダを取得
fn find_provider_by_name(name : String) -> @types.ProviderConfig? {
  let config = match api_v1_settings_state.get_config() {
    Some(c) => c
    None => return None
  }
  for p in config.providers {
    if p.name == name {
      return Some(p)
    }
  }
  None
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
  let transport = NativeHttpTransport::new(self.http_client)
  // フェイルオーバー: fallback.enabled なら複数プロバイダを順に試行
  let config = api_v1_settings_state.get_config()
  let fallback_enabled = match config {
    Some(c) => c.fallback.enabled && c.fallback.providers.length() > 0
    None => false
  }
  if not(fallback_enabled) {
    return call_provider_via_gateway(
      provider, transport, messages, options, tools,
    )
  }
  // プライマリプロバイダでまず試行
  let primary_result = call_provider_via_gateway(
    provider, transport, messages, options, tools,
  )
  match primary_result {
    @llm_types.ModelResponse::ModelError(_)
    | @llm_types.ModelResponse::RateLimited(..) => ()
    _ => return primary_result // 成功
  }
  // フェイルオーバーチェーン
  let fallback_providers = config.unwrap().fallback.providers
  for fb_name in fallback_providers {
    if fb_name == provider.name {
      continue // プライマリは既に試行済み
    }
    let fb_provider = match find_provider_by_name(fb_name) {
      Some(p) => p
      None => continue
    }
    match validate_provider_config(fb_provider) {
      Some(_) => continue
      None => ()
    }
    // フォールバック先のモデル名で options を調整
    let fb_options = if fb_provider.default_model.length() > 0 {
      { ..options, model_name: fb_provider.default_model }
    } else {
      options
    }
    let fb_result = call_provider_via_gateway(
      fb_provider, transport, messages, fb_options, tools,
    )
    match fb_result {
      @llm_types.ModelResponse::ModelError(_)
      | @llm_types.ModelResponse::RateLimited(..) => continue
      _ => return fb_result // 成功
    }
  }
  // 全プロバイダ失敗
  @llm_types.ModelResponse::ModelError(
    "All providers failed (primary + \{fallback_providers.length()} fallbacks)",
  )
}

// =============================================================================
// Utilities (kept)
// =============================================================================

///|
/// Vision: メッセージ配列から画像 URL を含む最後の User メッセージを検出
/// 返り値: (画像URL, メッセージインデックス) または None
fn find_vision_image(
  messages : Array[@llm_types.ModelMessage],
) -> (String, Int)? {
  let mut i = messages.length() - 1
  while i >= 0 {
    match messages[i] {
      @llm_types.ModelMessage::User(name=Some(n), ..) =>
        if n.has_prefix("image:") {
          let url = n[6:].to_string()
          return Some((url, i))
        }
      _ => ()
    }
    i = i - 1
  }
  None
}

///|
fn body_bytes_to_string(body : Bytes) -> String {
  @utf8.decode(body[:]) catch {
    _ => "<UTF-8 decode error: \{body.length()} bytes>"
  }
}

// =============================================================================
// ModelResponse → Responses API events (WebSocket 表示層)
// =============================================================================

///|
/// 非ストリーミングレスポンスを Responses API イベント形式に変換
/// WebSocket チャットハンドラーがクライアントにイベント列として送信するために使用
pub fn model_response_to_stream_events(
  response : @llm_types.ModelResponse,
) -> Array[(String, Json)] {
  let events : Array[(String, Json)] = []
  // response.created
  events.push(
    (
      "response.created",
      { "type": "response.created", "response": { "id": "resp_generated" } },
    ),
  )
  match response {
    @llm_types.ModelResponse::Text(content)
    | @llm_types.ModelResponse::RichText({ content, .. }) => {
      // response.output_text.delta (full content)
      events.push(
        (
          "response.output_text.delta",
          {
            "type": "response.output_text.delta",
            "delta": content,
            "output_index": 0,
          },
        ),
      )
      // response.output_text.done
      events.push(
        (
          "response.output_text.done",
          {
            "type": "response.output_text.done",
            "text": content,
            "output_index": 0,
          },
        ),
      )
    }
    @llm_types.ModelResponse::ToolCalls(calls) =>
      for i, call in calls {
        // response.output_item.added
        events.push(
          (
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
          ),
        )
      }
    _ => ()
  }
  // response.completed
  events.push(("response.completed", { "type": "response.completed" }))
  events
}
