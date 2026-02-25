///|
/// Plugin loader
/// Scans directories and loads plugin manifests

///|
/// Plugin loader configuration
pub struct PluginLoaderConfig {
  /// Base directory for plugins
  plugin_dir : String
  /// Manifest filename (default: manifest.json)
  manifest_filename : String
  /// Whether to validate manifests
  validate : Bool
  /// Whether to skip invalid manifests
  skip_invalid : Bool
}

///|
/// Default loader config
pub fn PluginLoaderConfig::default(plugin_dir~ : String) -> PluginLoaderConfig {
  {
    plugin_dir,
    manifest_filename: "manifest.json",
    validate: true,
    skip_invalid: true,
  }
}

///|
/// Plugin loader result
pub struct LoadedPlugin {
  /// Plugin manifest
  manifest : @interfaces.PluginManifest
  /// Plugin directory path
  plugin_path : String
  /// Raw manifest JSON
  raw_manifest : Json
}

///|
/// Scan plugins directory and return list of plugin directory names
/// Does not load manifests, just finds plugin directories
pub fn scan_plugins_directory(
  base_path : String,
  list_dir : (String) -> Array[String] raise,
) -> Array[String] raise {
  let dirs = list_dir(base_path)
  let result : Array[String] = []
  for dir in dirs {
    // Skip hidden directories and files
    if not(dir.has_prefix(".")) {
      result.push(dir)
    }
  }
  result
}

///|
/// Load a single plugin manifest from a directory
pub fn load_plugin_manifest(
  plugin_dir : String,
  manifest_filename : String,
  read_file : (String) -> String raise,
) -> LoadedPlugin raise {
  let manifest_path = "\{plugin_dir}/\{manifest_filename}"
  let content = read_file(manifest_path)
  let json = @json.parse(content) catch {
    e =>
      raise @interfaces.PluginError::InvalidManifest("JSON parse error: \{e}")
  }
  match parse_manifest(json) {
    Some(manifest) => { manifest, plugin_path: plugin_dir, raw_manifest: json }
    None =>
      raise @interfaces.PluginError::InvalidManifest(
        "Invalid manifest format in \{manifest_path}",
      )
  }
}

///|
/// Load all plugins from a directory
pub fn load_all_plugins(
  config : PluginLoaderConfig,
  list_dir : (String) -> Array[String] raise,
  read_file : (String) -> String raise,
) -> Array[LoadedPlugin] raise {
  let plugin_dirs = scan_plugins_directory(config.plugin_dir, list_dir)
  let loaded : Array[LoadedPlugin] = []
  for dir_name in plugin_dirs {
    let plugin_path = "\{config.plugin_dir}/\{dir_name}"
    try {
      let plugin = load_plugin_manifest(
        plugin_path,
        config.manifest_filename,
        read_file,
      )
      loaded.push(plugin)
    } catch {
      e => if not(config.skip_invalid) { raise e }
      // Skip invalid plugins silently when skip_invalid is true
    }
  }
  loaded
}

///|
/// Extended manifest with additional fields for dynamic plugin management
pub struct ExtendedManifest {
  /// Base manifest
  base : @interfaces.PluginManifest
  /// Whether plugin is enabled
  enabled : Bool
  /// Whether to auto-start on load
  auto_start : Bool
  /// Stdio configuration
  stdio : @interfaces.PluginStdioConfig?
  /// WebSocket configuration
  websocket : @interfaces.PluginWebSocketConfig?
  /// Auth configuration
  auth : PluginAuthConfigParsed?
  /// TLS configuration
  tls : PluginTlsConfigParsed?
  /// Capability schemas
  capability_schemas : Map[String, CapabilitySchemaParsed]
}

///|
/// Parsed auth config from manifest
pub struct PluginAuthConfigParsed {
  /// Auth mode
  mode : String
  /// Host token (may contain env var references)
  host_token : String?
  /// Plugin token (may contain env var references)
  plugin_token : String?
  /// Token header name
  token_header : String
}

///|
/// Parsed TLS config from manifest
pub struct PluginTlsConfigParsed {
  /// Whether TLS is enabled
  enabled : Bool
  /// Whether to verify host
  verify_host : Bool
  /// CA certificate path
  ca_cert_path : String?
  /// Client certificate path
  client_cert_path : String?
  /// Client key path
  client_key_path : String?
}

///|
/// Parsed capability schema
pub struct CapabilitySchemaParsed {
  /// Capability description
  description : String
  /// Parameters JSON schema
  parameters : Json
  /// Return value schema
  returns : Json?
  /// Examples
  examples : Array[Json]
}

///|
/// Parse extended manifest from JSON
pub fn parse_extended_manifest(json : Json) -> ExtendedManifest? {
  match parse_manifest(json) {
    Some(base) => {
      let enabled = match json {
        { "enabled": True, .. } | { .. } if not(json_has_field(json, "enabled")) =>
          true
        _ => false
      }
      let auto_start = match json {
        { "autoStart": True, .. } | { .. } if not(
            json_has_field(json, "autoStart"),
          ) => true
        _ => false
      }
      let stdio = parse_stdio_config(json)
      let websocket = parse_websocket_config(json)
      let auth = parse_auth_config(json)
      let tls = parse_tls_config(json)
      let capability_schemas = parse_capability_schemas(json)
      Some({
        base,
        enabled,
        auto_start,
        stdio,
        websocket,
        auth,
        tls,
        capability_schemas,
      })
    }
    None => None
  }
}

///|
/// Check if JSON object has a field
fn json_has_field(json : Json, field : String) -> Bool {
  match json {
    Object(obj) => obj.contains(field)
    _ => false
  }
}

///|
/// Parse stdio config from manifest JSON
fn parse_stdio_config(json : Json) -> @interfaces.PluginStdioConfig? {
  match json {
    { "stdio": Object(cfg), .. } => {
      let command = match cfg.get("command") {
        Some(String(c)) => c
        _ => return None
      }
      let args = match cfg.get("args") {
        Some(Array(arr)) => {
          let result : Array[String] = []
          for item in arr {
            match item {
              String(s) => result.push(s)
              _ => ()
            }
          }
          result
        }
        _ => []
      }
      let cwd = match cfg.get("cwd") {
        Some(String(c)) => Some(c)
        _ => None
      }
      let env : Map[String, String] = {}
      match cfg.get("env") {
        Some(Object(e)) =>
          for k, v in e {
            match v {
              String(s) => env[k] = s
              _ => ()
            }
          }
        _ => ()
      }
      let framing = match cfg.get("framing") {
        Some(String("length_prefixed")) =>
          @interfaces.StdioFraming::LengthPrefixed
        _ => @interfaces.StdioFraming::NewlineDelimited
      }
      let startup_timeout_ms = match cfg.get("startupTimeoutMs") {
        Some(Number(n, ..)) => n.to_int()
        _ => 30000
      }
      let restart_policy = parse_restart_policy(cfg.get("restartPolicy"))
      Some({
        command,
        args,
        cwd,
        env,
        framing,
        startup_timeout_ms,
        restart_policy,
      })
    }
    _ => None
  }
}

///|
/// Parse restart policy from JSON
fn parse_restart_policy(json : Json?) -> @interfaces.RestartPolicy {
  match json {
    Some(String("never")) => @interfaces.RestartPolicy::Never
    Some(Object(cfg)) =>
      match cfg.get("type") {
        Some(String("onFailure")) => {
          let max_retries = match cfg.get("maxRetries") {
            Some(Number(n, ..)) => n.to_int()
            _ => 3
          }
          let delay_ms = match cfg.get("delayMs") {
            Some(Number(n, ..)) => n.to_int()
            _ => 1000
          }
          @interfaces.RestartPolicy::OnFailure(max_retries~, delay_ms~)
        }
        Some(String("always")) => {
          let base_delay_ms = match cfg.get("baseDelayMs") {
            Some(Number(n, ..)) => n.to_int()
            _ => 1000
          }
          let max_delay_ms = match cfg.get("maxDelayMs") {
            Some(Number(n, ..)) => n.to_int()
            _ => 30000
          }
          @interfaces.RestartPolicy::Always(base_delay_ms~, max_delay_ms~)
        }
        _ => @interfaces.RestartPolicy::OnFailure(max_retries=3, delay_ms=1000)
      }
    _ => @interfaces.RestartPolicy::OnFailure(max_retries=3, delay_ms=1000)
  }
}

///|
/// Parse reconnect config from JSON
fn parse_reconnect_config(json : Json?) -> @interfaces.ReconnectConfig {
  match json {
    Some(Object(r)) => {
      let enabled = match r.get("enabled") {
        Some(False) => false
        _ => true
      }
      let max_attempts = match r.get("maxAttempts") {
        Some(Number(n, ..)) => n.to_int()
        _ => 10
      }
      let base_delay_ms = match r.get("baseDelayMs") {
        Some(Number(n, ..)) => n.to_int()
        _ => 1000
      }
      let max_delay_ms = match r.get("maxDelayMs") {
        Some(Number(n, ..)) => n.to_int()
        _ => 30000
      }
      { enabled, max_attempts, base_delay_ms, max_delay_ms }
    }
    _ => @interfaces.ReconnectConfig::default()
  }
}

///|
/// Parse WebSocket config from manifest JSON
fn parse_websocket_config(json : Json) -> @interfaces.PluginWebSocketConfig? {
  match json {
    { "websocket": Object(cfg), .. } => {
      let url = match cfg.get("url") {
        Some(String(u)) => u
        _ => return None
      }
      let headers : Map[String, String] = {}
      match cfg.get("headers") {
        Some(Object(h)) =>
          for k, v in h {
            match v {
              String(s) => headers[k] = s
              _ => ()
            }
          }
        _ => ()
      }
      let reconnect : @interfaces.ReconnectConfig = parse_reconnect_config(
        cfg.get("reconnect"),
      )
      let heartbeat_interval_ms = match cfg.get("heartbeatIntervalMs") {
        Some(Number(n, ..)) => n.to_int()
        _ => 30000
      }
      Some({ url, headers, reconnect, heartbeat_interval_ms })
    }
    _ => None
  }
}

///|
/// Parse auth config from manifest JSON
fn parse_auth_config(json : Json) -> PluginAuthConfigParsed? {
  match json {
    { "auth": Object(cfg), .. } => {
      let mode = match cfg.get("mode") {
        Some(String(m)) => m
        _ => "none"
      }
      let host_token = match cfg.get("hostToken") {
        Some(String(t)) => Some(t)
        _ => None
      }
      let plugin_token = match cfg.get("pluginToken") {
        Some(String(t)) => Some(t)
        _ => None
      }
      let token_header = match cfg.get("tokenHeader") {
        Some(String(h)) => h
        _ => "X-Plugin-Token"
      }
      Some({ mode, host_token, plugin_token, token_header })
    }
    _ => None
  }
}

///|
/// Parse TLS config from manifest JSON
fn parse_tls_config(json : Json) -> PluginTlsConfigParsed? {
  match json {
    { "tls": Object(cfg), .. } => {
      let enabled = match cfg.get("enabled") {
        Some(True) => true
        _ => false
      }
      let verify_host = match cfg.get("verifyHost") {
        Some(False) => false
        _ => true
      }
      let ca_cert_path = match cfg.get("caCert") {
        Some(String(p)) => Some(p)
        _ => None
      }
      let client_cert_path = match cfg.get("clientCert") {
        Some(String(p)) => Some(p)
        _ => None
      }
      let client_key_path = match cfg.get("clientKey") {
        Some(String(p)) => Some(p)
        _ => None
      }
      Some({
        enabled,
        verify_host,
        ca_cert_path,
        client_cert_path,
        client_key_path,
      })
    }
    _ => None
  }
}

///|
/// Parse capability schemas from manifest JSON
fn parse_capability_schemas(json : Json) -> Map[String, CapabilitySchemaParsed] {
  let result : Map[String, CapabilitySchemaParsed] = {}
  match json {
    { "capabilitySchemas": Object(schemas), .. } =>
      for name, schema in schemas {
        match parse_single_capability_schema(schema) {
          Some(parsed) => result[name] = parsed
          None => ()
        }
      }
    _ => ()
  }
  result
}

///|
/// Parse a single capability schema
fn parse_single_capability_schema(json : Json) -> CapabilitySchemaParsed? {
  match json {
    Object(obj) => {
      let description = match obj.get("description") {
        Some(String(d)) => d
        _ => ""
      }
      let parameters = match obj.get("parameters") {
        Some(p) => p
        _ => Json::object({})
      }
      let returns = obj.get("returns")
      let examples = match obj.get("examples") {
        Some(Array(arr)) => arr
        _ => []
      }
      Some({ description, parameters, returns, examples })
    }
    _ => None
  }
}

///|
/// Resolve environment variable references in a string
/// Format: ${ENV_VAR_NAME}
pub fn resolve_env_vars(
  value : String,
  get_env : (String) -> String?,
) -> String {
  // Simple implementation - find and replace ${VAR} patterns
  let chars = value.to_array()
  let result : StringBuilder = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    if i + 1 < chars.length() && chars[i] == '$' && chars[i + 1] == '{' {
      // Found start of variable reference
      let var_start = i + 2
      let mut var_end = var_start
      while var_end < chars.length() && chars[var_end] != '}' {
        var_end = var_end + 1
      }
      if var_end < chars.length() && chars[var_end] == '}' {
        // Extract variable name
        let var_name = StringBuilder::new()
        for j = var_start; j < var_end; j = j + 1 {
          var_name.write_char(chars[j])
        }
        // Get replacement value
        let replacement = match get_env(var_name.to_string()) {
          Some(v) => v
          None => ""
        }
        result.write_string(replacement)
        i = var_end + 1
      } else {
        // No closing brace found, output as-is
        result.write_char(chars[i])
        i = i + 1
      }
    } else {
      result.write_char(chars[i])
      i = i + 1
    }
  }
  result.to_string()
}
