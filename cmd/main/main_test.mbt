///|
/// cmd/main 統合テスト（execute系）

///|
async test "execute_command Help" {
  let result = execute_command(@cli.Command::Help)
  assert_true(
    match result {
      @cli.CliResult::Ok(msg) => msg.contains("mukuro")
      _ => false
    },
  )
}

///|
async test "execute_command Version" {
  let result = execute_command(@cli.Command::Version)
  assert_true(
    match result {
      @cli.CliResult::Ok(msg) => msg.contains("0.1.0")
      _ => false
    },
  )
}

///|
async test "execute_onboard missing provider" {
  let opts : @cli.OnboardOptions = {
    provider: None,
    api_key: Some("key"),
    default_model: None,
    base_url: None,
    output_path: None,
    reset: false,
  }
  let result = execute_onboard(opts)
  assert_true(
    match result {
      @cli.CliResult::Error(msg) => msg.contains("--provider")
      _ => false
    },
  )
}

///|
async test "execute_onboard missing api_key" {
  let opts : @cli.OnboardOptions = {
    provider: Some("anthropic"),
    api_key: None,
    default_model: None,
    base_url: None,
    output_path: None,
    reset: false,
  }
  let result = execute_onboard(opts)
  assert_true(
    match result {
      @cli.CliResult::Error(msg) => msg.contains("--api-key")
      _ => false
    },
  )
}

///|
async test "execute_onboard success with interpolated config" {
  // Use test-specific output path to avoid polluting user config
  let opts : @cli.OnboardOptions = {
    provider: Some("anthropic"),
    api_key: Some("sk-test123"),
    default_model: Some("claude-3"),
    base_url: None,
    output_path: Some("\{@osenv_dirs.temp_dir()}/mukuro-test/onboard-test-config.json"),
    reset: false,
  }
  let result = execute_onboard(opts)
  assert_true(
    match result {
      @cli.CliResult::Ok(msg) =>
        msg.contains("anthropic") && msg.contains("claude-3")
      _ => false
    },
  )
  // Cleanup test file
  ignore(
    @native.c_remove_file_bytes(
      @native.string_to_utf8_cstring(
        "\{@osenv_dirs.temp_dir()}/mukuro-test/onboard-test-config.json",
      ),
    ),
  )
}

///|
async test "run_cli help" {
  let result = run_cli(["help"])
  assert_true(
    match result {
      @cli.CliResult::Ok(msg) => msg.contains("Usage:")
      _ => false
    },
  )
}

///|
async test "run_cli gateway status" {
  let result = run_cli(["gateway", "status"])
  assert_true(
    match result {
      @cli.CliResult::Ok(msg) => msg.contains("State:")
      _ => false
    },
  )
}

///|
async test "run_cli gateway status --json" {
  let result = run_cli(["gateway", "status", "--json"])
  assert_true(
    match result {
      @cli.CliResult::Ok(msg) => msg.has_prefix("{\"mode\":")
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
  @daemon.set_daemon_ipc_response_hook_for_test(fn(_cmd) {
    Some("ERR unauthorized")
  })
  let result = @daemon.query_daemon_status(12345, false)
  @daemon.clear_daemon_ipc_response_hook_for_test()
  assert_true(
    match result {
      @cli.CliResult::Error(msg) => msg.contains("authentication failed")
      _ => false
    },
  )
}

///|
test "request_daemon_stop returns auth error when ipc unauthorized" {
  @daemon.set_daemon_ipc_response_hook_for_test(fn(_cmd) {
    Some("ERR unauthorized")
  })
  let result = @daemon.request_daemon_stop(12345)
  @daemon.clear_daemon_ipc_response_hook_for_test()
  assert_true(
    match result {
      @cli.CliResult::Error(msg) => msg.contains("authentication failed")
      _ => false
    },
  )
}

///|
async test "dispatch_inbound runs integrated agent loop" {
  let result = dispatch_echo_for_test("hello")
  assert_true(
    match result {
      @cli.CliResult::Ok(msg) => msg.contains("Echo: hello")
      _ => false
    },
  )
}

///|
async test "execute_gateway auth-log returns runtime-dependent result" {
  let result = execute_gateway_command(
    @cli.GatewayCommand::AuthLog({ since_seconds: 60, json: true }),
  )
  assert_true(
    match result {
      @cli.CliResult::Ok(msg) => msg.contains("since_seconds")
      @cli.CliResult::Error(msg) =>
        msg.contains("only supported on native target")
      _ => false
    },
  )
}
