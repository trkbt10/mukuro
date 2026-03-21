///|
/// CLI Argument Parsing (@argparse ベース)
/// 宣言的コマンドツリー定義と Matches → Command 変換

///|
/// argparse コマンドツリーを構築
pub fn mukuro_command() -> @argparse.Command {
  @argparse.Command(
    "mukuro",
    about="MoonBit Agent Framework v\{version}",
    disable_help_flag=true,
    disable_version_flag=true,
    disable_help_subcommand=true,
    flags=[
      @argparse.FlagArg(
        "show-help",
        short='h',
        long="help",
        global=true,
        about="Show help information",
      ),
      @argparse.FlagArg(
        "show-version",
        short='v',
        long="version",
        about="Show version information",
      ),
      @argparse.FlagArg(
        "local",
        global=true,
        about="Use .mukuro in current directory (project-local)",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "data-dir",
        global=true,
        about="Use custom data directory",
      ),
      @argparse.OptionArg("daemon-child", hidden=true),
    ],
    subcommands=[
      onboard_command(),
      gateway_command(),
      agent_command(),
      config_command(),
      cron_command(),
      service_command(),
      @argparse.Command("help", hidden=true, disable_help_flag=true),
      @argparse.Command("version", hidden=true, disable_help_flag=true),
    ],
  )
}

///|
fn onboard_command() -> @argparse.Command {
  @argparse.Command(
    "onboard",
    about="Initialize mukuro configuration",
    disable_help_flag=true,
    flags=[
      @argparse.FlagArg(
        "reset",
        about="Reset config before writing (default: merge)",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "provider",
        about="Provider name (anthropic, openai, gemini, deepseek, groq, openrouter, ollama, moonshot, or custom)",
      ),
      @argparse.OptionArg(
        "api-key",
        about="API key (auto-detected from env if not specified)",
      ),
      @argparse.OptionArg(
        "model",
        about="Default model (auto-set from provider if not specified)",
      ),
      @argparse.OptionArg(
        "base-url",
        about="Base URL for custom/OpenAI-compatible endpoints",
      ),
      @argparse.OptionArg("output", about="Config file path"),
    ],
  )
}

///|
fn gateway_command() -> @argparse.Command {
  @argparse.Command(
    "gateway",
    about="Gateway service management",
    disable_help_flag=true,
    // start 用オプションを global にして、サブコマンドなしでも使えるようにする
    // `mukuro gateway --port 9000` = `mukuro gateway start --port 9000`
    flags=[
      @argparse.FlagArg(
        "debug",
        short='d',
        global=true,
        about="Enable debug mode",
      ),
      @argparse.FlagArg(
        "daemon",
        short='D',
        global=true,
        about="Run as daemon (background process)",
      ),
      @argparse.FlagArg(
        "control-api",
        global=true,
        about="Serve HTTP control API (works with --daemon)",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "config",
        global=true,
        about="Path to configuration file",
      ),
      @argparse.OptionArg(
        "host",
        global=true,
        about="Host to bind (default: \{@interfaces.gateway_default_host})",
      ),
      @argparse.OptionArg(
        "port",
        global=true,
        about="Port to bind (default: \{@interfaces.gateway_default_port})",
      ),
    ],
    subcommands=[
      @argparse.Command(
        "start",
        about="Start the gateway (default when no subcommand given)",
        disable_help_flag=true,
      ),
      @argparse.Command(
        "run",
        about="Start the gateway",
        hidden=true,
        disable_help_flag=true,
      ),
      gateway_status_command(),
      @argparse.Command(
        "stop",
        about="Stop the gateway service",
        disable_help_flag=true,
      ),
      gateway_auth_log_command(),
    ],
  )
}

///|
fn gateway_status_command() -> @argparse.Command {
  @argparse.Command(
    "status",
    about="Show gateway status",
    disable_help_flag=true,
    flags=[@argparse.FlagArg("json", about="Output status as JSON")],
  )
}

///|
fn gateway_auth_log_command() -> @argparse.Command {
  @argparse.Command(
    "auth-log",
    about="Show auth audit log summary",
    disable_help_flag=true,
    flags=[@argparse.FlagArg("json", about="Output summary as JSON")],
    options=[
      @argparse.OptionArg(
        "since",
        about="Lookback window in seconds (default: 3600)",
        default_values=["3600"],
      ),
    ],
  )
}

///|
fn agent_command() -> @argparse.Command {
  @argparse.Command(
    "agent",
    about="Interactive agent REPL or single-shot execution",
    disable_help_flag=true,
    options=[
      @argparse.OptionArg(
        "message",
        short='m',
        about="Send a single message and exit",
      ),
      @argparse.OptionArg("config", about="Path to configuration file"),
    ],
  )
}

///|
fn config_command() -> @argparse.Command {
  @argparse.Command(
    "config",
    about="View configuration",
    disable_help_flag=true,
    subcommands=[
      @argparse.Command(
        "path",
        about="Show configuration file path",
        disable_help_flag=true,
      ),
      @argparse.Command(
        "show",
        about="Show current configuration",
        disable_help_flag=true,
      ),
      @argparse.Command(
        "providers",
        about="List configured providers",
        disable_help_flag=true,
      ),
    ],
  )
}

///|
fn cron_command() -> @argparse.Command {
  @argparse.Command(
    "cron",
    about="Manage cron jobs",
    disable_help_flag=true,
    subcommands=[
      @argparse.Command(
        "list",
        about="List scheduled cron jobs",
        disable_help_flag=true,
      ),
    ],
  )
}

///|
fn service_command() -> @argparse.Command {
  @argparse.Command(
    "service",
    about="Manage system service",
    disable_help_flag=true,
    subcommands=[
      service_install_command(),
      @argparse.Command(
        "uninstall",
        about="Uninstall system service",
        disable_help_flag=true,
      ),
      @argparse.Command(
        "start",
        about="Start the service",
        disable_help_flag=true,
      ),
      @argparse.Command(
        "stop",
        about="Stop the service",
        disable_help_flag=true,
      ),
      @argparse.Command(
        "restart",
        about="Restart the service",
        disable_help_flag=true,
      ),
      service_status_command(),
      service_logs_command(),
    ],
  )
}

///|
fn service_install_command() -> @argparse.Command {
  @argparse.Command(
    "install",
    about="Install as system service",
    disable_help_flag=true,
    flags=[
      @argparse.FlagArg(
        "user",
        about="Install as user-level service (default)",
      ),
      @argparse.FlagArg(
        "system",
        about="Install as system-level service",
        conflicts_with=["user"],
      ),
      @argparse.FlagArg(
        "auto-start",
        about="Enable auto-start",
        negatable=true,
      ),
    ],
    options=[
      @argparse.OptionArg("config", about="Path to configuration file"),
    ],
  )
}

///|
fn service_status_command() -> @argparse.Command {
  @argparse.Command(
    "status",
    about="Show service status",
    disable_help_flag=true,
    flags=[@argparse.FlagArg("json", about="Output status as JSON")],
  )
}

///|
fn service_logs_command() -> @argparse.Command {
  @argparse.Command(
    "logs",
    about="View service logs",
    disable_help_flag=true,
    flags=[
      @argparse.FlagArg(
        "follow",
        short='f',
        about="Follow (realtime display)",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "lines",
        short='n',
        about="Number of lines to display (default: 100)",
        default_values=["100"],
      ),
    ],
  )
}

// =============================================================================
// ヘルパー: Matches からの値取得
// =============================================================================

///|
/// Matches の values から最初の値を取得
fn get_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(vs) => if vs.length() > 0 { Some(vs[0]) } else { None }
    None => None
  }
}

///|
/// Matches の flags からブール値を取得
fn get_flag(matches : @argparse.Matches, name : String) -> Bool {
  matches.flags.get(name).unwrap_or(false)
}

///|
/// 文字列を Int に変換（失敗時は None）
fn parse_int_opt(s : String) -> Int? {
  try {
    let json : Json = @json.parse(s)
    match json {
      Number(n, ..) => Some(n.to_int())
      _ => None
    }
  } catch {
    _ => None
  }
}

///|
/// 文字列を Int64 に変換（失敗時は None）
fn parse_int64_opt(s : String) -> Int64? {
  try {
    let json : Json = @json.parse(s)
    match json {
      Number(n, ..) => Some(n.to_int64())
      _ => None
    }
  } catch {
    _ => None
  }
}

// =============================================================================
// Matches → GlobalOptions 変換
// =============================================================================

///|
/// Matches からグローバルオプションを抽出
fn extract_global_options(matches : @argparse.Matches) -> GlobalOptions {
  let path_mode = if get_flag(matches, "local") {
    @config.PathMode::Local
  } else {
    match get_value(matches, "data-dir") {
      Some(path) => @config.PathMode::Custom(path)
      None => @config.PathMode::Standard
    }
  }
  { path_mode, }
}

// =============================================================================
// Matches → Command 変換
// =============================================================================

///|
/// Matches から Command に変換
fn matches_to_command(matches : @argparse.Matches) -> Command {
  // --help / -h (global flag — どのサブコマンドでも有効)
  if get_flag(matches, "show-help") {
    return Command::Help
  }
  // --version / -v
  if get_flag(matches, "show-version") {
    return Command::Version
  }
  // --daemon-child <path> (hidden option)
  match get_value(matches, "daemon-child") {
    Some(path) => return Command::DaemonChild(path)
    None => ()
  }
  // サブコマンド
  match matches.subcommand {
    Some(("help", _)) => Command::Help
    Some(("version", _)) => Command::Version
    Some(("onboard", m)) => matches_to_onboard(m)
    Some(("gateway", m)) => matches_to_gateway(m)
    Some(("agent", m)) => matches_to_agent(m)
    Some(("config", m)) => matches_to_config(m)
    Some(("cron", m)) => matches_to_cron(m)
    Some(("service", m)) => matches_to_service(m)
    Some((name, _)) => Command::Unknown(name)
    None => Command::Help // 引数なし → ヘルプ表示
  }
}

///|
fn matches_to_onboard(matches : @argparse.Matches) -> Command {
  if get_flag(matches, "show-help") {
    return Command::Help
  }
  let opts : OnboardOptions = {
    provider: get_value(matches, "provider"),
    api_key: get_value(matches, "api-key"),
    default_model: get_value(matches, "model"),
    base_url: get_value(matches, "base-url"),
    output_path: get_value(matches, "output"),
    reset: get_flag(matches, "reset"),
  }
  Command::Onboard(opts)
}

///|
fn matches_to_gateway(matches : @argparse.Matches) -> Command {
  if get_flag(matches, "show-help") {
    return Command::Help
  }
  match matches.subcommand {
    Some(("status", m)) => {
      let opts : GatewayStatusOptions = { json: get_flag(m, "json"), }
      Command::Gateway(GatewayCommand::Status(opts))
    }
    Some(("stop", _)) => Command::Gateway(GatewayCommand::Stop)
    Some(("auth-log", m)) => {
      let since_str = get_value(m, "since").unwrap_or("3600")
      let since = parse_int64_opt(since_str).unwrap_or(3600L)
      let opts : GatewayAuthLogOptions = {
        since_seconds: since,
        json: get_flag(m, "json"),
      }
      Command::Gateway(GatewayCommand::AuthLog(opts))
    }
    // start, run, サブコマンドなし → Start
    _ => {
      let opts = extract_gateway_start_opts(matches)
      Command::Gateway(GatewayCommand::Start(opts))
    }
  }
}

///|
/// gateway レベルの Matches から GatewayStartOptions を抽出
/// start 用オプションは global なので gateway レベルに存在する
fn extract_gateway_start_opts(
  matches : @argparse.Matches,
) -> GatewayStartOptions {
  {
    config_path: get_value(matches, "config"),
    host: get_value(matches, "host"),
    port: get_value(matches, "port").bind(parse_int_opt),
    debug: get_flag(matches, "debug"),
    daemon: get_flag(matches, "daemon"),
    control_api: get_flag(matches, "control-api"),
  }
}

///|
fn matches_to_agent(matches : @argparse.Matches) -> Command {
  if get_flag(matches, "show-help") {
    return Command::Help
  }
  let opts : AgentOptions = {
    message: get_value(matches, "message"),
    config_path: get_value(matches, "config"),
  }
  Command::Agent(opts)
}

///|
fn matches_to_config(matches : @argparse.Matches) -> Command {
  if get_flag(matches, "show-help") {
    return Command::Help
  }
  match matches.subcommand {
    Some(("path", _)) => Command::Config(ConfigCommand::Path)
    Some(("show", _)) => Command::Config(ConfigCommand::Show)
    Some(("providers", _)) => Command::Config(ConfigCommand::Providers)
    Some((name, _)) => Command::Config(ConfigCommand::Unknown(name))
    None => Command::Config(ConfigCommand::Show) // デフォルト
  }
}

///|
fn matches_to_cron(matches : @argparse.Matches) -> Command {
  if get_flag(matches, "show-help") {
    return Command::Help
  }
  match matches.subcommand {
    Some(("list", _)) => Command::Cron(CronCommand::List)
    Some((name, _)) => Command::Cron(CronCommand::Unknown(name))
    None => Command::Cron(CronCommand::Unknown(""))
  }
}

///|
fn matches_to_service(matches : @argparse.Matches) -> Command {
  if get_flag(matches, "show-help") {
    return Command::Help
  }
  match matches.subcommand {
    Some(("install", m)) => {
      let system_flag = get_flag(m, "system")
      let opts : ServiceInstallOptions = {
        user: not(system_flag),
        system: system_flag,
        config_path: get_value(m, "config"),
        auto_start: get_flag(m, "auto-start"),
      }
      Command::Service(ServiceCommand::Install(opts))
    }
    Some(("uninstall", _)) => Command::Service(ServiceCommand::Uninstall)
    Some(("start", _)) => Command::Service(ServiceCommand::Start)
    Some(("stop", _)) => Command::Service(ServiceCommand::Stop)
    Some(("restart", _)) => Command::Service(ServiceCommand::Restart)
    Some(("status", m)) => {
      let opts : ServiceStatusOptions = { json: get_flag(m, "json"), }
      Command::Service(ServiceCommand::Status(opts))
    }
    Some(("logs", m)) => {
      let lines_str = get_value(m, "lines").unwrap_or("100")
      let opts : ServiceLogsOptions = {
        follow: get_flag(m, "follow"),
        lines: parse_int_opt(lines_str).unwrap_or(100),
      }
      Command::Service(ServiceCommand::Logs(opts))
    }
    Some((name, _)) => Command::Service(ServiceCommand::Unknown(name))
    None => Command::Service(ServiceCommand::Unknown(""))
  }
}

// =============================================================================
// 公開 API
// =============================================================================

///|
/// コマンドラインをパースし、グローバルオプション適用後にコマンドを返す
/// parse エラー時は raise
pub fn parse_cli(args : Array[String]) -> Command raise {
  let cmd = mukuro_command()
  let matches = cmd.parse(argv=args, env={})
  let global_opts = extract_global_options(matches)
  apply_global_options(global_opts)
  matches_to_command(matches)
}

///|
/// 引数配列からコマンドをパース（テスト用・後方互換）
/// グローバルオプションの適用は行わない
/// parse エラー時は Unknown にフォールバック
pub fn parse_args(args : Array[String]) -> Command {
  try {
    let cmd = mukuro_command()
    let matches = cmd.parse(argv=args, env={})
    matches_to_command(matches)
  } catch {
    _ =>
      if args.is_empty() {
        Command::Help
      } else {
        Command::Unknown(args[0])
      }
  }
}
