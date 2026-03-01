///|
/// Daemon Auth Log
/// Authentication log parsing and querying

///|
fn parse_auth_log_string_field(
  obj : Map[String, Json],
  key : String,
) -> String? {
  match obj.get(key) {
    Some(String(v)) => Some(v)
    _ => None
  }
}

///|
fn parse_auth_log_int64_field(obj : Map[String, Json], key : String) -> Int64? {
  match obj.get(key) {
    Some(Number(v, ..)) => Some(v.to_int64())
    _ => None
  }
}

///|
fn read_auth_log_text() -> String? {
  let buffer_len = 262144
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file_bytes(
    @native.string_to_utf8_cstring(daemon_auth_log_path()),
    buffer,
    buffer_len,
  )
  if read_len <= 0 {
    return None
  }
  @bytes.decode_utf8(buffer[:read_len])
}

///|
pub fn query_gateway_auth_log(
  since_seconds : Int64,
  as_json : Bool,
) -> CliResult {
  let content = read_auth_log_text().unwrap_or("")
  if content.length() == 0 {
    if as_json {
      return CliResult::Ok(
        "{\"path\":\"\{daemon_auth_log_path()}\",\"total\":0,\"since_seconds\":\{since_seconds}}",
      )
    }
    return CliResult::Ok(
      "Gateway auth log is empty or not found: \{daemon_auth_log_path()}",
    )
  }

  let now = @native.c_time()
  let cutoff = if since_seconds > 0 { now - since_seconds } else { 0 }
  let mut total = 0
  let event_counts : Map[String, Int] = {}
  let client_counts : Map[String, Int] = {}
  for line_sv in content.split("\n") {
    let line = line_sv.to_string().trim(chars=" \t\n\r").to_string()
    if line.length() == 0 {
      continue
    }
    let row_json : Json = @json.parse(line) catch { _ => continue }
    let row = match row_json {
      Object(obj) => obj
      _ => continue
    }
    let ts = parse_auth_log_int64_field(row, "ts").unwrap_or(0)
    if cutoff > 0 && ts < cutoff {
      continue
    }
    total = total + 1
    let event = parse_auth_log_string_field(row, "event").unwrap_or("unknown")
    event_counts[event] = event_counts.get(event).unwrap_or(0) + 1
    let client_id = parse_auth_log_string_field(row, "client_id").unwrap_or(
      "unknown",
    )
    client_counts[client_id] = client_counts.get(client_id).unwrap_or(0) + 1
  }

  if as_json {
    let events_obj : Map[String, Json] = {}
    for name, count in event_counts {
      events_obj[name] = Json::number(count.to_double())
    }
    let clients_obj : Map[String, Json] = {}
    for name, count in client_counts {
      clients_obj[name] = Json::number(count.to_double())
    }
    let payload : Json = {
      "path": daemon_auth_log_path(),
      "total": total,
      "since_seconds": Json::number(since_seconds.to_double()),
      "cutoff_ts": Json::number(cutoff.to_double()),
      "events": Json::object(events_obj),
      "clients": Json::object(clients_obj),
    }
    return CliResult::Ok(payload.stringify())
  }

  let mut output = "Gateway Auth Log Summary\n"
  output = output + "  Path: \{daemon_auth_log_path()}\n"
  output = output + "  Total: \{total}\n"
  output = output + "  Since: last \{since_seconds}s\n"
  output = output + "  Events:\n"
  for name, count in event_counts {
    output = output + "    - \{name}: \{count}\n"
  }
  output = output + "  Clients:\n"
  for name, count in client_counts {
    output = output + "    - \{name}: \{count}\n"
  }
  CliResult::Ok(output)
}
