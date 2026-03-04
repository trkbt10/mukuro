///|
/// Onboard API — オンボーディング状態管理とコンテキストファイル生成
///
/// Source of Truth: workspace-state.json
/// - status フィールドが明示的に状態を保持
/// - BOOTSTRAP.md の存在は補助情報

// =============================================================================
// Onboard State (Single Source of Truth)
// =============================================================================

///| 状態ファイルパス
fn onboard_state_path() -> String {
  @config.data_dir() + "/.mukuro/onboard-state.json"
}

///| 状態ディレクトリパス
fn onboard_state_dir() -> String {
  @config.data_dir() + "/.mukuro"
}

///| オンボーディング状態を読み込み
fn load_onboard_state() -> Json {
  let path = onboard_state_path()
  let content = @native.native_read_file_text(path) catch {
    _ => return {}
  }
  if content.length() == 0 {
    return {}
  }
  @json.parse(content) catch {
    _ => {}
  }
}

///| オンボーディング状態を保存
fn save_onboard_state(state : Json) -> Bool {
  // ディレクトリを作成
  let dir = onboard_state_dir()
  ignore(
    @native.c_mkdir_recursive_bytes(@bytes.to_utf8_cstring(dir), 493),
  ) // 0o755
  // ファイルに書き込み
  let path = onboard_state_path()
  let content = state.stringify()
  @native.c_write_text_file_bytes(
    @native.string_to_utf8_cstring(path),
    @native.string_to_utf8_cstring(content),
  ) == 0
}

///| エポック秒を文字列として取得（ISO8601より確実）
fn get_epoch_timestamp() -> String {
  let epoch = @native.c_time()
  epoch.to_string()
}

// =============================================================================
// Onboard Status API
// =============================================================================

///|
/// GET /api/v1/onboard/status — オンボーディング状態を取得
fn try_onboard_status() -> ControlApiResponse {
  // プロバイダの設定状態を確認
  let has_provider = match api_v1_settings_state.get_config() {
    Some(config) => config.providers.iter().any(fn(p) { p.api_key is Some(_) })
    None => false
  }
  // Source of Truth: 状態ファイルから読み込み
  let state = load_onboard_state()
  let status = match state {
    { "status": String(s), .. } => s
    _ =>
      // 状態未初期化の場合、プロバイダの有無で判定
      if has_provider { "in_progress" } else { "not_started" }
  }
  json_response(200, {
    "data": {
      "status": status,
      "has_provider": Json::boolean(has_provider),
    },
  })
}

///|
/// POST /api/v1/onboard/start — オンボーディングを開始
fn try_onboard_start() -> ControlApiResponse {
  let state = load_onboard_state()
  // すでに完了済みの場合はエラー
  match state {
    { "status": String("completed"), .. } =>
      return json_response(400, {
        "error": "already_completed",
        "message": "Onboarding already completed",
      })
    _ => ()
  }
  // 状態を in_progress に更新
  let now = get_epoch_timestamp()
  let new_state : Json = {
    "status": "in_progress",
    "started_at": now,
  }
  if not(save_onboard_state(new_state)) {
    return json_response(500, {
      "error": "save_failed",
      "message": "Failed to save onboard state",
    })
  }
  json_response(200, { "data": { "status": "in_progress", "started_at": now } })
}

///|
/// POST /api/v1/onboard/complete — オンボーディングを完了
fn try_onboard_complete() -> ControlApiResponse {
  let state = load_onboard_state()
  // すでに完了済みの場合は成功を返す
  match state {
    { "status": String("completed"), "completed_at": String(t), .. } =>
      return json_response(200, {
        "data": { "status": "completed", "completed_at": t },
      })
    _ => ()
  }
  // 状態を completed に更新
  let now = get_epoch_timestamp()
  let started_at = match state {
    { "started_at": String(t), .. } => Json::string(t)
    _ => Json::null()
  }
  let new_state : Json = {
    "status": "completed",
    "started_at": started_at,
    "completed_at": now,
  }
  if not(save_onboard_state(new_state)) {
    return json_response(500, {
      "error": "save_failed",
      "message": "Failed to save onboard state",
    })
  }
  // bootstrap.md を削除（存在する場合）
  // Source of truth: @api_context.ContextFileType::Bootstrap.filename()
  let bootstrap_filename = @api_context.ContextFileType::Bootstrap.filename()
  let bootstrap_path = @config.data_dir() + "/" + bootstrap_filename
  let bootstrap_exists = @native.c_access_bytes(
    @bytes.to_utf8_cstring(bootstrap_path),
    0,
  ) == 0
  if bootstrap_exists {
    ignore(@native.c_remove_bytes(@bytes.to_utf8_cstring(bootstrap_path)))
  }
  json_response(200, { "data": { "status": "completed", "completed_at": now } })
}

// =============================================================================
// Onboard Generate API
// =============================================================================

///|
/// POST /api/v1/onboard/generate — LLMでコンテキストファイルを生成
async fn try_onboard_generate(body : String) -> ControlApiResponse {
  let json : Json = @json.parse(body) catch {
    _ =>
      return json_response(400, {
        "error": "invalid_json",
        "message": "Invalid JSON body",
      })
  }
  let user_name = match json {
    { "user_name": String(v), .. } => v
    _ => ""
  }
  let work = match json {
    { "work": String(v), .. } => v
    _ => ""
  }
  let personality = match json {
    { "personality": String(v), .. } => v
    _ => ""
  }
  let notes = match json {
    { "notes": String(v), .. } => v
    _ => ""
  }
  if user_name.is_empty() && work.is_empty() && personality.is_empty() {
    return json_response(400, {
      "error": "missing_input",
      "message": "At least one of user_name, work, or personality is required",
    })
  }
  // 設定済みプロバイダを取得（APIキーがあるもの）
  let config = match api_v1_settings_state.get_config() {
    Some(c) => c
    None =>
      return json_response(503, {
        "error": "not_configured",
        "message": "No providers configured",
      })
  }
  let mut provider : @types.ProviderConfig? = None
  for p in config.providers {
    match p.api_key {
      Some(_) => {
        provider = Some(p)
        break
      }
      None => ()
    }
  }
  let p = match provider {
    Some(p) => p
    None =>
      return json_response(503, {
        "error": "no_api_key",
        "message": "No provider has an API key configured",
      })
  }
  let prompt = build_onboard_generation_prompt(
    user_name, work, personality, notes,
  )
  let result = call_onboard_llm(p, prompt)
  match result {
    @types.ModelResponse::Text(text) => {
      let files = parse_onboard_generated_text(text)
      json_response(200, { "data": files })
    }
    @types.ModelResponse::ModelError(msg) =>
      json_response(502, {
        "error": "llm_error",
        "message": Json::string("LLM call failed: " + msg),
      })
    _ =>
      json_response(502, {
        "error": "llm_error",
        "message": "Unexpected LLM response format",
      })
  }
}

///|
/// オンボーディング生成プロンプトを構築
fn build_onboard_generation_prompt(
  user_name : String,
  work : String,
  personality : String,
  notes : String,
) -> String {
  let name_part = if user_name.is_empty() {
    "(not provided)"
  } else {
    user_name
  }
  let work_part = if work.is_empty() { "(not provided)" } else { work }
  let personality_part = if personality.is_empty() {
    "(not provided)"
  } else {
    personality
  }
  let notes_part = if notes.is_empty() { "(none)" } else { notes }
  let sb = StringBuilder::new()
  sb.write_string(
    "You are helping a user set up their AI assistant's workspace context files during onboarding.\n\nBased on the information below, generate content for ALL 6 context files. Be creative and reflect the user's personality and preferences.\n\n## User Information\n- Name: ",
  )
  sb.write_string(name_part)
  sb.write_string("\n- Work / Interests: ")
  sb.write_string(work_part)
  sb.write_string("\n- Preferred AI personality: ")
  sb.write_string(personality_part)
  sb.write_string("\n- Additional notes: ")
  sb.write_string(notes_part)
  sb.write_string(
    "\n\n## Output Format\nOutput each file between markers EXACTLY as shown. Do not add any text outside the markers.\n\n---SOUL---\n(Generate SOUL.md: AI personality, core values, tone, boundaries. Make it feel personal, not corporate.)\n---/SOUL---\n\n---IDENTITY---\n(Generate IDENTITY.md: Pick a name, creature type, vibe, and emoji that fits the user's preferences.)\n---/IDENTITY---\n\n---USER---\n(Generate USER.md: Fill in what you know about the user from their answers.)\n---/USER---\n\n---AGENTS---\n(Generate AGENTS.md: Workspace handbook - priorities, safety, when to ask vs act.)\n---/AGENTS---\n\n---TOOLS---\n(Generate TOOLS.md: Placeholder for local tools and environment notes based on user's work.)\n---/TOOLS---\n\n---BOOTSTRAP---\n(Generate BOOTSTRAP.md: First-run conversation guide. A brief script for the AI's first interaction with this user.)\n---/BOOTSTRAP---",
  )
  sb.to_string()
}

///|
/// LLMを直接呼び出す（ワンショット・ツールなし）
async fn call_onboard_llm(
  provider : @types.ProviderConfig,
  prompt : String,
) -> @types.ModelResponse {
  let api_key = match provider.api_key {
    Some(k) => k
    None => return @types.ModelResponse::ModelError("No API key")
  }
  let base_url = match provider.base_url {
    Some(url) => url
    None =>
      match get_default_provider_base_url(provider.name) {
        Some(url) => url
        None =>
          return @types.ModelResponse::ModelError(
            "No base URL for provider: " + provider.name,
          )
      }
  }
  let messages : Array[@types.ModelMessage] = [
    @types.ModelMessage::User(content=prompt, name=None),
  ]
  let empty_tools : Array[@types.ToolDefinition] = []
  let is_anthropic = provider.name == "anthropic" ||
    base_url.contains("anthropic")
  let body_json = if is_anthropic {
    @protocol.build_anthropic_body(
      provider.default_model,
      messages,
      empty_tools,
      max_tokens=Some(4096),
    )
  } else {
    @protocol.build_openai_chat_body(
      provider.default_model,
      messages,
      empty_tools,
      max_tokens=Some(4096),
    )
  }
  let req_headers : Map[String, String] = {}
  req_headers["Content-Type"] = "application/json"
  if is_anthropic {
    req_headers["x-api-key"] = api_key
    req_headers["anthropic-version"] = "2023-06-01"
  } else {
    req_headers["Authorization"] = "Bearer " + api_key
  }
  let url = if is_anthropic {
    if base_url.has_suffix("/") {
      base_url + "v1/messages"
    } else {
      base_url + "/v1/messages"
    }
  } else if base_url.has_suffix("/") {
    base_url + "v1/chat/completions"
  } else {
    base_url + "/v1/chat/completions"
  }
  let http = @native.NativeHttpClient::new(
    timeout_seconds=60,
    user_agent="mukuro/0.1.0",
  )
  let body_bytes = @utf8.encode(body_json.stringify())
  let response = http.do_request_async({
    url,
    http_method: @interfaces.HttpMethod::Post,
    headers: req_headers,
    body: Some(body_bytes),
  }) catch {
    _ => return @types.ModelResponse::ModelError("HTTP request failed")
  }
  if response.status < 200 || response.status >= 300 {
    let err_body = @bytes.decode_utf8_or(response.body[:], default="")
    return @types.ModelResponse::ModelError(
      "HTTP \{response.status}: " + err_body,
    )
  }
  let resp_str = @bytes.decode_utf8_or(response.body[:], default="")
  let resp_json : Json = @json.parse(resp_str) catch {
    _ => return @types.ModelResponse::ModelError("Invalid JSON response")
  }
  if is_anthropic {
    @protocol.parse_anthropic_response(resp_json)
  } else {
    @protocol.parse_openai_chat_response(resp_json)
  }
}

///|
/// 生成テキストをマーカーでパースしてJSON Objectに変換
fn parse_onboard_generated_text(text : String) -> Json {
  let files : Map[String, Json] = {}
  let sv = text[:]
  let markers = [
    ("soul", "---SOUL---", "---/SOUL---"),
    ("identity", "---IDENTITY---", "---/IDENTITY---"),
    ("user", "---USER---", "---/USER---"),
    ("agents", "---AGENTS---", "---/AGENTS---"),
    ("tools", "---TOOLS---", "---/TOOLS---"),
    ("bootstrap", "---BOOTSTRAP---", "---/BOOTSTRAP---"),
  ]
  for entry in markers {
    let (name, open, close) = entry
    match sv.find(open[:]) {
      Some(start) => {
        let content_start = start + open.length()
        match sv.find(close[:]) {
          Some(end) =>
            if end > content_start {
              let content = sv[content_start:end]
                .trim(chars=" \t\n\r")
                .to_string() catch {
                  _ => ""
                }
              if content.length() > 0 {
                files[name] = Json::string(content)
              }
            }
          None => ()
        }
      }
      None => ()
    }
  }
  Json::object(files)
}
