///|
/// Unified transport handler trait for plugin communication
/// All transport implementations (HTTP, Stdio, WebSocket) implement this trait
///
/// Note: For WebSocket, the trait methods are synchronous but internally
/// may use async operations. In production, call from async fn main context.
/// For testing WebSocket, use async tests with the async client directly.
pub(open) trait PluginTransportHandler {
  /// Start the transport connection (async)
  async start(Self) -> Unit

  /// Stop the transport connection (async)
  async stop(Self) -> Unit

  /// Check if the transport is currently active
  is_active(Self) -> Bool

  /// Send a JSON-RPC request and wait for response (async)
  async send_request(Self, JsonRpcRequest) -> JsonRpcResponse

  /// Send a JSON-RPC notification (no response expected) (async)
  async send_notification(Self, JsonRpcRequest) -> Unit

  /// Try to receive an incoming request (non-blocking)
  try_receive(Self) -> JsonRpcRequest?

  /// Register a callback for incoming messages
  on_message(Self, (JsonRpcRequest) -> Unit) -> Unit
}

///|
/// Transport state
pub(all) enum TransportState {
  /// Not connected
  Disconnected
  /// Currently connecting
  Connecting
  /// Connected and active
  Connected
  /// Reconnecting after connection loss
  Reconnecting
  /// Stopped
  Stopped
  /// Error state
  Error(String)
}

///|
/// Transport error
pub(all) suberror TransportError {
  /// Connection failed
  ConnectionFailed(String)
  /// Connection lost
  ConnectionLost(String)
  /// Request timeout
  Timeout(String)
  /// Protocol error
  ProtocolError(String)
  /// Transport already started
  AlreadyStarted
  /// Transport not started
  NotStarted
  /// Send failed
  SendFailed(String)
}

///|
/// Transport configuration base
pub(all) struct TransportConfig {
  /// Connection timeout in milliseconds
  timeout_ms : Int
  /// Request timeout in milliseconds
  request_timeout_ms : Int
  /// Whether to auto-reconnect on connection loss
  auto_reconnect : Bool
  /// Maximum reconnect attempts
  max_reconnect_attempts : Int
  /// Base delay between reconnect attempts in milliseconds
  reconnect_base_delay_ms : Int
  /// Maximum delay between reconnect attempts in milliseconds
  reconnect_max_delay_ms : Int
}

///|
/// Default transport configuration
pub fn TransportConfig::default() -> TransportConfig {
  {
    timeout_ms: 30000,
    request_timeout_ms: 60000,
    auto_reconnect: true,
    max_reconnect_attempts: 5,
    reconnect_base_delay_ms: 1000,
    reconnect_max_delay_ms: 30000,
  }
}

///|
/// Stdio transport configuration
pub(all) struct PluginStdioConfig {
  /// Command to execute
  command : String
  /// Command arguments
  args : Array[String]
  /// Working directory
  cwd : String?
  /// Environment variables
  env : Map[String, String]
  /// Framing method
  framing : StdioFraming
  /// Startup timeout in milliseconds
  startup_timeout_ms : Int
  /// Restart policy
  restart_policy : RestartPolicy
}

///|
/// Stdio framing method
pub(all) enum StdioFraming {
  /// Newline-delimited JSON (NDJSON)
  NewlineDelimited
  /// Length-prefixed messages
  LengthPrefixed
}

///|
/// Process restart policy
pub(all) enum RestartPolicy {
  /// Never restart
  Never
  /// Restart on failure with max retries and delay
  OnFailure(max_retries~ : Int, delay_ms~ : Int)
  /// Always restart with exponential backoff
  Always(base_delay_ms~ : Int, max_delay_ms~ : Int)
}

///|
/// Default Stdio config
pub fn PluginStdioConfig::default(command~ : String) -> PluginStdioConfig {
  {
    command,
    args: [],
    cwd: None,
    env: {},
    framing: StdioFraming::NewlineDelimited,
    startup_timeout_ms: 30000,
    restart_policy: RestartPolicy::OnFailure(max_retries=3, delay_ms=1000),
  }
}

///|
/// WebSocket transport configuration
pub(all) struct PluginWebSocketConfig {
  /// WebSocket URL (ws:// or wss://)
  url : String
  /// Additional headers for connection
  headers : Map[String, String]
  /// Reconnect configuration
  reconnect : ReconnectConfig
  /// Heartbeat interval in milliseconds (0 to disable)
  heartbeat_interval_ms : Int
}

///|
/// Reconnection configuration
pub(all) struct ReconnectConfig {
  /// Whether reconnection is enabled
  enabled : Bool
  /// Maximum reconnection attempts
  max_attempts : Int
  /// Base delay between attempts in milliseconds
  base_delay_ms : Int
  /// Maximum delay between attempts in milliseconds
  max_delay_ms : Int
}

///|
/// Default reconnect config
pub fn ReconnectConfig::default() -> ReconnectConfig {
  { enabled: true, max_attempts: 10, base_delay_ms: 1000, max_delay_ms: 30000 }
}

///|
/// Default WebSocket config
pub fn PluginWebSocketConfig::default(url~ : String) -> PluginWebSocketConfig {
  {
    url,
    headers: {},
    reconnect: ReconnectConfig::default(),
    heartbeat_interval_ms: 30000,
  }
}

///|
/// Pending request tracker for async responses
pub(all) struct PendingRequest {
  /// Request ID
  id : Int
  /// Timestamp when request was sent
  sent_at : Int64
  /// Timeout in milliseconds
  timeout_ms : Int
}

///|
/// Check if request has timed out
pub fn PendingRequest::is_timed_out(
  self : PendingRequest,
  current_time : Int64,
) -> Bool {
  current_time - self.sent_at > self.timeout_ms.to_int64()
}
