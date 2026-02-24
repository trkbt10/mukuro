///|
/// Native config file helpers (Source of Truth)

fn read_config_text_impl(
  path : String,
) -> String raise @interfaces.ControlError {
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
fn parse_config_root_impl(
  raw : String,
) -> Map[String, Json] raise @interfaces.ControlError {
  let json : Json = @json.parse(raw) catch {
    e =>
      raise @interfaces.ControlError::ConfigError(
        "Invalid config JSON: \{e.to_string()}",
      )
  }
  match json {
    Object(o) => o
    _ =>
      raise @interfaces.ControlError::ConfigError(
        "Config must be a JSON object",
      )
  }
}

///|
fn load_config_root_impl(
  config_path : String,
) -> Map[String, Json] raise @interfaces.ControlError {
  parse_config_root_impl(read_config_text_impl(config_path))
}

///|
fn parse_bool_field_impl(
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
fn parse_string_field_impl(
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
fn parse_int_field_impl(
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
fn root_gateway_object_impl(
  root : Map[String, Json],
) -> Map[String, Json] raise @interfaces.ControlError {
  match root.get("gateway") {
    Some(Object(gw)) => gw
    Some(_) =>
      raise @interfaces.ControlError::ConfigError(
        "Field 'gateway' must be an object",
      )
    None => root
  }
}
