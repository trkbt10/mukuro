///|
/// オンボーディング: プロバイダープリセットとマージロジック
/// IO に依存しない純粋関数のみ（テスト可能）

///|
/// プロバイダープリセット
pub(all) struct ProviderPreset {
  /// プロバイダー名（config.json の name フィールド）
  name : String
  /// デフォルトモデル
  default_model : String
  /// ベース URL（None の場合はプロバイダー固有のデフォルト）
  base_url : String?
  /// API キーの環境変数名（None の場合はキー不要: ローカルモデル等）
  env_var : String?
}

///|
/// 既知プロバイダー一覧
/// openclaw と nemoclaw の両方でサポートされているプロバイダー
pub fn known_provider_presets() -> Array[ProviderPreset] {
  [
    {
      name: "anthropic",
      default_model: "claude-sonnet-4-20250514",
      base_url: None,
      env_var: Some("ANTHROPIC_API_KEY"),
    },
    {
      name: "openai",
      default_model: "gpt-4o",
      base_url: Some("https://api.openai.com/v1"),
      env_var: Some("OPENAI_API_KEY"),
    },
    {
      name: "gemini",
      default_model: "gemini-2.0-flash",
      base_url: None,
      env_var: Some("GEMINI_API_KEY"),
    },
    {
      name: "deepseek",
      default_model: "deepseek-chat",
      base_url: Some("https://api.deepseek.com/v1"),
      env_var: Some("DEEPSEEK_API_KEY"),
    },
    {
      name: "groq",
      default_model: "llama-3.3-70b-versatile",
      base_url: Some("https://api.groq.com/openai/v1"),
      env_var: Some("GROQ_API_KEY"),
    },
    {
      name: "openrouter",
      default_model: "openrouter/auto",
      base_url: None,
      env_var: Some("OPENROUTER_API_KEY"),
    },
    {
      name: "ollama",
      default_model: "llama3.2",
      base_url: Some("http://localhost:11434/v1"),
      env_var: None,
    },
    {
      name: "moonshot",
      default_model: "moonshot-v1-auto",
      base_url: Some("https://api.moonshot.cn/v1"),
      env_var: Some("MOONSHOT_API_KEY"),
    },
  ]
}

///|
/// プリセットからプロバイダー名で検索
pub fn find_preset(name : String) -> ProviderPreset? {
  let lower = name.to_lower()
  for preset in known_provider_presets() {
    if preset.name == lower {
      return Some(preset)
    }
  }
  None
}

///|
/// プロバイダー一覧の表示文字列を構築
pub fn format_provider_list() -> String {
  let buf = StringBuilder::new()
  buf.write_string("Available providers:\n")
  for preset in known_provider_presets() {
    let env_hint = match preset.env_var {
      Some(v) => " (\{v})"
      None => " (no key needed)"
    }
    buf.write_string("  - \{preset.name}: \{preset.default_model}\{env_hint}\n")
  }
  buf.to_string()
}

///|
/// 既存設定にプロバイダーをマージ
/// 同名のプロバイダーが存在する場合は更新、存在しない場合は追加
pub fn merge_provider_into_config(
  config : @types.MukuroConfig,
  provider : @types.ProviderConfig,
) -> @types.MukuroConfig {
  let new_providers : Array[@types.ProviderConfig] = []
  let mut replaced = false
  for p in config.providers {
    if p.name == provider.name {
      new_providers.push(provider)
      replaced = true
    } else {
      new_providers.push(p)
    }
  }
  if not(replaced) {
    new_providers.push(provider)
  }
  { ..config, providers: new_providers }
}

///|
/// オンボーディング完了後のガイダンスを構築
pub fn build_post_onboard_guidance(
  provider_name : String,
  model : String,
  output_path : String,
  api_key_set : Bool,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("Configuration written successfully.\n\n")
  buf.write_string("  Provider: \{provider_name}\n")
  buf.write_string("  Model:    \{model}\n")
  buf.write_string("  Config:   \{output_path}\n\n")
  if not(api_key_set) {
    let preset = find_preset(provider_name)
    let env_hint = match preset {
      Some(p) =>
        match p.env_var {
          Some(v) =>
            "\n  Or set the environment variable: export \{v}=<your-key>"
          None => ""
        }
      None => ""
    }
    buf.write_string("Next steps:\n")
    buf.write_string(
      "  1. Add your API key:\n     mukuro onboard --provider \{provider_name} --api-key <your-key>\{env_hint}\n",
    )
    buf.write_string("  2. Start the agent:\n     mukuro agent -m \"Hello!\"\n")
  } else {
    buf.write_string("Next steps:\n")
    buf.write_string("  Start the agent:  mukuro agent -m \"Hello!\"\n")
    buf.write_string("  Start the gateway: mukuro gateway\n")
    buf.write_string("  View providers:   mukuro config providers\n")
  }
  buf.to_string()
}
