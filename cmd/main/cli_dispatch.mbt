///|
/// CLI Dispatch
/// Main entry points and command dispatch

///|
/// グローバルGatewayインスタンス（シングルプロセス用）
let global_gateway : @control.Gateway = create_global_gateway(version)

///|
/// コマンドを実行 (async)
pub async fn execute_command(cmd : Command) -> CliResult {
  match cmd {
    Command::Help => CliResult::Ok(get_help_message())
    Command::Version => CliResult::Ok(get_version_message())
    Command::Onboard(opts) => execute_onboard(opts)
    Command::Gateway(gateway_cmd) => execute_gateway_command(gateway_cmd)
    Command::Agent(opts) => execute_agent_command(opts)
    Command::Config(config_cmd) => execute_config_command(config_cmd)
    Command::Cron(cron_cmd) => execute_cron_command(cron_cmd)
    Command::Service(service_cmd) => execute_service_command(service_cmd)
    Command::DaemonChild(pid_path) => execute_daemon_child(pid_path)
    Command::Unknown(name) =>
      CliResult::Error("Unknown command: \{name}\n\n\{get_help_message()}")
  }
}

///|
/// 統合経路テスト用: dispatch_inbound -> agent loop -> outbound を実行 (async)
pub async fn dispatch_echo_for_test(content : String) -> CliResult {
  set_forced_response_for_test(Some("Echo: \{content}"))
  let start_result : Result[Unit, @interfaces.ControlError] = Ok(
    global_gateway.start(config=@interfaces.GatewayConfig::default()),
  ) catch {
    e => Err(e)
  }
  match start_result {
    Ok(_) => ()
    Err(@interfaces.ControlError::AlreadyRunning) => ()
    Err(_) => {
      set_forced_response_for_test(None)
      return CliResult::Error("Failed to start gateway for test")
    }
  }

  let before = sent_messages_count()
  let envelope : @types.InboundEnvelope = {
    channel: "test",
    chat_id: "chat-1",
    sender_id: "user-1",
    sender_name: "User",
    content,
    message_type: @types.MessageType::Text,
    metadata: {},
    timestamp: 1000L,
  }
  let auth = @interfaces.AuthContext::token_only("test-token")
  let dispatch_result : Result[Unit, @interfaces.ControlError] = Ok(
    global_gateway.dispatch_inbound(auth~, envelope~),
  ) catch {
    e => Err(e)
  }
  match dispatch_result {
    Ok(_) => ()
    Err(_) => {
      set_forced_response_for_test(None)
      return CliResult::Error("dispatch_inbound failed")
    }
  }

  let after = sent_messages_count()
  if after <= before {
    set_forced_response_for_test(None)
    return CliResult::Error("No outbound message dispatched")
  }
  let result = match sent_message_at(after - 1) {
    Some(msg) => CliResult::Ok(msg.content)
    None => CliResult::Error("Dispatched message not found")
  }
  set_forced_response_for_test(None)
  result
}

///|
/// CLI実行結果を出力
fn print_result(result : CliResult) -> Unit {
  match result {
    CliResult::Ok(msg) => println(msg)
    CliResult::Error(msg) => println("Error: \{msg}")
    CliResult::Exit(code) => println("Exit code: \{code}")
  }
}

///|
/// グローバルオプションを適用
fn apply_global_options(opts : GlobalOptions) -> Unit {
  @config.set_path_mode(opts.path_mode)
}

///|
/// CLIを実行（引数配列を受け取る） (async)
pub async fn run_cli(args : Array[String]) -> CliResult {
  let (global_opts, remaining) = parse_global_options(args)
  apply_global_options(global_opts)
  let cmd = parse_args(remaining)
  execute_command(cmd)
}

///|
pub async fn run_cli_from_env_async() -> Unit {
  let args = get_command_line_args()
  if args.is_empty() {
    println(get_help_message())
  } else {
    let result = run_cli(args)
    print_result(result)
  }
}

///|
/// Synchronous entry point - async operations require native target
pub fn run_cli_from_env() -> Unit {
  let args = get_command_line_args()
  if args.is_empty() {
    println(get_help_message())
  } else {
    // Parse global options first
    let (global_opts, remaining) = parse_global_options(args)
    apply_global_options(global_opts)
    // For non-async commands, parse and handle directly
    let cmd = parse_args(remaining)
    match cmd {
      Command::Help => print_result(CliResult::Ok(get_help_message()))
      Command::Version => print_result(CliResult::Ok(get_version_message()))
      _ =>
        println("Note: This command requires native target for async support")
    }
  }
}

///|
async fn main {
  run_cli_from_env_async()
}

// get_command_line_args() は args.mbt で共通実装:
// @env.args() を使用し、Node.js環境を自動検出してスキップ数を調整
