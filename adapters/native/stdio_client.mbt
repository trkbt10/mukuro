///|
/// Native Stdio client for plugin communication
/// Uses shell pipes to communicate with child processes

///|
/// Stdio client error
pub(all) suberror StdioClientError {
  ProcessFailed(String)
  InvalidResponse(String)
  Timeout
}

///|
/// Stdio transport adapter for plugin communication
/// Executes plugin process for each request (stateless)
pub struct NativeStdioClient {
  /// Command to execute
  command : String
  /// Arguments
  args : Array[String]
  /// Working directory
  cwd : String?
  /// Environment variables
  env : Map[String, String]
  /// Request ID counter
  mut request_id : Int
}

///|
/// Create a new Stdio client
pub fn NativeStdioClient::new(
  command~ : String,
  args~ : Array[String],
  cwd~ : String?,
  env~ : Map[String, String],
) -> NativeStdioClient {
  { command, args, cwd, env, request_id: 0 }
}

///|
/// Create from PluginStdioConfig
pub fn NativeStdioClient::from_config(
  config : @interfaces.PluginStdioConfig,
) -> NativeStdioClient {
  NativeStdioClient::new(
    command=config.command,
    args=config.args,
    cwd=config.cwd,
    env=config.env,
  )
}

///|
/// Get next request ID
fn NativeStdioClient::next_request_id(self : NativeStdioClient) -> Int {
  self.request_id = self.request_id + 1
  self.request_id
}

///|
/// Escape single quotes for shell
fn escape_shell_single_quote(s : String) -> String {
  let parts : Array[String] = s
    .split("'")
    .map(fn(sv) { sv.to_string() })
    .collect()
  parts.join("'\\''")
}

///|
/// Build the shell command for piping
fn NativeStdioClient::build_pipe_command(
  self : NativeStdioClient,
  input : String,
) -> String {
  // Escape single quotes in input
  let escaped_input = escape_shell_single_quote(input)
  // Build command with args
  let mut cmd = self.command
  for arg in self.args {
    let escaped_arg = escape_shell_single_quote(arg)
    cmd = cmd + " '" + escaped_arg + "'"
  }
  // Add environment variables prefix
  let mut env_prefix = ""
  for key, value in self.env {
    let escaped_value = escape_shell_single_quote(value)
    env_prefix = env_prefix + key + "='" + escaped_value + "' "
  }
  // Add working directory prefix
  let cwd_prefix = match self.cwd {
    Some(dir) => "cd '" + dir + "' && "
    None => ""
  }
  // Final command: echo 'input' | env command args
  cwd_prefix + env_prefix + "echo '" + escaped_input + "' | " + cmd
}

///|
/// Send JSON-RPC request and get response
pub fn NativeStdioClient::send_request(
  self : NativeStdioClient,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse raise StdioClientError {
  // Ensure request has ID
  let actual_request = match request.id {
    Some(_) => request
    None =>
      @interfaces.JsonRpcRequest::new(
        rpc_method=request.rpc_method,
        params=request.params,
        id=Some(self.next_request_id()),
      )
  }
  // Serialize request to JSON
  let request_json = actual_request.to_json().stringify()
  // Build pipe command
  let cmd = self.build_pipe_command(request_json)
  // Execute using popen with UTF-8 bytes
  let cmd_bytes = string_to_utf8_cstring(cmd)
  let mode_bytes = string_to_utf8_cstring("r")
  let handle = c_popen_handle(cmd_bytes, mode_bytes)
  if handle == 0L {
    raise StdioClientError::ProcessFailed("Failed to open process pipe")
  }
  // Read output
  let buffer = Bytes::new(65536)
  let bytes_read = c_fread_handle(buffer, 1, 65536, handle)
  let exit_code = c_pclose_handle(handle)
  if exit_code != 0 {
    raise StdioClientError::ProcessFailed(
      "Process exited with code \{exit_code}",
    )
  }
  if bytes_read <= 0 {
    raise StdioClientError::InvalidResponse("No output from process")
  }
  // Decode output as UTF-8
  let output_bytes = Bytes::from_iter(buffer[:bytes_read].iter())
  let output_text = @utf8.decode(output_bytes) catch {
    _ =>
      raise StdioClientError::InvalidResponse(
        "Invalid UTF-8 output from process",
      )
  }
  // Parse JSON-RPC response
  let trimmed = output_text.trim()
  // Handle NDJSON - take first non-empty line
  let lines : Array[String] = trimmed
    .split("\n")
    .map(fn(sv) { sv.to_string() })
    .collect()
  let response_line = find_first_json_line(lines)
  match response_line {
    Some(line) => {
      let json = @json.parse(line) catch {
        e =>
          raise StdioClientError::InvalidResponse(
            "Invalid JSON: \{e} - output: \{line}",
          )
      }
      match parse_stdio_jsonrpc_response(json) {
        Some(response) => response
        None =>
          raise StdioClientError::InvalidResponse(
            "Invalid JSON-RPC response: \{line}",
          )
      }
    }
    None =>
      raise StdioClientError::InvalidResponse(
        "No JSON response found in output: \{trimmed}",
      )
  }
}

///|
/// Find first line that looks like JSON
fn find_first_json_line(lines : Array[String]) -> String? {
  for line in lines {
    let trimmed = line.trim()
    if trimmed.has_prefix("{") {
      return Some(trimmed.to_string())
    }
  }
  None
}

///|
/// Parse JSON as JSON-RPC response
fn parse_stdio_jsonrpc_response(json : Json) -> @interfaces.JsonRpcResponse? {
  match json {
    { "jsonrpc": String(ver), .. } if ver == "2.0" => {
      let result = match json {
        { "result": r, .. } => Some(r)
        _ => None
      }
      let error : @interfaces.JsonRpcError? = match json {
        { "error": Object(e), .. } => {
          let code = match e.get("code") {
            Some(Number(n, ..)) => n.to_int()
            _ => -32603
          }
          let message = match e.get("message") {
            Some(String(m)) => m
            _ => "Unknown error"
          }
          let data = e.get("data")
          Some({ code, message, data })
        }
        _ => None
      }
      let id = match json {
        { "id": Number(i, ..), .. } => Some(i.to_int())
        _ => None
      }
      Some({ jsonrpc: ver, result, error, id })
    }
    _ => None
  }
}

///|
/// Stdio transport adapter that implements PluginTransportHandler
pub struct StdioTransportAdapter {
  /// Stdio client
  client : NativeStdioClient
  /// Plugin ID
  plugin_id : String
  /// Whether active
  mut active : Bool
  /// Message queue
  message_queue : @plugin_transport.MessageQueue
}

///|
/// Create a new Stdio transport adapter
pub fn StdioTransportAdapter::new(
  plugin_id~ : String,
  config~ : @interfaces.PluginStdioConfig,
) -> StdioTransportAdapter {
  let client = NativeStdioClient::from_config(config)
  {
    client,
    plugin_id,
    active: false,
    message_queue: @plugin_transport.MessageQueue::new(),
  }
}

///|
/// Start the transport
pub fn StdioTransportAdapter::start(
  self : StdioTransportAdapter,
) -> Unit raise @interfaces.TransportError {
  if self.active {
    raise @interfaces.TransportError::AlreadyStarted
  }
  // For stateless stdio, just mark as active
  self.active = true
}

///|
/// Stop the transport
pub fn StdioTransportAdapter::stop(self : StdioTransportAdapter) -> Unit {
  self.active = false
}

///|
/// Check if active
pub fn StdioTransportAdapter::is_active(self : StdioTransportAdapter) -> Bool {
  self.active
}

///|
/// Send JSON-RPC request
pub fn StdioTransportAdapter::send_request(
  self : StdioTransportAdapter,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse raise @interfaces.TransportError {
  if not(self.active) {
    raise @interfaces.TransportError::NotStarted
  }
  self.client.send_request(request) catch {
    StdioClientError::ProcessFailed(msg) =>
      raise @interfaces.TransportError::SendFailed("Process failed: \{msg}")
    StdioClientError::InvalidResponse(msg) =>
      raise @interfaces.TransportError::SendFailed("Invalid response: \{msg}")
    StdioClientError::Timeout =>
      raise @interfaces.TransportError::SendFailed("Timeout")
  }
}

///|
/// Implementation of PluginTransportHandler trait
pub impl @interfaces.PluginTransportHandler for StdioTransportAdapter with start(
  self,
) {
  StdioTransportAdapter::start(self)
}

///|
pub impl @interfaces.PluginTransportHandler for StdioTransportAdapter with stop(
  self,
) {
  StdioTransportAdapter::stop(self)
}

///|
pub impl @interfaces.PluginTransportHandler for StdioTransportAdapter with is_active(
  self,
) {
  StdioTransportAdapter::is_active(self)
}

///|
pub impl @interfaces.PluginTransportHandler for StdioTransportAdapter with send_request(
  self,
  request,
) {
  StdioTransportAdapter::send_request(self, request)
}

///|
pub impl @interfaces.PluginTransportHandler for StdioTransportAdapter with send_notification(
  self,
  request,
) {
  if not(self.active) {
    raise @interfaces.TransportError::NotStarted
  }
  // For stateless stdio, notifications are fire-and-forget
  try {
    ignore(self.client.send_request(request))
  } catch {
    _ => ()
  }
}

///|
pub impl @interfaces.PluginTransportHandler for StdioTransportAdapter with try_receive(
  self,
) {
  self.message_queue.pop()
}

///|
pub impl @interfaces.PluginTransportHandler for StdioTransportAdapter with on_message(
  self,
  callback,
) {
  self.message_queue.set_callback(callback)
}
