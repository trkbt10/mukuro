///|
/// Daemon IPC Communication
/// IPC request/response functions for daemon control

///|
/// デーモンへIPCリクエストを送信
fn daemon_ipc_request(command : String) -> String? {
  match daemon_ipc_response_hook.value {
    Some(hook) => return hook(command)
    None => ()
  }
  let buffer = Bytes::new(512)
  let command_code = if command == "stop" { 2 } else { 1 }
  let token = @native.c_read_gateway_token()
  if token < 0 {
    return None
  }
  let session_id = @native.c_read_gateway_session_id()
  let read_len = @native.c_ipc_client_request(
    token,
    session_id,
    command_code,
    @native.string_to_cstring(current_cli_client_id()),
    buffer,
    512,
  )
  if read_len <= 0 {
    return None
  }
  Some(
    Bytes::from_iter(buffer[:read_len].iter())
    .to_unchecked_string()
    .trim(chars=" \t\n\r")
    .to_string(),
  )
}

///|
/// デーモンへstatus要求（IPC）
pub fn query_daemon_status(pid : Int, as_json : Bool) -> CliResult {
  let response = daemon_ipc_request("status").unwrap_or("")
  if response.has_prefix("OK running ") {
    let parts = response.split(" ").collect()
    let runtime_pid = if parts.length() > 2 { parts[2] } else { "\{pid}" }
    let uptime_sec = if parts.length() > 3 { parts[3] } else { "0" }
    if as_json {
      CliResult::Ok(
        "{\"mode\":\"daemon\",\"state\":\"running\",\"pid\":\{runtime_pid},\"uptime_sec\":\{uptime_sec},\"ipc\":\"connected\",\"pid_file\":\"\{@control.default_pid_path()}\",\"socket\":\"\{@control.default_ipc_socket_path()}\"}",
      )
    } else {
      CliResult::Ok(
        "Gateway Status (daemon mode):\n  State: running\n  PID: \{runtime_pid}\n  Uptime: \{uptime_sec}s\n  IPC: connected\n  PID file: \{@control.default_pid_path()}\n  Socket: \{@control.default_ipc_socket_path()}",
      )
    }
  } else if response.has_prefix("ERR unauthorized") {
    CliResult::Error("Daemon IPC authentication failed")
  } else if response == "" {
    CliResult::Error("Daemon IPC unavailable")
  } else {
    CliResult::Error("Daemon IPC error: \{response}")
  }
}

///|
/// デーモンへstop要求（IPC）
pub fn request_daemon_stop(pid : Int) -> CliResult {
  ignore(pid)
  let response = daemon_ipc_request("stop").unwrap_or("")
  if response.has_prefix("OK stopping") {
    CliResult::Ok("Stop request sent to gateway daemon via IPC")
  } else if response.has_prefix("ERR unauthorized") {
    CliResult::Error("Daemon IPC authentication failed")
  } else if response == "" {
    CliResult::Error("Daemon IPC unavailable")
  } else {
    CliResult::Error("Daemon IPC error: \{response}")
  }
}
