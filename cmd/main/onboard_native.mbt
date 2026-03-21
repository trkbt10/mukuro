///|
/// Onboard実装（Native専用）
/// IO 依存のロジックのみ配置。
/// プリセット定義・マージロジック・ガイダンス構築は cmd/cli/onboard_presets.mbt に配置。

// =============================================================================
// 標準入出力ヘルパー
// =============================================================================

///|
/// stdout に書き込み
fn onboard_write(text : String) -> Unit {
  let data = @utf8.encode(text.view())
  let _ = @native.c_write_stdout(data, data.length())

}

///|
/// stdout をフラッシュ
fn onboard_flush() -> Unit {
  let _ = @native.c_fflush_stdout()

}

///|
/// stdin から 1 行読み取り（改行除去済み）
fn onboard_read_line() -> String? {
  let buffer = Bytes::new(8192)
  let bytes_read = @native.c_read_stdin_line(buffer, 8192)
  if bytes_read <= 0 {
    return None
  }
  match @bytes.decode_utf8(buffer[:bytes_read]) {
    Some(s) => Some(s.trim(chars=" \t\r\n").to_string())
    None => None
  }
}

///|
/// プロンプトを表示して 1 行読み取り
fn prompt(message : String) -> String? {
  onboard_write(message)
  onboard_flush()
  onboard_read_line()
}

///|
/// y/N 確認プロンプト（デフォルト N）
fn confirm(message : String) -> Bool {
  match prompt(message + " [y/N] ") {
    Some(s) => {
      let lower = s.to_lower()
      lower == "y" || lower == "yes"
    }
    None => false
  }
}

// =============================================================================
// 環境変数からの API キー検出
// =============================================================================

///|
/// 環境変数から API キーを取得（UTF-8 Bytes FFI 経由、NULL安全）
fn native_getenv(name : String) -> String? {
  let name_bytes = @bytes.to_utf8_cstring(name)
  let buffer_len = 4096
  let buffer = Bytes::new(buffer_len)
  let result = @native.c_getenv_bytes(name_bytes, buffer, buffer_len)
  if result < 0 {
    return None
  }
  match @bytes.decode_utf8(buffer[:result]) {
    Some(s) => if s.is_empty() { None } else { Some(s) }
    None => None
  }
}

///|
/// プリセットの env_var に基づいて環境変数から API キーを検出
fn detect_api_key_from_env(preset : @cli.ProviderPreset) -> String? {
  match preset.env_var {
    Some(var_name) => native_getenv(var_name)
    None => None
  }
}

///|
/// 環境変数で検出されたプロバイダーの配列を返す
fn detect_env_providers() -> Array[(@cli.ProviderPreset, String)] {
  let result : Array[(@cli.ProviderPreset, String)] = []
  for preset in @cli.known_provider_presets() {
    match detect_api_key_from_env(preset) {
      Some(key) => result.push((preset, key))
      None => ()
    }
  }
  result
}

///|
/// 環境変数で検出されたプロバイダー一覧を表示文字列で返す
fn format_detected_env_keys() -> String {
  let buf = StringBuilder::new()
  let detected = detect_env_providers()
  if detected.is_empty() {
    buf.write_string("No API keys detected from environment variables.\n")
  } else {
    buf.write_string("Detected API keys from environment:\n")
    for entry in detected {
      let (preset, _) = entry
      let var_name = preset.env_var.unwrap()
      buf.write_string("  - \{preset.name} (\{var_name})\n")
    }
  }
  buf.to_string()
}

// =============================================================================
// 既存設定の読み込み
// =============================================================================

///|
/// 既存の設定ファイルを読み込み（存在しない場合は None）
fn read_existing_config(config_path : String) -> @types.MukuroConfig? {
  let content = @native.native_read_file_text(config_path) catch {
    _ => return None
  }
  if content.length() == 0 {
    return None
  }
  let loader = @config.ConfigLoaderImpl::default()
  let config = loader.load_from_string(content) catch {
    _ => return None
  }
  Some(config)
}

// =============================================================================
// 設定ファイルの書き込み
// =============================================================================

///|
/// MukuroConfig を JSON 文字列に変換して書き込み
fn write_onboard_config(
  config : @types.MukuroConfig,
  output_path : String,
) -> Bool {
  let dir = extract_parent_dir(output_path)
  if dir.length() > 0 {
    ignore(
      @native.c_mkdir_recursive_bytes(@bytes.to_utf8_cstring(dir), 493),
    )
  }
  let json = config.to_json()
  let content = json.stringify(indent=2)
  @native.c_write_text_file_bytes(
    @native.string_to_utf8_cstring(output_path),
    @native.string_to_utf8_cstring(content),
  ) == 0
}

///|
/// パスから親ディレクトリを抽出
fn extract_parent_dir(path : String) -> String {
  let mut last_sep = -1
  let mut i = 0
  for c in path {
    if c == '/' {
      last_sep = i
    }
    i = i + 1
  }
  if last_sep > 0 {
    path.substring(start=0, end=last_sep)
  } else {
    ""
  }
}

// =============================================================================
// 対話的オンボーディングウィザード
// =============================================================================

///|
/// 対話的オンボーディングウィザード
/// openclaw の interactive setup と nemoclaw の y/N 確認パターンの交差
pub fn execute_onboard_interactive(output_path : String) -> @cli.CliResult {
  onboard_write("mukuro onboard — Interactive setup\n\n")
  // 既存設定の確認
  let existing = read_existing_config(output_path)
  match existing {
    Some(config) => {
      let provider_count = config.providers.length()
      onboard_write(
        "Existing configuration found (\{provider_count} provider(s)).\n",
      )
      if not(confirm("Add or update a provider?")) {
        return @cli.CliResult::Ok("Onboarding cancelled.")
      }
      onboard_write("\n")
    }
    None => ()
  }
  // 環境変数検出の表示
  let detected = detect_env_providers()
  if not(detected.is_empty()) {
    onboard_write("Detected API keys from environment:\n")
    for i, entry in detected {
      let (preset, _) = entry
      let var_name = preset.env_var.unwrap()
      onboard_write("  \{i + 1}. \{preset.name} (\{var_name})\n")
    }
    onboard_write("\n")
  }
  // プロバイダー一覧を表示
  let presets = @cli.known_provider_presets()
  onboard_write("Available providers:\n")
  for i, preset in presets {
    let env_hint = match preset.env_var {
      Some(v) => {
        let has_key = native_getenv(v) is Some(_)
        if has_key { " * key detected" } else { "" }
      }
      None => " (no key needed)"
    }
    onboard_write("  \{i + 1}. \{preset.name}\{env_hint}\n")
  }
  onboard_write("\n")
  // プロバイダー選択
  let provider_input = match prompt("Select provider (number or name): ") {
    Some(s) if not(s.is_empty()) => s
    _ => return @cli.CliResult::Ok("Onboarding cancelled.")
  }
  // 番号またはプロバイダー名を解決
  let selected_name = resolve_provider_input(provider_input, presets)
  let preset = @cli.find_preset(selected_name)
  let model = match preset {
    Some(p) => p.default_model
    None => "default"
  }
  onboard_write("\n")
  onboard_write("Provider: \{selected_name}\n")
  onboard_write("Model:    \{model}\n")
  // API キーの取得: env var → 手入力
  let mut api_key : String? = None
  let mut env_detected = false
  match preset {
    Some(p) =>
      match detect_api_key_from_env(p) {
        Some(key) => {
          let masked = mask_key(key)
          onboard_write("API key:  \{masked} (from env)\n")
          api_key = Some(key)
          env_detected = true
        }
        None => ()
      }
    None => ()
  }
  if not(env_detected) {
    match preset {
      Some(p) if p.env_var is None =>
        // ollama 等: キー不要
        onboard_write("API key:  (not required)\n")
      _ => {
        let key_input = match prompt("API key: ") {
          Some(s) if not(s.is_empty()) => s
          _ => {
            onboard_write("No API key provided. You can add it later.\n")
            ""
          }
        }
        if not(key_input.is_empty()) {
          api_key = Some(key_input)
        }
      }
    }
  }
  // ベース URL（プリセットにない場合のみ）
  let base_url : String? = match preset {
    Some(_) => preset.unwrap().base_url
    None => {
      let url_input = match prompt("Base URL (OpenAI-compatible endpoint): ") {
        Some(s) if not(s.is_empty()) => Some(s)
        _ => None
      }
      url_input
    }
  }
  onboard_write("\n")
  // 確認
  let key_display = match api_key {
    Some(k) => mask_key(k)
    None => "(not set)"
  }
  let url_display = match base_url {
    Some(u) => u
    None => "(default)"
  }
  onboard_write("Summary:\n")
  onboard_write("  Provider:  \{selected_name}\n")
  onboard_write("  Model:     \{model}\n")
  onboard_write("  API Key:   \{key_display}\n")
  onboard_write("  Base URL:  \{url_display}\n")
  onboard_write("  Config:    \{output_path}\n\n")
  if not(confirm("Save this configuration?")) {
    return @cli.CliResult::Ok("Onboarding cancelled.")
  }
  // 保存
  execute_onboard_impl(
    selected_name,
    api_key~,
    default_model=None,
    base_url~,
    output_path,
    reset=false,
  )
}

///|
/// 番号またはプロバイダー名を解決
fn resolve_provider_input(
  input : String,
  presets : Array[@cli.ProviderPreset],
) -> String {
  // 数値として解釈
  let parsed : Json = @json.parse(input) catch { _ => Json::null() }
  match parsed {
    Number(n, ..) => {
      let idx = n.to_int() - 1
      if idx >= 0 && idx < presets.length() {
        return presets[idx].name
      }
    }
    _ => ()
  }
  // そのまま名前として使用
  input.to_lower()
}

///|
/// API キーをマスク表示（先頭4文字 + ... + 末尾4文字）
fn mask_key(key : String) -> String {
  let chars : Array[Char] = []
  for c in key {
    chars.push(c)
  }
  if chars.length() <= 8 {
    return "****"
  }
  let buf = StringBuilder::new()
  for i in 0..<4 {
    buf.write_char(chars[i])
  }
  buf.write_string("...")
  for i in (chars.length() - 4)..<chars.length() {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

// =============================================================================
// 非対話的（フラグ指定）オンボーディング実行
// =============================================================================

///|
pub fn execute_onboard_impl(
  provider : String,
  api_key~ : String?,
  default_model~ : String?,
  base_url~ : String?,
  output_path : String,
  reset~ : Bool,
) -> @cli.CliResult {
  let preset = @cli.find_preset(provider)
  // モデルの決定: 引数 > プリセット > "default"
  let model = match default_model {
    Some(m) if not(m.is_empty()) => m
    _ =>
      match preset {
        Some(p) => p.default_model
        None => "default"
      }
  }
  // ベース URL の決定: 引数 > プリセット > None
  let resolved_base_url : String? = match base_url {
    Some(u) if not(u.is_empty()) => Some(u)
    _ =>
      match preset {
        Some(p) => p.base_url
        None => None
      }
  }
  // API キーの決定: 引数 > 環境変数 > None
  let resolved_api_key : String? = match api_key {
    Some(k) if not(k.is_empty()) => Some(k)
    _ =>
      match preset {
        Some(p) => detect_api_key_from_env(p)
        None => None
      }
  }
  // ProviderConfig を構築
  let new_provider : @types.ProviderConfig = {
    name: provider.to_lower(),
    api_key: resolved_api_key,
    base_url: resolved_base_url,
    default_model: model,
    timeout_ms: 30000,
    max_retries: 3,
    use_responses_api: false,
    use_harmony_parser: false,
  }
  // 既存設定の確認（reset でも非対話でもなく、既存設定がある場合に上書き確認）
  let config = if reset {
    let default_config = @config.ConfigLoaderImpl::default().default_config()
    @cli.merge_provider_into_config(
      { ..default_config, providers: [], },
      new_provider,
    )
  } else {
    match read_existing_config(output_path) {
      Some(existing) =>
        @cli.merge_provider_into_config(existing, new_provider)
      None => {
        let default_config = @config.ConfigLoaderImpl::default().default_config()
        @cli.merge_provider_into_config(
          { ..default_config, providers: [], },
          new_provider,
        )
      }
    }
  }
  // 書き込み
  if not(write_onboard_config(config, output_path)) {
    return @cli.CliResult::Error(
      "Failed to write configuration file: \{output_path}",
    )
  }
  // データディレクトリの作成を保証
  let data_dir = @config.data_dir()
  ignore(
    @native.c_mkdir_recursive_bytes(@bytes.to_utf8_cstring(data_dir), 493),
  )
  // ガイダンスを表示
  let api_key_set = resolved_api_key is Some(_)
  let guidance = @cli.build_post_onboard_guidance(
    new_provider.name, model, output_path, api_key_set,
  )
  // 環境変数検出情報を付加
  let env_info = match (api_key, resolved_api_key) {
    (None, Some(_)) | (Some(""), Some(_)) => {
      let var_name = match preset {
        Some(p) => p.env_var.unwrap_or("(unknown)")
        None => "(unknown)"
      }
      "\nAPI key detected from environment variable: \{var_name}\n"
    }
    _ => ""
  }
  @cli.CliResult::Ok(env_info + guidance)
}

///|
/// 引数なしの onboard: 対話的ウィザードを起動
pub fn execute_onboard_list(output_path : String) -> @cli.CliResult {
  execute_onboard_interactive(output_path)
}
