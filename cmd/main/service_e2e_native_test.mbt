///|
/// Service Command E2E Tests
/// End-to-end tests for service management commands

// =============================================================================
// Service Command Parsing Tests
// =============================================================================

///|
/// Helper to parse service args and extract ServiceCommand
fn parse_service_cmd(args : Array[String]) -> @cli.ServiceCommand {
  // "service" を先頭に追加して parse_args に渡す
  let full_args : Array[String] = ["service"]
  for arg in args {
    full_args.push(arg)
  }
  match @cli.parse_args(full_args) {
    @cli.Command::Service(cmd) => cmd
    _ => @cli.ServiceCommand::Unknown("parse_error")
  }
}

///|
test "parse_service_args parses install command" {
  let cmd = parse_service_cmd(["install"])
  match cmd {
    @cli.ServiceCommand::Install(opts) => {
      assert_eq(opts.user, true) // Default is user level
      assert_eq(opts.auto_start, false) // Default is no auto start
    }
    _ => fail("Expected Install command")
  }
}

///|
test "parse_service_args parses install --system" {
  let cmd = parse_service_cmd(["install", "--system"])
  match cmd {
    @cli.ServiceCommand::Install(opts) => assert_eq(opts.user, false)
    _ => fail("Expected Install command")
  }
}

///|
test "parse_service_args parses install --user" {
  let cmd = parse_service_cmd(["install", "--user"])
  match cmd {
    @cli.ServiceCommand::Install(opts) => assert_eq(opts.user, true)
    _ => fail("Expected Install command")
  }
}

///|
test "parse_service_args parses install --no-auto-start" {
  let cmd = parse_service_cmd(["install", "--no-auto-start"])
  match cmd {
    @cli.ServiceCommand::Install(opts) => assert_eq(opts.auto_start, false)
    _ => fail("Expected Install command")
  }
}

///|
test "parse_service_args parses install --config PATH" {
  let cmd = parse_service_cmd(["install", "--config", "/path/to/config.json"])
  match cmd {
    @cli.ServiceCommand::Install(opts) =>
      match opts.config_path {
        Some(path) => assert_eq(path, "/path/to/config.json")
        None => fail("Expected config path")
      }
    _ => fail("Expected Install command")
  }
}

///|
test "parse_service_args parses uninstall command" {
  let cmd = parse_service_cmd(["uninstall"])
  assert_true(cmd is @cli.ServiceCommand::Uninstall)
}

///|
test "parse_service_args parses start command" {
  let cmd = parse_service_cmd(["start"])
  assert_true(cmd is @cli.ServiceCommand::Start)
}

///|
test "parse_service_args parses stop command" {
  let cmd = parse_service_cmd(["stop"])
  assert_true(cmd is @cli.ServiceCommand::Stop)
}

///|
test "parse_service_args parses restart command" {
  let cmd = parse_service_cmd(["restart"])
  assert_true(cmd is @cli.ServiceCommand::Restart)
}

///|
test "parse_service_args parses status command" {
  match parse_service_cmd(["status"]) {
    @cli.ServiceCommand::Status(opts) => assert_eq(opts.json, false)
    _ => fail("Expected Status command")
  }
}

///|
test "parse_service_args parses status --json" {
  match parse_service_cmd(["status", "--json"]) {
    @cli.ServiceCommand::Status(opts) => assert_eq(opts.json, true)
    _ => fail("Expected Status command")
  }
}

///|
test "parse_service_args parses logs command" {
  match parse_service_cmd(["logs"]) {
    @cli.ServiceCommand::Logs(opts) => {
      assert_eq(opts.follow, false)
      assert_eq(opts.lines, 100) // Default is 100 lines
    }
    _ => fail("Expected Logs command")
  }
}

///|
test "parse_service_args parses logs -f" {
  match parse_service_cmd(["logs", "-f"]) {
    @cli.ServiceCommand::Logs(opts) => assert_eq(opts.follow, true)
    _ => fail("Expected Logs command")
  }
}

///|
test "parse_service_args parses logs --follow" {
  match parse_service_cmd(["logs", "--follow"]) {
    @cli.ServiceCommand::Logs(opts) => assert_eq(opts.follow, true)
    _ => fail("Expected Logs command")
  }
}

///|
test "parse_service_args parses logs -n 100" {
  match parse_service_cmd(["logs", "-n", "100"]) {
    @cli.ServiceCommand::Logs(opts) => assert_eq(opts.lines, 100)
    _ => fail("Expected Logs command")
  }
}

///|
test "parse_service_args parses unknown command" {
  // argparse が不明なサブコマンドをエラーとして処理するため、
  // parse_args のフォールバックで Unknown になる
  let cmd = parse_service_cmd(["unknown"])
  assert_true(cmd is @cli.ServiceCommand::Unknown(_))
}

// =============================================================================
// Service Config Tests
// =============================================================================

///|
test "ServiceConfig::default creates valid config" {
  let config = @service.ServiceConfig::default("/usr/local/bin/mukuro", None)
  assert_eq(config.name, @service.service_name)
  assert_eq(config.display_name, @service.service_display_name)
  assert_eq(config.executable, "/usr/local/bin/mukuro")
  assert_eq(config.user_level, true)
  assert_eq(config.auto_start, true)
}

///|
test "ServiceConfig::default with config path" {
  let config = @service.ServiceConfig::default(
    "/usr/local/bin/mukuro",
    Some("/etc/mukuro/config.json"),
  )
  match config.config_path {
    Some(path) => assert_eq(path, "/etc/mukuro/config.json")
    None => fail("Expected config path")
  }
}

// =============================================================================
// Service Template Tests
// =============================================================================

///|
test "generate_launchd_plist creates valid plist" {
  let config : @service.ServiceConfig = {
    name: "com.test.service",
    display_name: "Test Service",
    executable: "/usr/local/bin/test",
    args: ["serve"],
    working_dir: "/tmp",
    config_path: None,
    user_level: true,
    auto_start: true,
    stdout_log: None,
    stderr_log: None,
  }
  let plist = @service.generate_launchd_plist(config)
  assert_true(plist.contains("<?xml version=\"1.0\""))
  assert_true(plist.contains("<key>Label</key>"))
  assert_true(plist.contains("com.test.service"))
  assert_true(plist.contains("<key>ProgramArguments</key>"))
  assert_true(plist.contains("/usr/local/bin/test"))
  assert_true(plist.contains("serve"))
  assert_true(plist.contains("<key>RunAtLoad</key>"))
  assert_true(plist.contains("<true/>"))
  assert_true(plist.contains("<key>KeepAlive</key>"))
}

///|
test "generate_launchd_plist includes config path" {
  let config : @service.ServiceConfig = {
    name: "com.test.service",
    display_name: "Test Service",
    executable: "/usr/local/bin/test",
    args: [],
    working_dir: "/tmp",
    config_path: Some("/etc/test/config.json"),
    user_level: true,
    auto_start: true,
    stdout_log: None,
    stderr_log: None,
  }
  let plist = @service.generate_launchd_plist(config)
  assert_true(plist.contains("--config"))
  assert_true(plist.contains("/etc/test/config.json"))
}

///|
test "generate_launchd_plist includes log paths" {
  let config : @service.ServiceConfig = {
    name: "com.test.service",
    display_name: "Test Service",
    executable: "/usr/local/bin/test",
    args: [],
    working_dir: "/tmp",
    config_path: None,
    user_level: true,
    auto_start: true,
    stdout_log: Some("/var/log/test.log"),
    stderr_log: Some("/var/log/test.err"),
  }
  let plist = @service.generate_launchd_plist(config)
  assert_true(plist.contains("<key>StandardOutPath</key>"))
  assert_true(plist.contains("/var/log/test.log"))
  assert_true(plist.contains("<key>StandardErrorPath</key>"))
  assert_true(plist.contains("/var/log/test.err"))
}

///|
test "generate_systemd_unit creates valid unit" {
  let config : @service.ServiceConfig = {
    name: "test-service",
    display_name: "Test Service",
    executable: "/usr/local/bin/test",
    args: ["serve", "--port", "8080"],
    working_dir: "/tmp",
    config_path: None,
    user_level: true,
    auto_start: true,
    stdout_log: None,
    stderr_log: None,
  }
  let unit = @service.generate_systemd_unit(config)
  assert_true(unit.contains("[Unit]"))
  assert_true(unit.contains("Description=Test Service"))
  assert_true(unit.contains("[Service]"))
  assert_true(unit.contains("Type=simple"))
  assert_true(unit.contains("ExecStart=/usr/local/bin/test serve --port 8080"))
  assert_true(unit.contains("Restart=always"))
  assert_true(unit.contains("[Install]"))
  assert_true(unit.contains("WantedBy=default.target"))
}

///|
test "generate_systemd_unit includes config path" {
  let config : @service.ServiceConfig = {
    name: "test-service",
    display_name: "Test Service",
    executable: "/usr/local/bin/test",
    args: [],
    working_dir: "/tmp",
    config_path: Some("/etc/test/config.json"),
    user_level: true,
    auto_start: true,
    stdout_log: None,
    stderr_log: None,
  }
  let unit = @service.generate_systemd_unit(config)
  assert_true(unit.contains("--config /etc/test/config.json"))
}

///|
test "generate_systemd_unit includes log paths" {
  let config : @service.ServiceConfig = {
    name: "test-service",
    display_name: "Test Service",
    executable: "/usr/local/bin/test",
    args: [],
    working_dir: "/tmp",
    config_path: None,
    user_level: true,
    auto_start: true,
    stdout_log: Some("/var/log/test.log"),
    stderr_log: Some("/var/log/test.err"),
  }
  let unit = @service.generate_systemd_unit(config)
  assert_true(unit.contains("StandardOutput=append:/var/log/test.log"))
  assert_true(unit.contains("StandardError=append:/var/log/test.err"))
}

///|
test "generate_systemd_unit without auto_start omits WantedBy" {
  let config : @service.ServiceConfig = {
    name: "test-service",
    display_name: "Test Service",
    executable: "/usr/local/bin/test",
    args: [],
    working_dir: "/tmp",
    config_path: None,
    user_level: true,
    auto_start: false,
    stdout_log: None,
    stderr_log: None,
  }
  let unit = @service.generate_systemd_unit(config)
  assert_true(not(unit.contains("WantedBy=")))
}

// =============================================================================
// Service Path Tests
// =============================================================================

///|
test "get_launchd_plist_path returns user path" {
  let path = @service.get_launchd_plist_path(true)
  assert_true(path.contains("Library/LaunchAgents"))
  assert_true(path.contains(@service.service_name))
  assert_true(path.contains(".plist"))
}

///|
test "get_launchd_plist_path returns system path" {
  let path = @service.get_launchd_plist_path(false)
  assert_eq(path, "/Library/LaunchDaemons/\{@service.service_name}.plist")
}

///|
test "get_systemd_unit_path returns user path" {
  let path = @service.get_systemd_unit_path(true)
  assert_true(path.contains(".config/systemd/user"))
  assert_true(path.contains("mukuro-gateway.service"))
}

///|
test "get_systemd_unit_path returns system path" {
  let path = @service.get_systemd_unit_path(false)
  assert_eq(path, "/etc/systemd/system/mukuro-gateway.service")
}

// =============================================================================
// ServiceStatus Tests
// =============================================================================

///|
test "ServiceStatus::to_json creates valid JSON" {
  let status : @service.ServiceStatus = {
    installed: true,
    running: true,
    pid: Some(12345),
    message: "Running",
  }
  let json = status.to_json()
  let str = json.stringify()
  assert_true(str.contains("\"installed\":true"))
  assert_true(str.contains("\"running\":true"))
  assert_true(str.contains("\"pid\":12345"))
  assert_true(str.contains("\"message\":\"Running\""))
}

///|
test "ServiceStatus::to_json handles null pid" {
  let status : @service.ServiceStatus = {
    installed: false,
    running: false,
    pid: None,
    message: "Not installed",
  }
  let json = status.to_json()
  let str = json.stringify()
  assert_true(str.contains("\"installed\":false"))
  assert_true(str.contains("\"pid\":null"))
}
