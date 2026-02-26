///|
/// CLI Argument Parsing
/// Functions for parsing command line arguments

///|
/// グローバルオプションをパースし、残りの引数を返す
pub fn parse_global_options(
  args : Array[String],
) -> (GlobalOptions, Array[String]) {
  let opts : GlobalOptions = { path_mode: @paths.PathMode::Standard }
  let remaining : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--local" => {
        opts.path_mode = @paths.PathMode::Local
        i = i + 1
      }
      "--data-dir" =>
        if i + 1 < args.length() {
          opts.path_mode = @paths.PathMode::Custom(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      _ => {
        remaining.push(arg)
        i = i + 1
      }
    }
  }
  (opts, remaining)
}

///|
/// 配列からスライスを作成（インデックス1から）
fn slice_from_1(arr : Array[String]) -> Array[String] {
  let result : Array[String] = []
  for i in 1..<arr.length() {
    result.push(arr[i])
  }
  result
}

///|
/// 引数配列からコマンドをパース
pub fn parse_args(args : Array[String]) -> Command {
  if args.is_empty() {
    return Command::Help
  }
  let cmd_name = args[0]
  match cmd_name {
    "help" | "--help" | "-h" => Command::Help
    "version" | "--version" | "-v" => Command::Version
    "--daemon-child" =>
      // 内部使用：posix_spawn で起動されたデーモン子プロセス
      if args.length() > 1 {
        Command::DaemonChild(args[1])
      } else {
        Command::Unknown("--daemon-child requires pid_path argument")
      }
    "onboard" => parse_onboard_args(slice_from_1(args)[:])
    "gateway" =>
      // gateway 単体でも start として動作（他実装との互換性）
      parse_gateway_args(slice_from_1(args)[:])
    "cron" =>
      if args.length() > 1 {
        parse_cron_args(slice_from_1(args)[:])
      } else {
        Command::Cron(CronCommand::Unknown(""))
      }
    _ => Command::Unknown(cmd_name)
  }
}

///|
/// ArrayViewをArrayに変換
fn array_view_to_array(view : ArrayView[String]) -> Array[String] {
  let arr : Array[String] = []
  for item in view {
    arr.push(item)
  }
  arr
}

///|
/// onboardコマンドの引数をパース
fn parse_onboard_args(args : ArrayView[String]) -> Command {
  let opts : OnboardOptions = {
    provider: None,
    api_key: None,
    default_model: None,
    output_path: None,
  }
  let arr = array_view_to_array(args)
  let mut i = 0
  while i < arr.length() {
    let arg = arr[i]
    match arg {
      "--provider" =>
        if i + 1 < arr.length() {
          opts.provider = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--api-key" =>
        if i + 1 < arr.length() {
          opts.api_key = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--model" =>
        if i + 1 < arr.length() {
          opts.default_model = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--output" =>
        if i + 1 < arr.length() {
          opts.output_path = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      _ => i = i + 1
    }
  }
  Command::Onboard(opts)
}

///|
/// gatewayコマンドの引数をパース
/// サブコマンドなし or "--" で始まる引数の場合は start として扱う（他実装との互換性）
fn parse_gateway_args(args : ArrayView[String]) -> Command {
  if args.is_empty() {
    // `mukuro gateway` = `mukuro gateway start` (他実装との互換性)
    let opts = default_gateway_start_opts()
    return Command::Gateway(GatewayCommand::Start(opts))
  }
  let arr = array_view_to_array(args)
  let subcmd = arr[0]
  // サブコマンドが "--" で始まる場合は start のオプションとして扱う
  if subcmd.has_prefix("--") || subcmd.has_prefix("-") {
    let opts = parse_gateway_start_opts(args)
    return Command::Gateway(GatewayCommand::Start(opts))
  }
  match subcmd {
    "start" => {
      let opts = parse_gateway_start_opts(slice_from_1(arr)[:])
      Command::Gateway(GatewayCommand::Start(opts))
    }
    "run" => {
      // OpenClaw互換: `gateway run` = `gateway start`
      let opts = parse_gateway_start_opts(slice_from_1(arr)[:])
      Command::Gateway(GatewayCommand::Start(opts))
    }
    "status" => {
      let opts = parse_gateway_status_opts(slice_from_1(arr)[:])
      Command::Gateway(GatewayCommand::Status(opts))
    }
    "stop" => Command::Gateway(GatewayCommand::Stop)
    "auth-log" => {
      let opts = parse_gateway_auth_log_opts(slice_from_1(arr)[:])
      Command::Gateway(GatewayCommand::AuthLog(opts))
    }
    _ => Command::Gateway(GatewayCommand::Unknown(subcmd))
  }
}

///|
/// デフォルトのGateway起動オプション
fn default_gateway_start_opts() -> GatewayStartOptions {
  {
    config_path: None,
    host: None,
    port: None,
    debug: false,
    daemon: false,
    control_api: false,
  }
}

///|
/// gateway statusオプションをパース
fn parse_gateway_status_opts(args : ArrayView[String]) -> GatewayStatusOptions {
  let opts : GatewayStatusOptions = { json: false }
  let arr = array_view_to_array(args)
  for arg in arr {
    if arg == "--json" {
      opts.json = true
    }
  }
  opts
}

///|
/// gateway startオプションをパース
fn parse_gateway_start_opts(args : ArrayView[String]) -> GatewayStartOptions {
  let opts : GatewayStartOptions = {
    config_path: None,
    host: None,
    port: None,
    debug: false,
    daemon: false,
    control_api: false,
  }
  let arr = array_view_to_array(args)
  let mut i = 0
  while i < arr.length() {
    let arg = arr[i]
    match arg {
      "--config" =>
        if i + 1 < arr.length() {
          opts.config_path = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--host" =>
        if i + 1 < arr.length() {
          opts.host = Some(arr[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      "--port" =>
        if i + 1 < arr.length() {
          try {
            let port_json : Json = @json.parse(arr[i + 1])
            match port_json {
              Number(n, ..) => opts.port = Some(n.to_int())
              _ => ()
            }
          } catch {
            _ => ()
          }
          i = i + 2
        } else {
          i = i + 1
        }
      "--debug" | "-d" => {
        opts.debug = true
        i = i + 1
      }
      "--daemon" | "-D" => {
        opts.daemon = true
        i = i + 1
      }
      "--control-api" => {
        opts.control_api = true
        i = i + 1
      }
      _ => i = i + 1
    }
  }
  opts
}

///|
fn parse_gateway_auth_log_opts(
  args : ArrayView[String],
) -> GatewayAuthLogOptions {
  let opts : GatewayAuthLogOptions = { since_seconds: 3600, json: false }
  let arr = array_view_to_array(args)
  let mut i = 0
  while i < arr.length() {
    let arg = arr[i]
    match arg {
      "--json" => {
        opts.json = true
        i = i + 1
      }
      "--since" =>
        if i + 1 < arr.length() {
          try {
            let parsed : Json = @json.parse(arr[i + 1])
            match parsed {
              Number(n, ..) => opts.since_seconds = n.to_int64()
              _ => ()
            }
          } catch {
            _ => ()
          }
          i = i + 2
        } else {
          i = i + 1
        }
      _ => i = i + 1
    }
  }
  opts
}

///|
/// cronコマンドの引数をパース
fn parse_cron_args(args : ArrayView[String]) -> Command {
  if args.is_empty() {
    return Command::Cron(CronCommand::Unknown(""))
  }
  let arr = array_view_to_array(args)
  let subcmd = arr[0]
  match subcmd {
    "list" => Command::Cron(CronCommand::List)
    _ => Command::Cron(CronCommand::Unknown(subcmd))
  }
}
