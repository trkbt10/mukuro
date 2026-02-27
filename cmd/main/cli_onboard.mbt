///|
/// CLI Onboard Command
/// Configuration initialization

///|
/// オンボーディングを実行
pub fn execute_onboard(opts : OnboardOptions) -> CliResult {
  // プロバイダの確認
  let provider = match opts.provider {
    Some(p) => p
    None => return CliResult::Error("Missing required option: --provider")
  }
  // APIキーの確認
  let api_key = match opts.api_key {
    Some(k) => k
    None => return CliResult::Error("Missing required option: --api-key")
  }
  // デフォルトモデルはオプション (use provider-specific default if empty)
  let default_model = match opts.default_model {
    Some(m) if not(m.is_empty()) => m
    _ =>
      match provider {
        "anthropic" => "claude-sonnet-4-20250514"
        "openai" => "gpt-4o"
        _ => "default"
      }
  }
  // 出力パスのデフォルト
  let output_path = opts.output_path.unwrap_or(default_runtime_config_path())
  // 設定JSONを新しいproviders配列形式で構築
  let config_json =
    $|{
    $|  "providers": [
    $|    {
    $|      "name": "\{provider}",
    $|      "api_key": "\{api_key}",
    $|      "default_model": "\{default_model}"
    $|    }
    $|  ]
    $|}
  execute_onboard_impl(
    provider, api_key, default_model, output_path, config_json,
  )
}
