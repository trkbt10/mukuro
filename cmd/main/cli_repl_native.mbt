///|
/// CLI Agent REPL - 対話型エージェント実行
/// `mukuro agent` で REPL モード、`mukuro agent -m "query"` で単発実行

///|
/// Agent コマンドを実行
async fn execute_agent_command(opts : AgentOptions) -> CliResult {
  // 設定ファイルを読み込み (gateway start と同じパターンを使用)
  let config_path = opts.config_path.unwrap_or(default_runtime_config_path())
  let config_text = read_config_text_impl(config_path) catch {
    _ =>
      return CliResult::Error(
        "Configuration not found at \{config_path}. Run 'mukuro onboard' first.",
      )
  }
  let mukuro_config = @config.ConfigLoaderImpl::default().load_from_string(
    config_text,
  ) catch {
    _ =>
      return CliResult::Error(
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
async fn execute_agent_single(message : String) -> CliResult {
  let envelope : @types.InboundEnvelope = {
    ..@types.InboundEnvelope::default(),
    channel: "cli",
    chat_id: "cli_single",
    sender_id: "user",
    sender_name: "user",
    content: message,
  }
  let result = handle_inbound_with_agent_loop(envelope, None) catch {
    e => return CliResult::Error("Agent error: \{e}")
  }
  CliResult::Ok(result.content)
}

///|
/// REPL モード: stdin から入力を読み取り、エージェントに送信
async fn execute_agent_repl() -> CliResult {
  repl_write("mukuro agent v\{version} - Type your message (Ctrl+D to exit)\n")
  while true {
    repl_write("\n> ")
    repl_flush()
    let line = repl_read_line()
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
            repl_write("Error: \{e}\n")
            continue
          }
        }
        repl_write("\n")
        repl_write(result.content)
        repl_write("\n")
      }
    }
  }
  CliResult::Ok("Goodbye!")
}

///|
fn repl_read_line() -> String? {
  let buffer = Bytes::new(8192)
  let bytes_read = @native.c_read_stdin_line(buffer, 8192)
  if bytes_read <= 0 {
    return None
  }
  @bytes.decode_utf8(buffer[:bytes_read])
}

///|
fn repl_write(text : String) -> Unit {
  let data = @utf8.encode(text.view())
  let _ = @native.c_write_stdout(data, data.length())

}

///|
fn repl_flush() -> Unit {
  let _ = @native.c_fflush_stdout()

}
