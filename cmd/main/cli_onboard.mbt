///|
/// CLI Onboard Command
/// Configuration initialization with provider presets, env detection, and merge

///|
/// オンボーディングを実行
pub async fn execute_onboard(opts : @cli.OnboardOptions) -> @cli.CliResult {
  let output_path = opts.output_path.unwrap_or(
    @cmd_config.default_runtime_config_path(),
  )
  // プロバイダ未指定の場合
  let provider = match opts.provider {
    Some(p) if not(p.is_empty()) => p
    _ => {
      // 他のオプションが指定されている場合は非対話的エラー
      // (e.g., `mukuro onboard --api-key sk-xxx` は --provider が必要)
      if opts.api_key is Some(_) ||
        opts.default_model is Some(_) ||
        opts.base_url is Some(_) {
        return @cli.CliResult::Error(
          "--provider is required when specifying --api-key, --model, or --base-url",
        )
      }
      // オプションなし: 対話的ウィザードを起動
      return execute_onboard_list(output_path)
    }
  }
  // プロバイダ指定あり: 非対話的実行
  execute_onboard_impl(
    provider,
    api_key=opts.api_key,
    default_model=opts.default_model,
    base_url=opts.base_url,
    output_path,
    reset=opts.reset,
  )
}
