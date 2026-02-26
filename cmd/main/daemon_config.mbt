///|
/// Daemon Configuration
/// Startup configuration, constants, parsing and loading

///|
/// テスト用IPCレスポンスフック
struct IpcResponseHookCell {
  mut value : ((String) -> String?)?
}

///|
let daemon_ipc_response_hook : IpcResponseHookCell = { value: None }

///|
/// IPCトークンのローテーション間隔（秒）
let daemon_token_rotation_interval_sec : Int64 = 300

///|
/// ローテーション直後に直前tokenを許容するgrace期間（秒）
let daemon_prev_token_grace_sec : Int64 = 30

///|
/// token最大寿命（秒）
let daemon_token_max_age_sec : Int64 = 900

///|
/// 認証失敗レート制御の窓（秒）
let daemon_auth_fail_window_sec : Int64 = 10

///|
/// 窓内失敗閾値
let daemon_auth_fail_threshold : Int = 5

///|
/// レート制限（全IPC拒否）継続秒数
let daemon_auth_rate_limit_sec : Int64 = 15

///|
let daemon_startup_config_path = ".mukuro/daemon-startup.json"

///|
let daemon_auth_log_path = ".mukuro/gateway-auth.log"

///|
struct DaemonStartupConfig {
  gateway_config : @interfaces.GatewayConfig
  runtime_model_config_path : String
  control_api : Bool
}

///|
fn daemon_startup_default() -> DaemonStartupConfig {
  {
    gateway_config: @interfaces.GatewayConfig::default(),
    runtime_model_config_path: default_runtime_config_path(),
    control_api: false,
  }
}

///|
fn write_daemon_startup_config(
  opts : GatewayStartOptions,
  config : @interfaces.GatewayConfig,
) -> Bool {
  let payload : Json = {
    "runtime_model_config_path": opts.config_path.unwrap_or(
      default_runtime_config_path(),
    ),
    "control_api": opts.control_api,
    "gateway": {
      "host": config.host,
      "port": config.port,
      "auth_token": config.auth_token,
      "auto_connect_channels": config.auto_connect_channels,
      "health_endpoint": {
        "path": config.health_endpoint.path,
        "require_auth": config.health_endpoint.require_auth,
        "include_details": config.health_endpoint.include_details,
        "cache_seconds": config.health_endpoint.cache_seconds,
      },
    },
  }
  let text = payload.stringify()
  @native.c_write_text_file(
    @native.string_to_cstring(daemon_startup_config_path),
    @native.string_to_cstring(text),
  ) ==
  0
}

///|
fn parse_daemon_startup_config(content : String) -> DaemonStartupConfig {
  let root_json : Json = @json.parse(content) catch {
    _ => return daemon_startup_default()
  }
  let root = match root_json {
    Object(obj) => obj
    _ => return daemon_startup_default()
  }
  let runtime_model_config_path = match root.get("runtime_model_config_path") {
    Some(String(path)) => path
    _ => default_runtime_config_path()
  }
  let control_api = match root.get("control_api") {
    Some(True) => true
    Some(False) => false
    _ => false
  }
  let base_cfg = @interfaces.GatewayConfig::default()
  let gateway = match root.get("gateway") {
    Some(Object(obj)) => obj
    _ =>
      return {
        gateway_config: base_cfg,
        runtime_model_config_path,
        control_api,
      }
  }
  let health_base = base_cfg.health_endpoint
  let health_endpoint : @interfaces.HealthEndpointConfig = match
    gateway.get("health_endpoint") {
    Some(Object(h)) =>
      {
        path: match h.get("path") {
          Some(String(v)) => v
          _ => health_base.path
        },
        require_auth: match h.get("require_auth") {
          Some(True) => true
          Some(False) => false
          _ => health_base.require_auth
        },
        include_details: match h.get("include_details") {
          Some(True) => true
          Some(False) => false
          _ => health_base.include_details
        },
        cache_seconds: match h.get("cache_seconds") {
          Some(Number(n, ..)) => n.to_int()
          _ => health_base.cache_seconds
        },
      }
    _ => health_base
  }
  let gateway_config : @interfaces.GatewayConfig = {
    host: match gateway.get("host") {
      Some(String(v)) => v
      _ => base_cfg.host
    },
    port: match gateway.get("port") {
      Some(Number(n, ..)) => n.to_int()
      _ => base_cfg.port
    },
    auth_token: match gateway.get("auth_token") {
      Some(String(v)) => v
      _ => base_cfg.auth_token
    },
    health_endpoint,
    auto_connect_channels: match gateway.get("auto_connect_channels") {
      Some(True) => true
      Some(False) => false
      _ => base_cfg.auto_connect_channels
    },
  }
  { gateway_config, runtime_model_config_path, control_api }
}

///|
fn load_daemon_startup_config() -> DaemonStartupConfig {
  let buffer_len = 65536
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file(
    @native.string_to_cstring(daemon_startup_config_path),
    buffer,
    buffer_len,
  )
  if read_len <= 0 {
    return daemon_startup_default()
  }
  let data = Bytes::from_iter(buffer[:read_len].iter())
  let content = @utf8.decode(data[:]) catch {
    _ => return daemon_startup_default()
  }
  parse_daemon_startup_config(content)
}

///|
/// テスト用: IPCレスポンスフックを設定
pub fn set_daemon_ipc_response_hook_for_test(
  hook : (String) -> String?,
) -> Unit {
  daemon_ipc_response_hook.value = Some(hook)
}

///|
/// テスト用: IPCレスポンスフックを解除
pub fn clear_daemon_ipc_response_hook_for_test() -> Unit {
  daemon_ipc_response_hook.value = None
}
