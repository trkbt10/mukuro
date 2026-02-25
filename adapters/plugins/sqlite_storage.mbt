///|
/// SQLite Storage Plugin - Persistent Key-Value Store
/// Provides SQLite-backed storage with TTL support

///|
/// SQLite storage plugin configuration
pub(all) struct SqliteStorageConfig {
  /// Plugin name
  name : String
  /// Database file path
  db_path : String
  /// Default TTL in milliseconds (0 = no expiration)
  default_ttl_ms : Int64
  /// Key prefix for namespacing
  key_prefix : String
}

///|
/// Default SQLite storage config
pub fn SqliteStorageConfig::default(
  name~ : String,
  db_path~ : String,
) -> SqliteStorageConfig {
  { name, db_path, default_ttl_ms: 0L, key_prefix: "" }
}

///|
/// SQLite storage plugin (mock implementation for cross-platform)
/// Actual SQLite operations require native target
pub struct SqliteStoragePlugin {
  config : SqliteStorageConfig
  /// In-memory fallback for non-native platforms
  data : Map[String, SqliteStorageEntry]
  /// Connection state
  mut is_connected : Bool
  /// Current timestamp provider
  mut get_timestamp : () -> Int64
}

///|
/// Storage entry structure
pub(all) struct SqliteStorageEntry {
  /// Stored value as JSON string
  value : String
  /// Expiration timestamp (milliseconds), None for no expiration
  expires_at : Int64?
  /// Creation timestamp
  created_at : Int64
  /// Last updated timestamp
  updated_at : Int64
}

///|
/// Create new SQLite storage plugin
pub fn SqliteStoragePlugin::new(
  config : SqliteStorageConfig,
) -> SqliteStoragePlugin {
  { config, data: {}, is_connected: false, get_timestamp: fn() { 0L } }
}

///|
/// Set timestamp provider (for testing)
pub fn SqliteStoragePlugin::set_timestamp_provider(
  self : SqliteStoragePlugin,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Get namespaced key
fn SqliteStoragePlugin::prefixed_key(
  self : SqliteStoragePlugin,
  key : String,
) -> String {
  if self.config.key_prefix.length() > 0 {
    "\{self.config.key_prefix}:\{key}"
  } else {
    key
  }
}

///|
/// Check if entry is expired
fn sqlite_storage_is_expired(entry : SqliteStorageEntry, now : Int64) -> Bool {
  match entry.expires_at {
    Some(expires) => now >= expires
    None => false
  }
}

///|
/// Connect to database (creates schema if needed)
pub fn SqliteStoragePlugin::connect(self : SqliteStoragePlugin) -> Unit {
  // In-memory implementation - just set connected flag
  // Native SQLite implementation would:
  // 1. Open database connection
  // 2. Create table if not exists:
  //    CREATE TABLE IF NOT EXISTS kv_store (
  //      key TEXT PRIMARY KEY,
  //      value TEXT NOT NULL,
  //      expires_at INTEGER,
  //      created_at INTEGER NOT NULL,
  //      updated_at INTEGER NOT NULL
  //    );
  //    CREATE INDEX IF NOT EXISTS idx_expires ON kv_store(expires_at);
  self.is_connected = true
}

///|
/// Disconnect from database
pub fn SqliteStoragePlugin::disconnect(self : SqliteStoragePlugin) -> Unit {
  self.is_connected = false
}

///|
/// Check if connected
pub fn SqliteStoragePlugin::is_connected(self : SqliteStoragePlugin) -> Bool {
  self.is_connected
}

///|
/// Set a value with optional TTL
pub fn SqliteStoragePlugin::set(
  self : SqliteStoragePlugin,
  key : String,
  value : Json,
  ttl_ms? : Int64? = None,
) -> Unit {
  let ns_key = self.prefixed_key(key)
  let now = (self.get_timestamp)()
  // Determine expiration
  let expires_at = match ttl_ms {
    Some(ttl) => if ttl > 0L { Some(now + ttl) } else { None }
    None =>
      if self.config.default_ttl_ms > 0L {
        Some(now + self.config.default_ttl_ms)
      } else {
        None
      }
  }
  // Serialize JSON to string
  let value_str = value.stringify()
  let entry : SqliteStorageEntry = {
    value: value_str,
    expires_at,
    created_at: now,
    updated_at: now,
  }
  self.data[ns_key] = entry
}

///|
/// Get a value
pub fn SqliteStoragePlugin::get(
  self : SqliteStoragePlugin,
  key : String,
) -> Json? {
  let ns_key = self.prefixed_key(key)
  match self.data.get(ns_key) {
    Some(entry) => {
      let now = (self.get_timestamp)()
      if sqlite_storage_is_expired(entry, now) {
        self.data.remove(ns_key)
        None
      } else {
        Some(
          // Parse JSON from string
          @json.parse(entry.value),
        ) catch {
          _ => None
        }
      }
    }
    None => None
  }
}

///|
/// Delete a value
pub fn SqliteStoragePlugin::delete(
  self : SqliteStoragePlugin,
  key : String,
) -> Bool {
  let ns_key = self.prefixed_key(key)
  match self.data.get(ns_key) {
    Some(_) => {
      self.data.remove(ns_key)
      true
    }
    None => false
  }
}

///|
/// Check if key exists (and not expired)
pub fn SqliteStoragePlugin::exists(
  self : SqliteStoragePlugin,
  key : String,
) -> Bool {
  let ns_key = self.prefixed_key(key)
  match self.data.get(ns_key) {
    Some(entry) => {
      let now = (self.get_timestamp)()
      if sqlite_storage_is_expired(entry, now) {
        self.data.remove(ns_key)
        false
      } else {
        true
      }
    }
    None => false
  }
}

///|
/// Get all keys (excluding expired)
pub fn SqliteStoragePlugin::keys(self : SqliteStoragePlugin) -> Array[String] {
  let now = (self.get_timestamp)()
  let result : Array[String] = []
  let expired_keys : Array[String] = []
  for key, entry in self.data {
    if sqlite_storage_is_expired(entry, now) {
      expired_keys.push(key)
    } else {
      // Remove key prefix if present
      let display_key = if self.config.key_prefix.length() > 0 {
        let prefix = "\{self.config.key_prefix}:"
        if key.has_prefix(prefix) {
          key[prefix.length():].to_string() catch {
            _ => abort("unreachable: prefix length already validated")
          }
        } else {
          key
        }
      } else {
        key
      }
      result.push(display_key)
    }
  }
  // Clean up expired keys
  for key in expired_keys {
    self.data.remove(key)
  }
  result
}

///|
/// Clear all entries
pub fn SqliteStoragePlugin::clear(self : SqliteStoragePlugin) -> Unit {
  self.data.clear()
}

///|
/// Get entry count
pub fn SqliteStoragePlugin::count(self : SqliteStoragePlugin) -> Int {
  self.data.length()
}

///|
/// Handle JSON-RPC request
pub fn SqliteStoragePlugin::handle_request(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "get" => self.handle_get(request)
    "set" => self.handle_set(request)
    "delete" => self.handle_delete(request)
    "exists" => self.handle_exists(request)
    "keys" => self.handle_keys(request)
    "clear" => self.handle_clear(request)
    "count" => self.handle_count(request)
    "connect" => self.handle_connect(request)
    "disconnect" => self.handle_disconnect(request)
    "status" => self.handle_status(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn SqliteStoragePlugin::handle_get(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let key = match @interfaces.rpc_require_string(request, "key") {
    Ok(k) => k
    Err(response) => return response
  }
  match self.get(key) {
    Some(value) =>
      @interfaces.JsonRpcResponse::success(
        result={ "value": value },
        id=request.id,
      )
    None => @interfaces.rpc_null_result("value", request.id)
  }
}

///|
fn SqliteStoragePlugin::handle_set(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (key, value, ttl) = match request.params {
    Some({ "key": String(k), "value": v, .. } as params) => {
      let ttl : Int64? = match params {
        { "ttl_ms": Number(t, ..), .. } => Some(t.to_int64())
        _ => None
      }
      (k, v, ttl)
    }
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'key' or 'value' parameter",
        id=request.id,
      )
  }
  self.set(key, value, ttl_ms=ttl)
  @interfaces.JsonRpcResponse::success(result={ "ok": true }, id=request.id)
}

///|
fn SqliteStoragePlugin::handle_delete(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let key = match @interfaces.rpc_require_string(request, "key") {
    Ok(k) => k
    Err(response) => return response
  }
  let deleted = self.delete(key)
  @interfaces.rpc_success_bool("deleted", deleted, request.id)
}

///|
fn SqliteStoragePlugin::handle_exists(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let key = match @interfaces.rpc_require_string(request, "key") {
    Ok(k) => k
    Err(response) => return response
  }
  let exists = self.exists(key)
  @interfaces.rpc_success_bool("exists", exists, request.id)
}

///|
fn SqliteStoragePlugin::handle_keys(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let keys = self.keys()
  @interfaces.rpc_success_array(
    "keys",
    keys,
    fn(k) { Json::string(k) },
    request.id,
  )
}

///|
fn SqliteStoragePlugin::handle_clear(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.clear()
  @interfaces.rpc_ok(request.id)
}

///|
fn SqliteStoragePlugin::handle_count(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let count = self.count()
  @interfaces.rpc_success_int("count", count, request.id)
}

///|
fn SqliteStoragePlugin::handle_connect(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.connect()
  @interfaces.rpc_connect_response(request.id)
}

///|
fn SqliteStoragePlugin::handle_disconnect(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.disconnect()
  @interfaces.rpc_disconnect_response(request.id)
}

///|
fn SqliteStoragePlugin::handle_status(
  self : SqliteStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let extra : Map[String, Json] = {
    "db_path": Json::string(self.config.db_path),
    "count": Json::number(self.data.length().to_double()),
  }
  @interfaces.rpc_status_response(self.is_connected, extra, request.id)
}
