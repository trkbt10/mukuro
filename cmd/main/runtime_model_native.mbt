///|
/// RuntimeModelOrchestrator（Native実装）
/// config は常に api_v1_settings_state.get_config() から取得する。
/// RuntimeModelOrchestrator は http_client と provider_resolver を保持し、ProviderConfig はキャッシュしない。

///|
fn is_openai_compatible_provider(provider : String) -> Bool {
  provider != "anthropic"
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
fn parse_openai_response(body : String) -> @types.ModelResponse {
  let json : Json = @json.parse(body) catch {
    _ => return @types.ModelResponse::ModelError("Invalid OpenAI response JSON")
  }
  @protocol.parse_openai_chat_response(json)
}

///|
fn parse_openai_responses_response(body : String) -> @types.ModelResponse {
  let json : Json = @json.parse(body) catch {
    _ =>
      return @types.ModelResponse::ModelError(
        "Invalid OpenAI Responses response JSON",
      )
  }
  @protocol.parse_responses_api_response(json)
}

///|
fn parse_anthropic_response(body : String) -> @types.ModelResponse {
  let json : Json = @json.parse(body) catch {
    _ =>
      return @types.ModelResponse::ModelError("Invalid Anthropic response JSON")
  }
  @protocol.parse_anthropic_response(json)
}

///|
async fn call_openai_impl(
  provider : @types.ProviderConfig,
  http_client : @native.NativeHttpClient,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
  tools : Array[@types.ToolDefinition],
) -> @types.ModelResponse {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  let api_key = provider.api_key.unwrap_or("")
  if api_key.length() > 0 {
    headers["Authorization"] = "Bearer \{api_key}"
  }
  let model = options.model_name
  let use_responses_api = provider.use_responses_api
  let body = (if use_responses_api {
    @protocol.build_responses_api_body(model, messages, tools)
  } else {
    @protocol.build_openai_chat_body(
      model,
      messages,
      tools,
      max_tokens=options.max_tokens,
      temperature=options.temperature,
    )
  }).stringify()
  let base = normalize_base_url(provider.base_url.unwrap_or(""))
  let path = if use_responses_api {
    "/v1/responses"
  } else {
    "/v1/chat/completions"
  }
  let req : @interfaces.HttpRequest = {
    url: "\{base}\{path}",
    http_method: @interfaces.HttpMethod::Post,
    headers,
    body: Some(string_to_body_bytes(body)),
  }
  let response = @interfaces.HttpClient::request(http_client, req) catch {
    _ => return @types.ModelResponse::ModelError("OpenAI request failed")
  }
  if response.status == 429 {
    return @types.ModelResponse::RateLimited(retry_after=60)
  }
  if response.status < 200 || response.status >= 300 {
    let err_body = body_bytes_to_string(response.body)
    return @types.ModelResponse::ModelError(
      "OpenAI HTTP error: \{response.status}; body=\{err_body}",
    )
  }
  if use_responses_api {
    parse_openai_responses_response(body_bytes_to_string(response.body))
  } else {
    parse_openai_response(body_bytes_to_string(response.body))
  }
}

///|
async fn call_anthropic_impl(
  provider : @types.ProviderConfig,
  http_client : @native.NativeHttpClient,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
  tools : Array[@types.ToolDefinition],
) -> @types.ModelResponse {
  let api_key = provider.api_key.unwrap_or("")
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "x-api-key": api_key,
    "anthropic-version": "2023-06-01",
  }
  let model = options.model_name
  let system = @protocol.extract_system_message(messages)
  let body = @protocol.build_anthropic_body(
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
    _ => return @types.ModelResponse::ModelError("Anthropic request failed")
  }
  if response.status == 429 {
    return @types.ModelResponse::RateLimited(retry_after=60)
  }
  if response.status < 200 || response.status >= 300 {
    return @types.ModelResponse::ModelError(
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
    Some(content) => return @types.ModelResponse::Text(content)
    None => ()
  }
  let provider = match self.provider_resolver.resolve() {
    Some(p) => p
    None =>
      return @types.ModelResponse::ModelError(
        "Configuration not initialized or no providers configured",
      )
  }
  match validate_provider_config(provider) {
    Some(msg) => return @types.ModelResponse::ModelError(msg)
    None => ()
  }
  if is_openai_compatible_provider(provider.name) {
    call_openai_impl(provider, self.http_client, messages, options, tools)
  } else {
    call_anthropic_impl(provider, self.http_client, messages, options, tools)
  }
}
