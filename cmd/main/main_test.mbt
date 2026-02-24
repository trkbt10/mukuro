///|
/// CLI テスト

///|
test "parse_args empty returns Help" {
  let cmd = parse_args([])
  assert_true(
    match cmd {
      Command::Help => true
      _ => false
    },
  )
}

///|
test "parse_args help" {
  let cmd = parse_args(["help"])
  assert_true(
    match cmd {
      Command::Help => true
      _ => false
    },
  )
}

///|
test "parse_args --help" {
  let cmd = parse_args(["--help"])
  assert_true(
    match cmd {
      Command::Help => true
      _ => false
    },
  )
}

///|
test "parse_args version" {
  let cmd = parse_args(["version"])
  assert_true(
    match cmd {
      Command::Version => true
      _ => false
    },
  )
}

///|
test "parse_args --version" {
  let cmd = parse_args(["--version"])
  assert_true(
    match cmd {
      Command::Version => true
      _ => false
    },
  )
}

///|
test "parse_args onboard with options" {
  let cmd = parse_args([
    "onboard", "--provider", "anthropic", "--api-key", "sk-xxx", "--model", "claude-3",
  ])
  assert_true(
    match cmd {
      Command::Onboard(opts) =>
        opts.provider == Some("anthropic") &&
        opts.api_key == Some("sk-xxx") &&
        opts.default_model == Some("claude-3")
      _ => false
    },
  )
}

///|
test "parse_args gateway start" {
  let cmd = parse_args(["gateway", "start"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(_)) => true
      _ => false
    },
  )
}

///|
test "parse_args gateway start with options" {
  let cmd = parse_args([
    "gateway", "start", "--host", "0.0.0.0", "--port", "9000",
  ])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(opts)) =>
        opts.host == Some("0.0.0.0") && opts.port == Some(9000)
      _ => false
    },
  )
}

///|
test "parse_args gateway status" {
  let cmd = parse_args(["gateway", "status"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Status(opts)) => opts.json == false
      _ => false
    },
  )
}

///|
test "parse_args gateway status --json" {
  let cmd = parse_args(["gateway", "status", "--json"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Status(opts)) => opts.json == true
      _ => false
    },
  )
}

///|
test "parse_args gateway stop" {
  let cmd = parse_args(["gateway", "stop"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Stop) => true
      _ => false
    },
  )
}

///|
test "parse_args cron list" {
  let cmd = parse_args(["cron", "list"])
  assert_true(
    match cmd {
      Command::Cron(CronCommand::List) => true
      _ => false
    },
  )
}

///|
test "parse_args unknown command" {
  let cmd = parse_args(["unknown"])
  assert_true(
    match cmd {
      Command::Unknown("unknown") => true
      _ => false
    },
  )
}

///|
test "execute_command Help" {
  let result = execute_command(Command::Help)
  assert_true(
    match result {
      CliResult::Ok(msg) => msg.contains("mukuro")
      _ => false
    },
  )
}

///|
test "execute_command Version" {
  let result = execute_command(Command::Version)
  assert_true(
    match result {
      CliResult::Ok(msg) => msg.contains("0.1.0")
      _ => false
    },
  )
}

///|
test "execute_onboard missing provider" {
  let opts : OnboardOptions = {
    provider: None,
    api_key: Some("key"),
    default_model: None,
    output_path: None,
  }
  let result = execute_onboard(opts)
  assert_true(
    match result {
      CliResult::Error(msg) => msg.contains("--provider")
      _ => false
    },
  )
}

///|
test "execute_onboard missing api_key" {
  let opts : OnboardOptions = {
    provider: Some("anthropic"),
    api_key: None,
    default_model: None,
    output_path: None,
  }
  let result = execute_onboard(opts)
  assert_true(
    match result {
      CliResult::Error(msg) => msg.contains("--api-key")
      _ => false
    },
  )
}

///|
test "execute_onboard success with interpolated config" {
  let opts : OnboardOptions = {
    provider: Some("anthropic"),
    api_key: Some("sk-test123"),
    default_model: Some("claude-3"),
    output_path: None,
  }
  let result = execute_onboard(opts)
  assert_true(
    match result {
      CliResult::Ok(msg) =>
        msg.contains("anthropic") &&
        msg.contains("sk-test123") &&
        msg.contains("claude-3")
      _ => false
    },
  )
}

///|
test "run_cli help" {
  let result = run_cli(["help"])
  assert_true(
    match result {
      CliResult::Ok(msg) => msg.contains("Usage:")
      _ => false
    },
  )
}

///|
test "run_cli gateway status" {
  let result = run_cli(["gateway", "status"])
  assert_true(
    match result {
      CliResult::Ok(msg) => msg.contains("State:")
      _ => false
    },
  )
}

///|
test "run_cli gateway status --json" {
  let result = run_cli(["gateway", "status", "--json"])
  assert_true(
    match result {
      CliResult::Ok(msg) => msg.has_prefix("{\"mode\":")
      _ => false
    },
  )
}

// ============================================================
// Daemon mode tests
// ============================================================

///|
test "parse_args gateway start --daemon" {
  let cmd = parse_args(["gateway", "start", "--daemon"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(opts)) => opts.daemon == true
      _ => false
    },
  )
}

///|
test "parse_args gateway start -D" {
  let cmd = parse_args(["gateway", "start", "-D"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(opts)) => opts.daemon == true
      _ => false
    },
  )
}

///|
test "parse_args gateway start --daemon with options" {
  let cmd = parse_args([
    "gateway", "start", "--daemon", "--host", "127.0.0.1", "--port", "8080",
  ])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(opts)) =>
        opts.daemon == true &&
        opts.host == Some("127.0.0.1") &&
        opts.port == Some(8080)
      _ => false
    },
  )
}

///|
test "parse_args gateway start without daemon" {
  let cmd = parse_args(["gateway", "start", "--port", "9000"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(opts)) =>
        opts.daemon == false && opts.port == Some(9000)
      _ => false
    },
  )
}

///|
test "parse_args daemon-child internal command" {
  let cmd = parse_args(["--daemon-child", ".mukuro/gateway.pid"])
  assert_true(
    match cmd {
      Command::DaemonChild(path) => path == ".mukuro/gateway.pid"
      _ => false
    },
  )
}

///|
test "parse_args daemon-child without pid_path returns Unknown" {
  let cmd = parse_args(["--daemon-child"])
  assert_true(
    match cmd {
      Command::Unknown(msg) => msg.contains("requires pid_path")
      _ => false
    },
  )
}

///|
test "DaemonStatus::Running pattern" {
  let status = @control.DaemonStatus::Running(12345)
  assert_true(
    match status {
      @control.DaemonStatus::Running(pid) => pid == 12345
      _ => false
    },
  )
}

///|
test "DaemonStatus::Stopped pattern" {
  let status = @control.DaemonStatus::Stopped
  assert_true(
    match status {
      @control.DaemonStatus::Stopped => true
      _ => false
    },
  )
}

///|
test "DaemonStatus::Stale pattern" {
  let status = @control.DaemonStatus::Stale(99999)
  assert_true(
    match status {
      @control.DaemonStatus::Stale(pid) => pid == 99999
      _ => false
    },
  )
}

///|
test "query_daemon_status returns auth error when ipc unauthorized" {
  set_daemon_ipc_response_hook_for_test(fn(_cmd) { Some("ERR unauthorized") })
  let result = query_daemon_status(12345, false)
  clear_daemon_ipc_response_hook_for_test()
  assert_true(
    match result {
      CliResult::Error(msg) => msg.contains("authentication failed")
      _ => false
    },
  )
}

///|
test "request_daemon_stop returns auth error when ipc unauthorized" {
  set_daemon_ipc_response_hook_for_test(fn(_cmd) { Some("ERR unauthorized") })
  let result = request_daemon_stop(12345)
  clear_daemon_ipc_response_hook_for_test()
  assert_true(
    match result {
      CliResult::Error(msg) => msg.contains("authentication failed")
      _ => false
    },
  )
}

///|
test "dispatch_inbound runs integrated agent loop" {
  let result = dispatch_echo_for_test("hello")
  assert_true(
    match result {
      CliResult::Ok(msg) => msg.contains("Echo: hello")
      _ => false
    },
  )
}
