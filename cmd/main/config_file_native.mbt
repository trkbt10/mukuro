///|
/// Native config file helpers (Source of Truth)

///|
fn read_config_text_impl(
  path : String,
) -> String raise @interfaces.ControlError {
  let buffer_len = 65536
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file_bytes(
    @native.string_to_utf8_cstring(path),
    buffer,
    buffer_len,
  )
  if read_len < 0 {
    raise @interfaces.ControlError::ConfigError(
      "Config file not found or unreadable: \{path}",
    )
  }
  match @bytes.decode_utf8(buffer[:read_len]) {
    Some(s) => s
    None =>
      raise @interfaces.ControlError::ConfigError(
        "Config file is not valid UTF-8: \{path}",
      )
  }
}

///|
fn parse_config_root_impl(
  raw : String,
) -> Map[String, Json] raise @interfaces.ControlError {
  match @config_json_accessors.parse_root_object(raw) {
    Ok(root) => root
    Err(message) => raise @interfaces.ControlError::ConfigError(message)
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
  match @config_json_accessors.bool_field_or_default(obj, key, default_value) {
    Ok(value) => value
    Err(message) => raise @interfaces.ControlError::ConfigError(message)
  }
}

///|
fn parse_string_field_impl(
  obj : Map[String, Json],
  key : String,
  default_value : String,
) -> String raise @interfaces.ControlError {
  match
    @config_json_accessors.string_field_or_default(obj, key, default_value) {
    Ok(value) => value
    Err(message) => raise @interfaces.ControlError::ConfigError(message)
  }
}

///|
fn parse_int_field_impl(
  obj : Map[String, Json],
  key : String,
  default_value : Int,
) -> Int raise @interfaces.ControlError {
  match @config_json_accessors.int_field_or_default(obj, key, default_value) {
    Ok(value) => value
    Err(message) => raise @interfaces.ControlError::ConfigError(message)
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
