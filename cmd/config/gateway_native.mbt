///|
/// gateway --config 読み込み実装（Native専用）

///|
fn parse_health_endpoint(
  root : Map[String, Json],
  default_cfg : @interfaces.HealthEndpointConfig,
) -> @interfaces.HealthEndpointConfig raise @interfaces.ControlError {
  match root.get("health_endpoint") {
    Some(Object(obj)) =>
      {
        path: parse_string_field_impl(obj, "path", default_cfg.path),
        require_auth: parse_bool_field_impl(
          obj,
          "require_auth",
          default_cfg.require_auth,
        ),
        include_details: parse_bool_field_impl(
          obj,
          "include_details",
          default_cfg.include_details,
        ),
        cache_seconds: parse_int_field_impl(
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
pub fn load_gateway_config_impl(
  config_path : String,
) -> @interfaces.GatewayConfig raise @interfaces.ControlError {
  let root = root_gateway_object_impl(load_config_root_impl(config_path))
  let defaults = @interfaces.GatewayConfig::default()
  {
    host: parse_string_field_impl(root, "host", defaults.host),
    port: parse_int_field_impl(root, "port", defaults.port),
    auth_token: parse_string_field_impl(root, "auth_token", defaults.auth_token),
    health_endpoint: parse_health_endpoint(root, defaults.health_endpoint),
    auto_connect_channels: parse_bool_field_impl(
      root,
      "auto_connect_channels",
      defaults.auto_connect_channels,
    ),
  }
}
