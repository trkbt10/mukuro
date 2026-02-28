///|
/// RuntimeModelOrchestrator（Native実装）

///|
fn default_model_for(provider : String) -> String {
  match provider {
    "anthropic" => "claude-3-5-sonnet-latest"
    _ => ""
  }
}

///|
fn is_openai_compatible_provider(provider : String) -> Bool {
  provider != "anthropic"
}

///|
fn validate_runtime_config_or_error(cfg : RuntimeModelConfig) -> String? {
  let provider = cfg.provider.trim(chars=" \t\n\r").to_string()
  let model = cfg.model.trim(chars=" \t\n\r").to_string()
  let base_url = cfg.base_url.trim(chars=" \t\n\r").to_string()
  if provider.length() == 0 {
    return Some(
      "provider is required in \{default_runtime_config_path()}\n\nRun 'mukuro onboard --provider <provider> --api-key <key>' to initialize configuration.",
    )
  }
  if is_openai_compatible_provider(provider) {
    if base_url.length() == 0 {
      return Some(
        "base_url is required for openai-compatible providers (e.g. OpenAI/Groq/Ollama)",
      )
    }
    if model.length() == 0 {
      return Some("model is required for openai-compatible providers")
    }
    None
  } else {
    if cfg.api_key.is_empty() {
      return Some("api_key is required for anthropic provider")
    }
    if model.length() == 0 {
      return Some("model is required for anthropic provider")
    }
    None
  }
}

///|
struct RuntimeModelConfig {
  provider : String
  api_key : String
  model : String
  base_url : String
  use_responses_api : Bool
}

///|
struct RuntimeModelPathCell {
  mut path : String
}

///|
let runtime_model_path_cell : RuntimeModelPathCell = { path: "" }

///|
fn get_runtime_model_config_path() -> String {
  let path = runtime_model_path_cell.path
  if path.is_empty() {
    default_runtime_config_path()
  } else {
    path
  }
}

///|
pub fn set_runtime_model_config_path_for_process(path : String) -> Unit {
  runtime_model_path_cell.path = path
}

///|
fn default_runtime_model_config() -> RuntimeModelConfig {
  {
    provider: "",
    api_key: "",
    model: "",
    base_url: "",
    use_responses_api: false,
  }
}

///|
fn parse_runtime_model_config(
  root : Map[String, Json],
) -> RuntimeModelConfig raise @interfaces.ControlError {
  let provider = parse_string_field_impl(root, "provider", "")
  let api_key = parse_string_field_impl(root, "api_key", "")
  let model = parse_string_field_impl(
    root,
    "model",
    parse_string_field_impl(root, "default_model", default_model_for(provider)),
  )
  let base_url = parse_string_field_impl(root, "base_url", "")
  let use_responses_api = parse_bool_field_impl(
    root, "use_responses_api", false,
  )
  { provider, api_key, model, base_url, use_responses_api }
}

///|
fn load_runtime_model_config() -> RuntimeModelConfig {
  parse_runtime_model_config(
    load_config_root_impl(get_runtime_model_config_path()),
  ) catch {
    _ => return default_runtime_model_config()
  }
}

///|
pub struct RuntimeModelOrchestrator {
  provider : String
  api_key : String
  model : String
  base_url : String
  use_responses_api : Bool
  http_client : @native.NativeHttpClient
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
pub fn RuntimeModelOrchestrator::default() -> RuntimeModelOrchestrator {
  let cfg = load_runtime_model_config()
  {
    provider: cfg.provider,
    api_key: cfg.api_key,
    model: cfg.model,
    base_url: cfg.base_url,
    use_responses_api: cfg.use_responses_api,
    http_client: @native.NativeHttpClient::default(),
  }
}

///|
fn select_model_name(
  orchestrator : RuntimeModelOrchestrator,
  options : @types.ModelOptions,
) -> String {
  if options.model_name.length() > 0 &&
    options.model_name != "claude-sonnet-4-20250514" {
    options.model_name
  } else {
    orchestrator.model
  }
}

///|
fn string_to_body_bytes(s : String) -> Bytes {
  @utf8.encode(s.view())
}

///|
fn body_bytes_to_string(body : Bytes) -> String {
  @utf8.decode(body[:]) catch {
    _ => ""
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
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
  tools : Array[@types.ToolDefinition],
) -> @types.ModelResponse {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  if orchestrator.api_key.length() > 0 {
    headers["Authorization"] = "Bearer \{orchestrator.api_key}"
  }
  let model = select_model_name(orchestrator, options)
  let body = (if orchestrator.use_responses_api {
    @protocol.build_responses_api_body(model, messages, tools)
  } else {
    @protocol.build_openai_chat_body(model, messages, tools)
  }).stringify()
  let base = normalize_base_url(orchestrator.base_url)
  let path = if orchestrator.use_responses_api {
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
  let response = @interfaces.HttpClient::request(orchestrator.http_client, req) catch {
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
  if orchestrator.use_responses_api {
    parse_openai_responses_response(body_bytes_to_string(response.body))
  } else {
    parse_openai_response(body_bytes_to_string(response.body))
  }
}

///|
async fn call_anthropic_impl(
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
  tools : Array[@types.ToolDefinition],
) -> @types.ModelResponse {
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "x-api-key": orchestrator.api_key,
    "anthropic-version": "2023-06-01",
  }
  let model = select_model_name(orchestrator, options)
  let system = @protocol.extract_system_message(messages)
  let body = @protocol.build_anthropic_body(
    model,
    messages,
    tools,
    system=system,
  ).stringify()
  let req : @interfaces.HttpRequest = {
    url: "https://api.anthropic.com/v1/messages",
    http_method: @interfaces.HttpMethod::Post,
    headers,
    body: Some(string_to_body_bytes(body)),
  }
  let response = @interfaces.HttpClient::request(orchestrator.http_client, req) catch {
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
async fn call_openai_async_impl(
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
  tools : Array[@types.ToolDefinition],
) -> @types.ModelResponse {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  if orchestrator.api_key.length() > 0 {
    headers["Authorization"] = "Bearer \{orchestrator.api_key}"
  }
  let model = select_model_name(orchestrator, options)
  let body = (if orchestrator.use_responses_api {
    @protocol.build_responses_api_body(model, messages, tools)
  } else {
    @protocol.build_openai_chat_body(model, messages, tools)
  }).stringify()
  let base = normalize_base_url(orchestrator.base_url)
  let path = if orchestrator.use_responses_api {
    "/v1/responses"
  } else {
    "/v1/chat/completions"
  }
  let (response, body_data) = @xhttp.post("\{base}\{path}", body, headers~) catch {
    _ => return @types.ModelResponse::ModelError("OpenAI request failed")
  }
  if response.code == 429 {
    return @types.ModelResponse::RateLimited(retry_after=60)
  }
  let response_body = body_data.text() catch { _ => "" }
  if response.code < 200 || response.code >= 300 {
    return @types.ModelResponse::ModelError(
      "OpenAI HTTP error: \{response.code}; body=\{response_body}",
    )
  }
  if orchestrator.use_responses_api {
    parse_openai_responses_response(response_body)
  } else {
    parse_openai_response(response_body)
  }
}

///|
async fn call_anthropic_async_impl(
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
  tools : Array[@types.ToolDefinition],
) -> @types.ModelResponse {
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "x-api-key": orchestrator.api_key,
    "anthropic-version": "2023-06-01",
  }
  let model = select_model_name(orchestrator, options)
  let system = @protocol.extract_system_message(messages)
  let body = @protocol.build_anthropic_body(
    model,
    messages,
    tools,
    system=system,
  ).stringify()
  let (response, body_data) = @xhttp.post(
    "https://api.anthropic.com/v1/messages",
    body,
    headers~,
  ) catch {
    _ => return @types.ModelResponse::ModelError("Anthropic request failed")
  }
  if response.code == 429 {
    return @types.ModelResponse::RateLimited(retry_after=60)
  }
  let response_body = body_data.text() catch { _ => "" }
  if response.code < 200 || response.code >= 300 {
    return @types.ModelResponse::ModelError(
      "Anthropic HTTP error: \{response.code}; body=\{response_body}",
    )
  }
  parse_anthropic_response(response_body)
}

///|
pub async fn runtime_model_invoke_async(
  messages : Array[@types.ModelMessage],
  tools : Array[@types.ToolDefinition],
  options : @types.ModelOptions,
) -> @types.ModelResponse {
  let cfg = load_runtime_model_config()
  let runtime : RuntimeModelOrchestrator = {
    provider: cfg.provider,
    api_key: cfg.api_key,
    model: cfg.model,
    base_url: cfg.base_url,
    use_responses_api: cfg.use_responses_api,
    http_client: @native.NativeHttpClient::default(),
  }
  match validate_runtime_config_or_error(cfg) {
    Some(msg) => return @types.ModelResponse::ModelError(msg)
    None => ()
  }
  if is_openai_compatible_provider(runtime.provider) {
    call_openai_async_impl(runtime, messages, options, tools)
  } else {
    call_anthropic_async_impl(runtime, messages, options, tools)
  }
}

///|
pub impl @interfaces.ModelOrchestrator for RuntimeModelOrchestrator with call(
  self,
  messages~,
  tools~,
  options~,
) {
  let cfg = load_runtime_model_config()
  let runtime : RuntimeModelOrchestrator = {
    provider: cfg.provider,
    api_key: cfg.api_key,
    model: cfg.model,
    base_url: cfg.base_url,
    use_responses_api: cfg.use_responses_api,
    http_client: self.http_client,
  }
  match test_toggle.forced_response {
    Some(content) => return @types.ModelResponse::Text(content)
    None => ()
  }
  match validate_runtime_config_or_error(cfg) {
    Some(msg) => return @types.ModelResponse::ModelError(msg)
    None => ()
  }
  if is_openai_compatible_provider(runtime.provider) {
    call_openai_impl(runtime, messages, options, tools)
  } else {
    call_anthropic_impl(runtime, messages, options, tools)
  }
}
