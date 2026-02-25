///|
/// Storage Plugin - Key-Value Store
/// Provides in-memory storage with optional TTL support

///|
/// Storage entry with optional expiration
pub(all) struct StorageEntry {
  /// Stored value
  value : Json
  /// Expiration timestamp (milliseconds since epoch), None for no expiration
  expires_at : Int64?
  /// Creation timestamp
  created_at : Int64
  /// Last updated timestamp
  updated_at : Int64
}

///|
/// Storage plugin configuration
pub(all) struct StoragePluginConfig {
  /// Plugin name
  name : String
  /// Default TTL in milliseconds (0 = no expiration)
  default_ttl_ms : Int64
  /// Maximum number of entries (0 = unlimited)
  max_entries : Int
  /// Key prefix
  key_prefix : String
}

///|
/// Default storage config
pub fn StoragePluginConfig::default(name~ : String) -> StoragePluginConfig {
  { name, default_ttl_ms: 0L, max_entries: 0, key_prefix: "" }
}

///|
/// In-memory storage plugin
pub struct MemoryStoragePlugin {
  config : StoragePluginConfig
  /// Key-value store
  data : Map[String, StorageEntry]
  /// Current timestamp provider (for testing)
  mut get_timestamp : () -> Int64
}

///|
/// Create new memory storage plugin
pub fn MemoryStoragePlugin::new(
  config : StoragePluginConfig,
) -> MemoryStoragePlugin {
  { config, data: {}, get_timestamp: fn() { 0L } }
}

///|
/// Set timestamp provider (for testing)
pub fn MemoryStoragePlugin::set_timestamp_provider(
  self : MemoryStoragePlugin,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Get namespaced key
fn MemoryStoragePlugin::prefixed_key(
  self : MemoryStoragePlugin,
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
fn is_expired(entry : StorageEntry, now : Int64) -> Bool {
  match entry.expires_at {
    Some(expires) => now >= expires
    None => false
  }
}

///|
/// Set a value with optional TTL
pub fn MemoryStoragePlugin::set(
  self : MemoryStoragePlugin,
  key : String,
  value : Json,
  ttl_ms~ : Int64? = None,
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
  // Check max entries limit
  if self.config.max_entries > 0 && self.data.length() >= self.config.max_entries {
    // Remove oldest entry (simple eviction)
    self.evict_oldest()
  }
  let entry : StorageEntry = { value, expires_at, created_at: now, updated_at: now }
  self.data[ns_key] = entry
}

///|
/// Get a value
pub fn MemoryStoragePlugin::get(
  self : MemoryStoragePlugin,
  key : String,
) -> Json? {
  let ns_key = self.prefixed_key(key)
  match self.data.get(ns_key) {
    Some(entry) => {
      let now = (self.get_timestamp)()
      if is_expired(entry, now) {
        self.data.remove(ns_key)
        None
      } else {
        Some(entry.value)
      }
    }
    None => None
  }
}

///|
/// Delete a value
pub fn MemoryStoragePlugin::delete(
  self : MemoryStoragePlugin,
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
pub fn MemoryStoragePlugin::exists(
  self : MemoryStoragePlugin,
  key : String,
) -> Bool {
  let ns_key = self.prefixed_key(key)
  match self.data.get(ns_key) {
    Some(entry) => {
      let now = (self.get_timestamp)()
      if is_expired(entry, now) {
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
pub fn MemoryStoragePlugin::keys(self : MemoryStoragePlugin) -> Array[String] {
  let now = (self.get_timestamp)()
  let result : Array[String] = []
  let expired_keys : Array[String] = []
  for key, entry in self.data {
    if is_expired(entry, now) {
      expired_keys.push(key)
    } else {
      // Remove key prefix if present
      let display_key = if self.config.key_prefix.length() > 0 {
        let prefix = "\{self.config.key_prefix}:"
        if key.has_prefix(prefix) {
          key.substring(start=prefix.length())
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
pub fn MemoryStoragePlugin::clear(self : MemoryStoragePlugin) -> Unit {
  self.data.clear()
}

///|
/// Get entry count
pub fn MemoryStoragePlugin::count(self : MemoryStoragePlugin) -> Int {
  self.data.length()
}

///|
/// Evict oldest entry
fn MemoryStoragePlugin::evict_oldest(self : MemoryStoragePlugin) -> Unit {
  let mut oldest_key : String? = None
  let mut oldest_time = 9223372036854775807L // Int64 max
  for key, entry in self.data {
    if entry.created_at < oldest_time {
      oldest_time = entry.created_at
      oldest_key = Some(key)
    }
  }
  match oldest_key {
    Some(key) => self.data.remove(key)
    None => ()
  }
}

///|
/// Handle JSON-RPC request
pub fn MemoryStoragePlugin::handle_request(
  self : MemoryStoragePlugin,
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
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn MemoryStoragePlugin::handle_get(
  self : MemoryStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let key = match request.params {
    Some({ "key": String(k), .. }) => k
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'key' parameter",
        id=request.id,
      )
  }
  match self.get(key) {
    Some(value) =>
      @interfaces.JsonRpcResponse::success(result={ "value": value }, id=request.id)
    None =>
      @interfaces.JsonRpcResponse::success(
        result={ "value": Json::null() },
        id=request.id,
      )
  }
}

///|
fn MemoryStoragePlugin::handle_set(
  self : MemoryStoragePlugin,
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
fn MemoryStoragePlugin::handle_delete(
  self : MemoryStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let key = match request.params {
    Some({ "key": String(k), .. }) => k
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'key' parameter",
        id=request.id,
      )
  }
  let deleted = self.delete(key)
  @interfaces.JsonRpcResponse::success(result={ "deleted": deleted }, id=request.id)
}

///|
fn MemoryStoragePlugin::handle_exists(
  self : MemoryStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let key = match request.params {
    Some({ "key": String(k), .. }) => k
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing 'key' parameter",
        id=request.id,
      )
  }
  let exists = self.exists(key)
  @interfaces.JsonRpcResponse::success(result={ "exists": exists }, id=request.id)
}

///|
fn MemoryStoragePlugin::handle_keys(
  self : MemoryStoragePlugin,
  _request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let keys = self.keys()
  let keys_json : Array[Json] = []
  for k in keys {
    keys_json.push(Json::string(k))
  }
  @interfaces.JsonRpcResponse::success(
    result={ "keys": Json::array(keys_json) },
    id=_request.id,
  )
}

///|
fn MemoryStoragePlugin::handle_clear(
  self : MemoryStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.clear()
  @interfaces.JsonRpcResponse::success(result={ "ok": true }, id=request.id)
}

///|
fn MemoryStoragePlugin::handle_count(
  self : MemoryStoragePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let count = self.count()
  @interfaces.JsonRpcResponse::success(
    result={ "count": Json::number(count.to_double()) },
    id=request.id,
  )
}
