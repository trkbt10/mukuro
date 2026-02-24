///|
/// RuntimeModelOrchestrator（Native実装）

///|
fn default_model_for(provider : String) -> String {
  if provider == "openai" {
    "gpt-4o-mini"
  } else {
    "claude-3-5-sonnet-latest"
  }
}

///|
struct RuntimeModelConfig {
  provider : String
  api_key : String
  model : String
}

///|
fn default_runtime_model_config() -> RuntimeModelConfig {
  { provider: "anthropic", api_key: "", model: default_model_for("anthropic") }
}

///|
fn parse_runtime_model_config(content : String) -> RuntimeModelConfig {
  let parsed : Json = @json.parse(content) catch {
    _ => return default_runtime_model_config()
  }
  match parsed {
    Object(obj) => {
      let provider = match obj.get("provider") {
        Some(String(s)) => s
        _ => "anthropic"
      }
      let api_key = match obj.get("api_key") {
        Some(String(s)) => s
        _ => ""
      }
      let model = match obj.get("default_model") {
        Some(String(s)) => s
        _ => default_model_for(provider)
      }
      { provider, api_key, model }
    }
    _ => default_runtime_model_config()
  }
}

///|
fn load_runtime_model_config() -> RuntimeModelConfig {
  let path = ".mukuro/config.json"
  let buffer_len = 65536
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file(
    @native.string_to_cstring(path),
    buffer,
    buffer_len,
  )
  if read_len <= 0 {
    return default_runtime_model_config()
  }
  let data = Bytes::from_iter(buffer[:read_len].iter())
  let content = @utf8.decode(data[:]) catch {
    _ => return default_runtime_model_config()
  }
  parse_runtime_model_config(content)
}

///|
pub struct RuntimeModelOrchestrator {
  provider : String
  api_key : String
  model : String
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
    http_client: @native.NativeHttpClient::default(),
  }
}

///|
fn select_model_name(
  orchestrator : RuntimeModelOrchestrator,
  options : @types.ModelOptions,
) -> String {
  if options.model_name.length() > 0 {
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
fn to_basic_chat_messages(messages : Array[@types.ModelMessage]) -> Array[Json] {
  let result : Array[Json] = []
  for msg in messages {
    match msg {
      @types.ModelMessage::System(content) =>
        result.push({ "role": "system", "content": content })
      @types.ModelMessage::User(content~, ..) =>
        result.push({ "role": "user", "content": content })
      @types.ModelMessage::Assistant(content~, ..) =>
        result.push({ "role": "assistant", "content": content })
      @types.ModelMessage::ToolResult(content~, ..) =>
        result.push({ "role": "user", "content": content })
    }
  }
  result
}

///|
fn build_openai_body_impl(
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
) -> Json {
  {
    "model": select_model_name(orchestrator, options),
    "messages": Json::array(to_basic_chat_messages(messages)),
  }
}

///|
fn extract_anthropic_system(messages : Array[@types.ModelMessage]) -> String {
  let mut system = ""
  for msg in messages {
    match msg {
      @types.ModelMessage::System(content) => system = content
      _ => ()
    }
  }
  system
}

///|
fn to_anthropic_messages(messages : Array[@types.ModelMessage]) -> Array[Json] {
  let result : Array[Json] = []
  for msg in messages {
    match msg {
      @types.ModelMessage::System(_) => ()
      @types.ModelMessage::User(content~, ..) =>
        result.push({ "role": "user", "content": content })
      @types.ModelMessage::Assistant(content~, ..) =>
        result.push({ "role": "assistant", "content": content })
      @types.ModelMessage::ToolResult(content~, ..) =>
        result.push({ "role": "user", "content": content })
    }
  }
  result
}

///|
fn build_anthropic_body_impl(
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
) -> Json {
  let system = extract_anthropic_system(messages)
  {
    "model": select_model_name(orchestrator, options),
    "max_tokens": 1024,
    "system": system,
    "messages": Json::array(to_anthropic_messages(messages)),
  }
}

///|
fn parse_openai_response(body : String) -> @types.ModelResponse {
  let json : Json = @json.parse(body) catch {
    _ => return @types.ModelResponse::ModelError("Invalid OpenAI response JSON")
  }
  match json {
    { "choices": Array(choices), .. } =>
      if choices.length() == 0 {
        @types.ModelResponse::ModelError("OpenAI response has no choices")
      } else {
        match choices[0] {
          { "message": { "content": String(content), .. }, .. } =>
            @types.ModelResponse::Text(content)
          _ =>
            @types.ModelResponse::ModelError("OpenAI response missing content")
        }
      }
    _ => @types.ModelResponse::ModelError("OpenAI response shape is invalid")
  }
}

///|
fn parse_anthropic_response(body : String) -> @types.ModelResponse {
  let json : Json = @json.parse(body) catch {
    _ =>
      return @types.ModelResponse::ModelError("Invalid Anthropic response JSON")
  }
  match json {
    { "content": Array(contents), .. } => {
      let text = StringBuilder::new()
      for item in contents {
        match item {
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
    _ => @types.ModelResponse::ModelError("Anthropic response shape is invalid")
  }
}

///|
fn call_openai_impl(
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
) -> @types.ModelResponse {
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "Authorization": "Bearer \{orchestrator.api_key}",
  }
  let body = build_openai_body_impl(orchestrator, messages, options).stringify()
  let req : @interfaces.HttpRequest = {
    url: "https://api.openai.com/v1/chat/completions",
    http_method: @interfaces.HttpMethod::Post,
    headers,
    body: Some(string_to_body_bytes(body)),
  }
  let response = orchestrator.http_client.do_request(req) catch {
    _ => return @types.ModelResponse::ModelError("OpenAI request failed")
  }
  if response.status == 429 {
    return @types.ModelResponse::RateLimited(retry_after=60)
  }
  if response.status < 200 || response.status >= 300 {
    return @types.ModelResponse::ModelError(
      "OpenAI HTTP error: \{response.status}",
    )
  }
  parse_openai_response(response.body.to_unchecked_string())
}

///|
fn call_anthropic_impl(
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
) -> @types.ModelResponse {
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "x-api-key": orchestrator.api_key,
    "anthropic-version": "2023-06-01",
  }
  let body = build_anthropic_body_impl(orchestrator, messages, options).stringify()
  let req : @interfaces.HttpRequest = {
    url: "https://api.anthropic.com/v1/messages",
    http_method: @interfaces.HttpMethod::Post,
    headers,
    body: Some(string_to_body_bytes(body)),
  }
  let response = orchestrator.http_client.do_request(req) catch {
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
  parse_anthropic_response(response.body.to_unchecked_string())
}

///|
pub impl @interfaces.ModelOrchestrator for RuntimeModelOrchestrator with call(
  self,
  messages~,
  tools~,
  options~,
) {
  ignore(tools)
  match test_toggle.forced_response {
    Some(content) => return @types.ModelResponse::Text(content)
    None => ()
  }
  // APIキー未設定時は明示エラー
  if self.api_key.is_empty() {
    return @types.ModelResponse::ModelError(
      "API key is not configured for provider: \{self.provider}. Run `mukuro onboard` to create .mukuro/config.json",
    )
  }
  if self.provider == "openai" {
    call_openai_impl(self, messages, options)
  } else {
    call_anthropic_impl(self, messages, options)
  }
}
