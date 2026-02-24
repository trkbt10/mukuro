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
      Command::Gateway(GatewayCommand::Status) => true
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
