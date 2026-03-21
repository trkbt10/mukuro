///|
/// CLI Onboard Command
/// Configuration initialization with provider presets, env detection, and merge

///|
/// オンボーディングを実行
pub fn execute_onboard(opts : @cli.OnboardOptions) -> @cli.CliResult {
  let output_path = opts.output_path.unwrap_or(
    @cmd_config.default_runtime_config_path(),
  )
  // プロバイダ未指定の場合: 対話的ウィザードを起動
  let provider = match opts.provider {
    Some(p) if not(p.is_empty()) => p
    _ => return execute_onboard_list(output_path)
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
