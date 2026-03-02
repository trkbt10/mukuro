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
/// Validate environment variable key - only allow alphanumeric and underscore
pub fn validate_env_key(key : String) -> Unit raise StdioClientError {
  if key.length() == 0 {
    raise StdioClientError::ProcessFailed("Empty environment variable key")
  }
  let chars = key.to_array()
  // First character must be letter or underscore
  let first = chars[0]
  if not(
      (first >= 'a' && first <= 'z') ||
      (first >= 'A' && first <= 'Z') ||
      first == '_',
    ) {
    raise StdioClientError::ProcessFailed(
      "Invalid environment variable key: \{key}",
    )
  }
  for c in chars {
    if not(
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '_',
      ) {
      raise StdioClientError::ProcessFailed(
        "Invalid character '\{c}' in environment variable key: \{key}",
      )
    }
  }
}

///|
/// Escape single quotes for shell
pub fn escape_shell_single_quote(s : String) -> String {
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
) -> String raise StdioClientError {
  // Validate command name
  @native.validate_command_name(self.command) catch {
    @native.ProcessError::ExecutionFailed(msg) =>
      raise StdioClientError::ProcessFailed(msg)
    _ => raise StdioClientError::ProcessFailed("Invalid command")
  }
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
    validate_env_key(key) catch {
      e => raise e
    }
    let escaped_value = escape_shell_single_quote(value)
    env_prefix = env_prefix + key + "='" + escaped_value + "' "
  }
  // Add working directory prefix
  let cwd_prefix = match self.cwd {
    Some(dir) => {
      let escaped_dir = escape_shell_single_quote(dir)
      "cd '" + escaped_dir + "' && "
    }
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
  let cmd = self.build_pipe_command(request_json) catch { e => raise e }
  // Execute using popen with UTF-8 bytes
  let cmd_bytes = @native.string_to_utf8_cstring(cmd)
  let mode_bytes = @native.string_to_utf8_cstring("r")
  let handle = @native.c_popen_handle(cmd_bytes, mode_bytes)
  if handle == 0L {
    raise StdioClientError::ProcessFailed("Failed to open process pipe")
  }
  // Read output
  let buffer = Bytes::new(65536)
  let bytes_read = @native.c_fread_handle(buffer, 1, 65536, handle)
  let exit_code = @native.c_pclose_handle(handle)
  if exit_code != 0 {
    raise StdioClientError::ProcessFailed(
      "Process exited with code \{exit_code}",
    )
  }
  if bytes_read <= 0 {
    raise StdioClientError::InvalidResponse("No output from process")
  }
  let output_text = match @bytes.decode_utf8(buffer[:bytes_read]) {
    Some(s) => s
    None =>
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
      match parse_jsonrpc_response(json) {
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
  ignore(self.client.send_request(request)) catch {
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
