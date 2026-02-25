///|
/// Stdio Transport Handler
/// Implements PluginTransportHandler for stdio-based plugin communication
/// Uses stdin/stdout pipes to communicate with child processes

///|
/// Stdio transport handler for plugins
pub struct StdioTransportHandler {
  /// Plugin ID
  plugin_id : String
  /// Stdio configuration
  config : @interfaces.PluginStdioConfig
  /// Transport state
  mut state : @interfaces.TransportState
  /// Process ID (if running)
  mut pid : Int?
  /// Pending requests (id -> callback)
  pending_requests : Map[Int, @interfaces.PendingRequest]
  /// Request ID counter
  mut request_id : Int
  /// Message callback
  mut on_message_callback : ((@interfaces.JsonRpcRequest) -> Unit)?
  /// Incoming message queue
  incoming_queue : Array[@interfaces.JsonRpcRequest]
  /// Restart attempt counter
  mut restart_attempts : Int
  /// Last restart timestamp
  last_restart_time : Int64
}

///|
/// Create a new Stdio transport handler
pub fn StdioTransportHandler::new(
  plugin_id~ : String,
  config~ : @interfaces.PluginStdioConfig,
) -> StdioTransportHandler {
  {
    plugin_id,
    config,
    state: @interfaces.TransportState::Disconnected,
    pid: None,
    pending_requests: {},
    request_id: 0,
    on_message_callback: None,
    incoming_queue: [],
    restart_attempts: 0,
    last_restart_time: 0L,
  }
}

///|
/// Get next request ID
fn StdioTransportHandler::next_request_id(self : StdioTransportHandler) -> Int {
  self.request_id = self.request_id + 1
  self.request_id
}

///|
/// Format a JSON-RPC request for stdio output
/// Uses newline-delimited JSON (NDJSON) or length-prefixed framing
pub fn StdioTransportHandler::format_request(
  self : StdioTransportHandler,
  request : @interfaces.JsonRpcRequest,
) -> String {
  let json_str = request.to_json().stringify()
  match self.config.framing {
    @interfaces.StdioFraming::NewlineDelimited => json_str + "\n"
    @interfaces.StdioFraming::LengthPrefixed => {
      let len = json_str.length()
      "\{len}\n\{json_str}"
    }
  }
}

///|
/// Parse a line from stdio as JSON-RPC
pub fn parse_stdio_line(line : String) -> @interfaces.JsonRpcRequest? {
  let trimmed = line.trim()
  if trimmed.length() == 0 {
    return None
  }
  let json = @json.parse(trimmed) catch { _ => return None }
  @interfaces.JsonRpcRequest::from_json(json)
}

///|
/// Parse stdio line as JSON-RPC response
pub fn parse_stdio_response(line : String) -> @interfaces.JsonRpcResponse? {
  let trimmed = line.trim()
  if trimmed.length() == 0 {
    return None
  }
  let json = @json.parse(trimmed) catch { _ => return None }
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
/// Start the transport (launch child process)
/// Note: This is a synchronous placeholder - actual process spawning
/// requires async context and will be integrated in Phase 7
pub fn StdioTransportHandler::start(self : StdioTransportHandler) -> Unit raise {
  match self.state {
    @interfaces.TransportState::Connected
    | @interfaces.TransportState::Connecting =>
      raise @interfaces.TransportError::AlreadyStarted
    _ => {
      self.state = @interfaces.TransportState::Connecting
      // In Phase 7, this will spawn the actual process using @process.run
      // For now, mark as connected to allow testing
      self.state = @interfaces.TransportState::Connected
    }
  }
}

///|
/// Stop the transport (terminate child process)
pub fn StdioTransportHandler::stop(self : StdioTransportHandler) -> Unit raise {
  match self.pid {
    Some(_) =>
      // Process termination will be handled in Phase 7
      self.pid = None
    None => ()
  }
  self.state = @interfaces.TransportState::Stopped
  self.pending_requests.clear()
}

///|
/// Check if transport is active
pub fn StdioTransportHandler::is_active(self : StdioTransportHandler) -> Bool {
  match self.state {
    @interfaces.TransportState::Connected => true
    _ => false
  }
}

///|
/// Check if restart should be attempted based on policy
pub fn StdioTransportHandler::should_restart(
  self : StdioTransportHandler,
) -> Bool {
  match self.config.restart_policy {
    @interfaces.RestartPolicy::Never => false
    @interfaces.RestartPolicy::OnFailure(max_retries~, ..) =>
      self.restart_attempts < max_retries
    @interfaces.RestartPolicy::Always(..) => true
  }
}

///|
/// Get restart delay in milliseconds
pub fn StdioTransportHandler::get_restart_delay(
  self : StdioTransportHandler,
) -> Int {
  match self.config.restart_policy {
    @interfaces.RestartPolicy::Never => 0
    @interfaces.RestartPolicy::OnFailure(delay_ms~, ..) => delay_ms
    @interfaces.RestartPolicy::Always(base_delay_ms~, max_delay_ms~) => {
      // Exponential backoff
      let multiplier = 1 << self.restart_attempts
      let delay = base_delay_ms * multiplier
      if delay > max_delay_ms {
        max_delay_ms
      } else {
        delay
      }
    }
  }
}

///|
/// Reset restart counter
pub fn StdioTransportHandler::reset_restart_counter(
  self : StdioTransportHandler,
) -> Unit {
  self.restart_attempts = 0
}

///|
/// Increment restart counter
pub fn StdioTransportHandler::increment_restart_counter(
  self : StdioTransportHandler,
) -> Unit {
  self.restart_attempts = self.restart_attempts + 1
}

///|
/// Implementation of PluginTransportHandler trait
pub impl @interfaces.PluginTransportHandler for StdioTransportHandler with start(
  self,
) {
  StdioTransportHandler::start(self)
}

///|
pub impl @interfaces.PluginTransportHandler for StdioTransportHandler with stop(
  self,
) {
  StdioTransportHandler::stop(self)
}

///|
pub impl @interfaces.PluginTransportHandler for StdioTransportHandler with is_active(
  self,
) {
  StdioTransportHandler::is_active(self)
}

///|
/// Send a JSON-RPC request
/// Note: Actual stdin writing will be implemented in Phase 7
pub impl @interfaces.PluginTransportHandler for StdioTransportHandler with send_request(
  self,
  request,
) {
  guard self.is_active() else { raise @interfaces.TransportError::NotStarted }
  // Build request with ID if not present
  let actual_request = match request.id {
    Some(_) => request
    None =>
      @interfaces.JsonRpcRequest::new(
        rpc_method=request.rpc_method,
        params=request.params,
        id=Some(self.next_request_id()),
      )
  }
  // Format for stdio
  let _ = self.format_request(actual_request)
  // In Phase 7, write to stdin pipe
  // For now, return a placeholder response
  @interfaces.JsonRpcResponse::success(
    result=Json::object({ "pending": true, "transport": "stdio" }),
    id=actual_request.id,
  )
}

///|
/// Send a notification (no response expected)
pub impl @interfaces.PluginTransportHandler for StdioTransportHandler with send_notification(
  self,
  request,
) {
  guard self.is_active() else { raise @interfaces.TransportError::NotStarted }
  // Format for stdio (notifications have no id)
  let _ = self.format_request(request)
  // In Phase 7, write to stdin pipe
}

///|
/// Try to receive incoming message (non-blocking)
pub impl @interfaces.PluginTransportHandler for StdioTransportHandler with try_receive(
  self,
) {
  if self.incoming_queue.length() > 0 {
    Some(self.incoming_queue.remove(0))
  } else {
    None
  }
}

///|
/// Register message callback
pub impl @interfaces.PluginTransportHandler for StdioTransportHandler with on_message(
  self,
  callback,
) {
  self.on_message_callback = Some(callback)
}

///|
/// Queue an incoming message (called when reading from stdout)
pub fn StdioTransportHandler::queue_incoming(
  self : StdioTransportHandler,
  request : @interfaces.JsonRpcRequest,
) -> Unit {
  self.incoming_queue.push(request)
  match self.on_message_callback {
    Some(callback) => callback(request)
    None => ()
  }
}

///|
/// Process a line from stdout
/// Parses JSON-RPC and either queues as incoming request or matches to pending response
pub fn StdioTransportHandler::process_stdout_line(
  self : StdioTransportHandler,
  line : String,
) -> Unit {
  // First try to parse as response (has id but no method)
  match parse_stdio_response(line) {
    Some(response) =>
      match response.id {
        Some(id) =>
          // Remove from pending
          self.pending_requests.remove(id)
        // Response handling would be done via callback in async implementation
        None => ()
      }
    None =>
      // Try to parse as request (has method)
      match parse_stdio_line(line) {
        Some(request) => self.queue_incoming(request)
        None => ()
      }
  }
}

///|
/// Build command arguments with environment variable expansion
pub fn StdioTransportHandler::build_args(
  self : StdioTransportHandler,
) -> Array[String] {
  let args : Array[String] = []
  for arg in self.config.args {
    args.push(arg)
  }
  args
}

///|
/// Build environment variables map
pub fn StdioTransportHandler::build_env(
  self : StdioTransportHandler,
) -> Map[String, String] {
  let env : Map[String, String] = {}
  for key, value in self.config.env {
    env[key] = value
  }
  env
}

///|
/// Get working directory
pub fn StdioTransportHandler::get_cwd(self : StdioTransportHandler) -> String? {
  self.config.cwd
}
