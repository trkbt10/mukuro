///|
/// RuntimeModelOrchestrator（Native実装）

///|
fn default_model_for(provider : String) -> String {
  match provider {
    "openai" | "groq" => "gpt-4o-mini"
    "ollama" => "llama3.2"
    _ => "claude-3-5-sonnet-latest"
  }
}

///|
fn is_openai_compatible_provider(provider : String) -> Bool {
  provider == "openai" || provider == "groq" || provider == "ollama"
}

///|
fn provider_requires_api_key(provider : String) -> Bool {
  provider != "ollama"
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
let runtime_model_path_cell : RuntimeModelPathCell = {
  path: ".mukuro/config.json",
}

///|
pub fn set_runtime_model_config_path_for_process(path : String) -> Unit {
  runtime_model_path_cell.path = path
}

///|
fn default_runtime_model_config() -> RuntimeModelConfig {
  {
    provider: "anthropic",
    api_key: "",
    model: default_model_for("anthropic"),
    base_url: "",
    use_responses_api: false,
  }
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
      let model = match obj.get("model") {
        Some(String(s)) => s
        _ =>
          match obj.get("default_model") {
            Some(String(s)) => s
            _ => default_model_for(provider)
          }
      }
      let base_url = match obj.get("base_url") {
        Some(String(s)) => s
        _ => ""
      }
      let use_responses_api = match obj.get("use_responses_api") {
        Some(True) => true
        _ => false
      }
      { provider, api_key, model, base_url, use_responses_api }
    }
    _ => default_runtime_model_config()
  }
}

///|
fn load_runtime_model_config() -> RuntimeModelConfig {
  let path = runtime_model_path_cell.path
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
fn build_openai_responses_body_impl(
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
) -> Json {
  let input_items : Array[Json] = []
  for msg in messages {
    match msg {
      @types.ModelMessage::System(content) =>
        input_items.push({
          "role": "system",
          "content": Json::array([{ "type": "input_text", "text": content }]),
        })
      @types.ModelMessage::User(content~, ..) =>
        input_items.push({
          "role": "user",
          "content": Json::array([{ "type": "input_text", "text": content }]),
        })
      @types.ModelMessage::Assistant(content~, ..) =>
        input_items.push({
          "role": "assistant",
          "content": Json::array([{ "type": "output_text", "text": content }]),
        })
      @types.ModelMessage::ToolResult(content~, ..) =>
        input_items.push({
          "role": "user",
          "content": Json::array([{ "type": "input_text", "text": content }]),
        })
    }
  }
  {
    "model": select_model_name(orchestrator, options),
    "input": Json::array(input_items),
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
fn parse_openai_responses_response(body : String) -> @types.ModelResponse {
  let json : Json = @json.parse(body) catch {
    _ =>
      return @types.ModelResponse::ModelError(
        "Invalid OpenAI Responses response JSON",
      )
  }
  match json {
    { "output_text": String(text), .. } =>
      if text.length() == 0 {
        @types.ModelResponse::ModelError(
          "OpenAI Responses response missing output_text",
        )
      } else {
        @types.ModelResponse::Text(text)
      }
    { "output": Array(items), .. } => {
      let mut found_text = ""
      let mut i = 0
      while i < items.length() && found_text.length() == 0 {
        match items[i] {
          { "content": Array(contents), .. } => {
            let mut j = 0
            while j < contents.length() && found_text.length() == 0 {
              match contents[j] {
                { "text": String(t), .. } =>
                  if t.length() > 0 {
                    found_text = t
                  } else {
                    ()
                  }
                _ => ()
              }
              j = j + 1
            }
          }
          _ => ()
        }
        i = i + 1
      }
      if found_text.length() == 0 {
        @types.ModelResponse::ModelError(
          "OpenAI Responses response has no textual output",
        )
      } else {
        @types.ModelResponse::Text(found_text)
      }
    }
    _ =>
      @types.ModelResponse::ModelError(
        "OpenAI Responses response shape is invalid",
      )
  }
}

///|
fn normalize_base_url(base_url : String, default_url : String) -> String {
  let trimmed = base_url.trim(chars=" \t\n\r").to_string()
  if trimmed.length() == 0 {
    default_url
  } else if trimmed.has_suffix("/") {
    trimmed.unsafe_substring(start=0, end=trimmed.length() - 1)
  } else {
    trimmed
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
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  if orchestrator.api_key.length() > 0 {
    headers["Authorization"] = "Bearer \{orchestrator.api_key}"
  }
  let body = (if orchestrator.use_responses_api {
    build_openai_responses_body_impl(orchestrator, messages, options)
  } else {
    build_openai_body_impl(orchestrator, messages, options)
  }).stringify()
  let default_base = match orchestrator.provider {
    "groq" => "https://api.groq.com/openai"
    "ollama" => "http://127.0.0.1:11434"
    _ => "https://api.openai.com"
  }
  let base = normalize_base_url(orchestrator.base_url, default_base)
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
  let response = orchestrator.http_client.do_request(req) catch {
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
  parse_anthropic_response(body_bytes_to_string(response.body))
}

///|
async fn call_openai_async_impl(
  orchestrator : RuntimeModelOrchestrator,
  messages : Array[@types.ModelMessage],
  options : @types.ModelOptions,
) -> @types.ModelResponse {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  if orchestrator.api_key.length() > 0 {
    headers["Authorization"] = "Bearer \{orchestrator.api_key}"
  }
  let body = (if orchestrator.use_responses_api {
    build_openai_responses_body_impl(orchestrator, messages, options)
  } else {
    build_openai_body_impl(orchestrator, messages, options)
  }).stringify()
  let default_base = match orchestrator.provider {
    "groq" => "https://api.groq.com/openai"
    "ollama" => "http://127.0.0.1:11434"
    _ => "https://api.openai.com"
  }
  let base = normalize_base_url(orchestrator.base_url, default_base)
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
) -> @types.ModelResponse {
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "x-api-key": orchestrator.api_key,
    "anthropic-version": "2023-06-01",
  }
  let body = build_anthropic_body_impl(orchestrator, messages, options).stringify()
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
  ignore(tools)
  let cfg = load_runtime_model_config()
  let runtime : RuntimeModelOrchestrator = {
    provider: cfg.provider,
    api_key: cfg.api_key,
    model: cfg.model,
    base_url: cfg.base_url,
    use_responses_api: cfg.use_responses_api,
    http_client: @native.NativeHttpClient::default(),
  }
  if provider_requires_api_key(runtime.provider) && runtime.api_key.is_empty() {
    return @types.ModelResponse::ModelError(
      "API key is not configured for provider: \{runtime.provider}. Run `mukuro onboard` to create .mukuro/config.json",
    )
  }
  if is_openai_compatible_provider(runtime.provider) {
    call_openai_async_impl(runtime, messages, options)
  } else {
    call_anthropic_async_impl(runtime, messages, options)
  }
}

///|
pub impl @interfaces.ModelOrchestrator for RuntimeModelOrchestrator with call(
  self,
  messages~,
  tools~,
  options~,
) {
  ignore(tools)
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
  // APIキー未設定時は明示エラー
  if provider_requires_api_key(runtime.provider) && runtime.api_key.is_empty() {
    return @types.ModelResponse::ModelError(
      "API key is not configured for provider: \{runtime.provider}. Run `mukuro onboard` to create .mukuro/config.json",
    )
  }
  if is_openai_compatible_provider(runtime.provider) {
    call_openai_impl(runtime, messages, options)
  } else {
    call_anthropic_impl(runtime, messages, options)
  }
}
