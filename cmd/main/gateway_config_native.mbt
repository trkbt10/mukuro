///|
/// gateway --config 読み込み実装（Native専用）

///|
fn read_config_text(path : String) -> String raise @interfaces.ControlError {
  let buffer_len = 65536
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file(
    @native.string_to_cstring(path),
    buffer,
    buffer_len,
  )
  if read_len < 0 {
    raise @interfaces.ControlError::ConfigError(
      "Config file not found or unreadable: \{path}",
    )
  }
  let data = if read_len == 0 {
    Bytes::new(0)
  } else {
    Bytes::from_iter(buffer[:read_len].iter())
  }
  @utf8.decode(data[:]) catch {
    _ =>
      raise @interfaces.ControlError::ConfigError(
        "Config file is not valid UTF-8: \{path}",
      )
  }
}

///|
fn parse_bool_field(
  obj : Map[String, Json],
  key : String,
  default_value : Bool,
) -> Bool raise @interfaces.ControlError {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    Some(_) =>
      raise @interfaces.ControlError::ConfigError(
        "Field '\{key}' must be a boolean",
      )
    None => default_value
  }
}

///|
fn parse_string_field(
  obj : Map[String, Json],
  key : String,
  default_value : String,
) -> String raise @interfaces.ControlError {
  match obj.get(key) {
    Some(String(s)) => s
    Some(_) =>
      raise @interfaces.ControlError::ConfigError(
        "Field '\{key}' must be a string",
      )
    None => default_value
  }
}

///|
fn parse_int_field(
  obj : Map[String, Json],
  key : String,
  default_value : Int,
) -> Int raise @interfaces.ControlError {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
    Some(_) =>
      raise @interfaces.ControlError::ConfigError(
        "Field '\{key}' must be a number",
      )
    None => default_value
  }
}

///|
fn parse_health_endpoint(
  root : Map[String, Json],
  default_cfg : @interfaces.HealthEndpointConfig,
) -> @interfaces.HealthEndpointConfig raise @interfaces.ControlError {
  match root.get("health_endpoint") {
    Some(Object(obj)) =>
      {
        path: parse_string_field(obj, "path", default_cfg.path),
        require_auth: parse_bool_field(
          obj,
          "require_auth",
          default_cfg.require_auth,
        ),
        include_details: parse_bool_field(
          obj,
          "include_details",
          default_cfg.include_details,
        ),
        cache_seconds: parse_int_field(
          obj,
          "cache_seconds",
          default_cfg.cache_seconds,
        ),
      }
    Some(Null) => default_cfg
    Some(_) =>
      raise @interfaces.ControlError::ConfigError(
        "Field 'health_endpoint' must be an object",
      )
    None => default_cfg
  }
}

///|
fn root_gateway_object(
  json : Json,
) -> Map[String, Json] raise @interfaces.ControlError {
  let obj = match json {
    Object(o) => o
    _ =>
      raise @interfaces.ControlError::ConfigError(
        "Config must be a JSON object",
      )
  }
  match obj.get("gateway") {
    Some(Object(gw)) => gw
    Some(_) =>
      raise @interfaces.ControlError::ConfigError(
        "Field 'gateway' must be an object",
      )
    None => obj
  }
}

///|
pub fn load_gateway_config_impl(
  config_path : String,
) -> @interfaces.GatewayConfig raise @interfaces.ControlError {
  let raw = read_config_text(config_path)
  let json : Json = @json.parse(raw) catch {
    e =>
      raise @interfaces.ControlError::ConfigError(
        "Invalid config JSON: \{e.to_string()}",
      )
  }
  let root = root_gateway_object(json)
  let defaults = @interfaces.GatewayConfig::default()
  {
    host: parse_string_field(root, "host", defaults.host),
    port: parse_int_field(root, "port", defaults.port),
    auth_token: parse_string_field(root, "auth_token", defaults.auth_token),
    health_endpoint: parse_health_endpoint(root, defaults.health_endpoint),
    auto_connect_channels: parse_bool_field(
      root,
      "auto_connect_channels",
      defaults.auto_connect_channels,
    ),
  }
}
