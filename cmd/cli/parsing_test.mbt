///|
/// CLI Parsing テスト (@argparse ベース)

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
test "parse_args help subcommand" {
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
test "parse_args -h" {
  let cmd = parse_args(["-h"])
  assert_true(
    match cmd {
      Command::Help => true
      _ => false
    },
  )
}

///|
test "parse_args version subcommand" {
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
test "parse_args -v" {
  let cmd = parse_args(["-v"])
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
        opts.default_model == Some("claude-3") &&
        opts.base_url == None &&
        opts.reset == false
      _ => false
    },
  )
}

///|
test "parse_args onboard with base-url" {
  let cmd = parse_args([
    "onboard", "--provider", "deepseek", "--base-url", "https://api.deepseek.com/v1",
    "--api-key", "sk-ds",
  ])
  assert_true(
    match cmd {
      Command::Onboard(opts) =>
        opts.provider == Some("deepseek") &&
        opts.base_url == Some("https://api.deepseek.com/v1") &&
        opts.api_key == Some("sk-ds")
      _ => false
    },
  )
}

///|
test "parse_args onboard with reset flag" {
  let cmd = parse_args(["onboard", "--provider", "anthropic", "--reset"])
  assert_true(
    match cmd {
      Command::Onboard(opts) =>
        opts.provider == Some("anthropic") && opts.reset == true
      _ => false
    },
  )
}

///|
test "parse_args onboard without provider shows list" {
  let cmd = parse_args(["onboard"])
  assert_true(
    match cmd {
      Command::Onboard(opts) => opts.provider == None
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
test "parse_args gateway without subcommand defaults to start" {
  let cmd = parse_args(["gateway"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(_)) => true
      _ => false
    },
  )
}

///|
test "parse_args gateway with options but no subcommand" {
  let cmd = parse_args(["gateway", "--port", "9000"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(opts)) => opts.port == Some(9000)
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
test "parse_args gateway auth-log defaults" {
  let cmd = parse_args(["gateway", "auth-log"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::AuthLog(opts)) =>
        opts.since_seconds == 3600 && opts.json == false
      _ => false
    },
  )
}

///|
test "parse_args gateway auth-log with options" {
  let cmd = parse_args(["gateway", "auth-log", "--since", "120", "--json"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::AuthLog(opts)) =>
        opts.since_seconds == 120 && opts.json == true
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
      Command::Unknown(_) => true
      _ => false
    },
  )
}

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
test "parse_args gateway start --daemon with --control-api" {
  let cmd = parse_args(["gateway", "start", "--daemon", "--control-api"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(opts)) =>
        opts.daemon == true && opts.control_api == true
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
test "parse_args gateway start --control-api" {
  let cmd = parse_args(["gateway", "start", "--control-api"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(opts)) =>
        opts.control_api == true && opts.daemon == false
      _ => false
    },
  )
}

///|
test "parse_args daemon-child internal command" {
  let cmd = parse_args(["--daemon-child", "test-data/gateway.pid"])
  assert_true(
    match cmd {
      Command::DaemonChild(path) => path == "test-data/gateway.pid"
      _ => false
    },
  )
}

///|
test "parse_args daemon-child without pid_path returns Unknown" {
  // argparse が MissingValue エラーを発生 → catch で Unknown にフォールバック
  let cmd = parse_args(["--daemon-child"])
  assert_true(
    match cmd {
      Command::Unknown(_) => true
      _ => false
    },
  )
}

///|
test "parse_args gateway start with daemon and control-api" {
  let cmd = parse_args(["gateway", "start", "--daemon", "--control-api"])
  assert_true(
    match cmd {
      Command::Gateway(GatewayCommand::Start(opts)) =>
        opts.daemon == true && opts.control_api == true
      _ => false
    },
  )
}

///|
test "parse_args config default is show" {
  let cmd = parse_args(["config"])
  assert_true(
    match cmd {
      Command::Config(ConfigCommand::Show) => true
      _ => false
    },
  )
}

///|
test "parse_args config path" {
  let cmd = parse_args(["config", "path"])
  assert_true(
    match cmd {
      Command::Config(ConfigCommand::Path) => true
      _ => false
    },
  )
}

///|
test "parse_args config providers" {
  let cmd = parse_args(["config", "providers"])
  assert_true(
    match cmd {
      Command::Config(ConfigCommand::Providers) => true
      _ => false
    },
  )
}

///|
test "parse_args agent with message" {
  let cmd = parse_args(["agent", "-m", "hello world"])
  assert_true(
    match cmd {
      Command::Agent(opts) => opts.message == Some("hello world")
      _ => false
    },
  )
}

///|
test "parse_args agent with --message" {
  let cmd = parse_args(["agent", "--message", "hello world"])
  assert_true(
    match cmd {
      Command::Agent(opts) => opts.message == Some("hello world")
      _ => false
    },
  )
}

///|
test "parse_args agent without options" {
  let cmd = parse_args(["agent"])
  assert_true(
    match cmd {
      Command::Agent(opts) => opts.message == None && opts.config_path == None
      _ => false
    },
  )
}

///|
test "parse_args service install defaults" {
  let cmd = parse_args(["service", "install"])
  assert_true(
    match cmd {
      Command::Service(ServiceCommand::Install(opts)) =>
        opts.user == true && opts.system == false && opts.auto_start == false
      _ => false
    },
  )
}

///|
test "parse_args service install --system" {
  let cmd = parse_args(["service", "install", "--system"])
  assert_true(
    match cmd {
      Command::Service(ServiceCommand::Install(opts)) =>
        opts.system == true && opts.user == false
      _ => false
    },
  )
}

///|
test "parse_args service status --json" {
  let cmd = parse_args(["service", "status", "--json"])
  assert_true(
    match cmd {
      Command::Service(ServiceCommand::Status(opts)) => opts.json == true
      _ => false
    },
  )
}

///|
test "parse_args service logs defaults" {
  let cmd = parse_args(["service", "logs"])
  assert_true(
    match cmd {
      Command::Service(ServiceCommand::Logs(opts)) =>
        opts.follow == false && opts.lines == 100
      _ => false
    },
  )
}

///|
test "parse_args service logs -f -n 50" {
  let cmd = parse_args(["service", "logs", "-f", "-n", "50"])
  assert_true(
    match cmd {
      Command::Service(ServiceCommand::Logs(opts)) =>
        opts.follow == true && opts.lines == 50
      _ => false
    },
  )
}

///|
test "parse_args --help in subcommand context" {
  // --help は global flag なのでどのサブコマンドでも Help を返す
  let cmd = parse_args(["gateway", "--help"])
  assert_true(
    match cmd {
      Command::Help => true
      _ => false
    },
  )
}

///|
test "mukuro_command render_help contains mukuro" {
  let help = mukuro_command().render_help()
  assert_true(help.contains("mukuro"))
}
