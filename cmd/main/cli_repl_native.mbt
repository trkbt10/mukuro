///|
/// CLI Agent REPL - 対話型エージェント実行
/// `mukuro agent` で REPL モード、`mukuro agent -m "query"` で単発実行

///|
/// Agent コマンドを実行
async fn execute_agent_command(opts : @cli.AgentOptions) -> @cli.CliResult {
  // 設定ファイルを読み込み (gateway start と同じパターンを使用)
  let config_path = opts.config_path.unwrap_or(
    @cmd_config.default_runtime_config_path(),
  )
  let config_text = @cmd_config.read_config_text_impl(config_path) catch {
    _ =>
      return @cli.CliResult::Error(
        "Configuration not found at \{config_path}. Run 'mukuro onboard' first.",
      )
  }
  let mukuro_config = @config.ConfigLoaderImpl::default().load_from_string(
    config_text,
  ) catch {
    _ =>
      return @cli.CliResult::Error(
        "Failed to parse configuration: \{config_path}",
      )
  }
  init_api_v1_state(mukuro_config, config_path)
  match opts.message {
    Some(msg) => execute_agent_single(msg)
    None => execute_agent_repl()
  }
}

///|
/// 単発実行: メッセージを1回送信してレスポンスを表示
async fn execute_agent_single(message : String) -> @cli.CliResult {
  let envelope : @types.InboundEnvelope = {
    ..@types.InboundEnvelope::default(),
    channel: "cli",
    chat_id: "cli_single",
    sender_id: "user",
    sender_name: "user",
    content: message,
  }
  let result = handle_inbound_with_agent_loop(envelope, None) catch {
    e => return @cli.CliResult::Error("Agent error: \{e}")
  }
  @cli.CliResult::Ok(result.content)
}

///|
/// REPL モード: stdin から入力を読み取り、エージェントに送信
async fn execute_agent_repl() -> @cli.CliResult {
  @stdio.stdout.write("mukuro agent v\{@cli.version} - Type your message (Ctrl+D to exit)\n")
  while true {
    @stdio.stdout.write("\n> ")
    let line = @stdio.stdin.read_until("\n")
    match line {
      None => break // EOF (Ctrl+D)
      Some(input) => {
        let trimmed = input.trim(chars=" \t\r\n").to_string()
        if trimmed.is_empty() {
          continue
        }
        if trimmed == "/quit" || trimmed == "/exit" {
          break
        }
        let envelope : @types.InboundEnvelope = {
          ..@types.InboundEnvelope::default(),
          channel: "cli",
          chat_id: "cli_repl",
          sender_id: "user",
          sender_name: "user",
          content: trimmed,
        }
        let result = handle_inbound_with_agent_loop(envelope, None) catch {
          e => {
            @stdio.stdout.write("Error: \{e}\n")
            continue
          }
        }
        @stdio.stdout.write("\n")
        @stdio.stdout.write(result.content)
        @stdio.stdout.write("\n")
      }
    }
  }
  @cli.CliResult::Ok("Goodbye!")
}
