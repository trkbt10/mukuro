///|
/// CLI Dispatch
/// Main entry points and command dispatch

///|
/// グローバルGatewayインスタンス（シングルプロセス用）
let global_gateway : @control.Gateway = create_global_gateway(@cli.version)

///|
/// コマンドを実行 (async)
pub async fn execute_command(cmd : @cli.Command) -> @cli.CliResult {
  match cmd {
    @cli.Command::Help =>
      @cli.CliResult::Ok(
        @cli.get_help_message(
          config_path=@cmd_config.default_runtime_config_path(),
        ),
      )
    @cli.Command::Version => @cli.CliResult::Ok(@cli.get_version_message())
    @cli.Command::Onboard(opts) => execute_onboard(opts)
    @cli.Command::Gateway(gateway_cmd) => execute_gateway_command(gateway_cmd)
    @cli.Command::Agent(opts) => execute_agent_command(opts)
    @cli.Command::Config(config_cmd) => execute_config_command(config_cmd)
    @cli.Command::Cron(cron_cmd) => execute_cron_command(cron_cmd)
    @cli.Command::Service(service_cmd) =>
      @service.execute_service_command(service_cmd)
    @cli.Command::DaemonChild(pid_path) => execute_daemon_child(pid_path)
    @cli.Command::Unknown(name) =>
      @cli.CliResult::Error(
        "Unknown command: \{name}\n\n\{@cli.get_help_message(config_path=@cmd_config.default_runtime_config_path())}",
      )
  }
}

///|
/// 統合経路テスト用: dispatch_inbound -> agent loop -> outbound を実行 (async)
pub async fn dispatch_echo_for_test(content : String) -> @cli.CliResult {
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
      return @cli.CliResult::Error("Failed to start gateway for test")
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
      return @cli.CliResult::Error("dispatch_inbound failed")
    }
  }

  let after = sent_messages_count()
  if after <= before {
    set_forced_response_for_test(None)
    return @cli.CliResult::Error("No outbound message dispatched")
  }
  let result = match sent_message_at(after - 1) {
    Some(msg) => @cli.CliResult::Ok(msg.content)
    None => @cli.CliResult::Error("Dispatched message not found")
  }
  set_forced_response_for_test(None)
  result
}

///|
/// CLIを実行（引数配列を受け取る） (async)
pub async fn run_cli(args : Array[String]) -> @cli.CliResult {
  let (global_opts, remaining) = @cli.parse_global_options(args)
  @cli.apply_global_options(global_opts)
  let cmd = @cli.parse_args(remaining)
  execute_command(cmd)
}

///|
pub async fn run_cli_from_env_async() -> Unit {
  let args = @cli.get_command_line_args()
  if args.is_empty() {
    println(
      @cli.get_help_message(
        config_path=@cmd_config.default_runtime_config_path(),
      ),
    )
  } else {
    let result = run_cli(args)
    @cli.print_result(result)
  }
}

///|
/// Synchronous entry point - async operations require native target
pub fn run_cli_from_env() -> Unit {
  let args = @cli.get_command_line_args()
  if args.is_empty() {
    println(
      @cli.get_help_message(
        config_path=@cmd_config.default_runtime_config_path(),
      ),
    )
  } else {
    // Parse global options first
    let (global_opts, remaining) = @cli.parse_global_options(args)
    @cli.apply_global_options(global_opts)
    // For non-async commands, parse and handle directly
    let cmd = @cli.parse_args(remaining)
    match cmd {
      @cli.Command::Help =>
        @cli.print_result(
          @cli.CliResult::Ok(
            @cli.get_help_message(
              config_path=@cmd_config.default_runtime_config_path(),
            ),
          ),
        )
      @cli.Command::Version =>
        @cli.print_result(@cli.CliResult::Ok(@cli.get_version_message()))
      _ =>
        println("Note: This command requires native target for async support")
    }
  }
}

///|
async fn main {
  run_cli_from_env_async()
}
