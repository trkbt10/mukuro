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
  // デフォルトモデルはオプション
  let default_model = opts.default_model.unwrap_or("")
  // 出力パスのデフォルト
  let output_path = opts.output_path.unwrap_or(default_runtime_config_path())
  // 設定JSONを構築（実際の値を補間）
  let config_json = "{\n  \"provider\": \"\{provider}\",\n  \"api_key\": \"\{api_key}\",\n  \"default_model\": \"\{default_model}\"\n}"
  execute_onboard_impl(
    provider, api_key, default_model, output_path, config_json,
  )
}
