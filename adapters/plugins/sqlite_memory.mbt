///|
/// SQLite Memory Plugin - Persistent Memory with Vector Search
/// Provides SQLite-backed memory storage with embedding support

///|
/// SQLite memory plugin configuration
pub(all) struct SqliteMemoryConfig {
  /// Plugin name
  name : String
  /// Database file path
  db_path : String
  /// Embedding dimension (default 768 for common models)
  embedding_dimension : Int
  /// Maximum memories to return in search
  max_search_results : Int
  /// Default importance value
  default_importance : Double
}

///|
/// Default SQLite memory config
pub fn SqliteMemoryConfig::default(
  name~ : String,
  db_path~ : String,
) -> SqliteMemoryConfig {
  {
    name,
    db_path,
    embedding_dimension: 768,
    max_search_results: 10,
    default_importance: 0.5,
  }
}

///|
/// Memory entry structure
pub(all) struct SqliteMemoryEntry {
  /// Unique identifier
  id : String
  /// Memory content
  content : String
  /// Embedding vector (optional, for similarity search)
  embedding : Array[Double]?
  /// Metadata as JSON string
  metadata : String?
  /// Creation timestamp
  timestamp : Int64
  /// Source identifier
  source : String?
  /// Importance score (0.0 - 1.0)
  importance : Double
}

///|
/// Search result with score
pub(all) struct MemorySearchResult {
  /// Memory entry
  entry : SqliteMemoryEntry
  /// Similarity score (higher = more similar)
  score : Double
}

///|
/// SQLite memory plugin (mock implementation for cross-platform)
pub struct SqliteMemoryPlugin {
  config : SqliteMemoryConfig
  /// In-memory fallback for non-native platforms
  memories : Map[String, SqliteMemoryEntry]
  /// Connection state
  mut is_connected : Bool
  /// Current timestamp provider
  mut get_timestamp : () -> Int64
  /// ID generator
  id_gen : @util.IdGenerator
}

///|
/// Create new SQLite memory plugin
pub fn SqliteMemoryPlugin::new(
  config : SqliteMemoryConfig,
) -> SqliteMemoryPlugin {
  {
    config,
    memories: {},
    is_connected: false,
    get_timestamp: fn() { 0L },
    id_gen: @util.IdGenerator::new("mem_"),
  }
}

///|
/// Set timestamp provider (for testing)
pub fn SqliteMemoryPlugin::set_timestamp_provider(
  self : SqliteMemoryPlugin,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Connect to database (creates schema if needed)
pub fn SqliteMemoryPlugin::connect(self : SqliteMemoryPlugin) -> Unit {
  // In-memory implementation - just set connected flag
  // Native SQLite implementation would:
  // CREATE TABLE IF NOT EXISTS memories (
  //   id TEXT PRIMARY KEY,
  //   content TEXT NOT NULL,
  //   embedding BLOB,
  //   metadata TEXT,
  //   timestamp INTEGER NOT NULL,
  //   source TEXT,
  //   importance REAL
  // );
  // CREATE INDEX IF NOT EXISTS idx_timestamp ON memories(timestamp);
  // CREATE INDEX IF NOT EXISTS idx_importance ON memories(importance);
  self.is_connected = true
}

///|
/// Disconnect from database
pub fn SqliteMemoryPlugin::disconnect(self : SqliteMemoryPlugin) -> Unit {
  self.is_connected = false
}

///|
/// Check if connected
pub fn SqliteMemoryPlugin::is_connected(self : SqliteMemoryPlugin) -> Bool {
  self.is_connected
}

///|
/// Store a memory
pub fn SqliteMemoryPlugin::remember(
  self : SqliteMemoryPlugin,
  content : String,
  embedding? : Array[Double]? = None,
  metadata? : String? = None,
  source? : String? = None,
  importance? : Double? = None,
) -> String {
  let id = self.id_gen.next()
  let now = (self.get_timestamp)()
  let entry : SqliteMemoryEntry = {
    id,
    content,
    embedding,
    metadata,
    timestamp: now,
    source,
    importance: match importance {
      Some(imp) => imp
      None => self.config.default_importance
    },
  }
  self.memories[id] = entry
  id
}

///|
/// Get a memory by ID
pub fn SqliteMemoryPlugin::get(
  self : SqliteMemoryPlugin,
  id : String,
) -> SqliteMemoryEntry? {
  self.memories.get(id)
}

///|
/// Forget (delete) a memory
pub fn SqliteMemoryPlugin::forget(
  self : SqliteMemoryPlugin,
  id : String,
) -> Bool {
  match self.memories.get(id) {
    Some(_) => {
      self.memories.remove(id)
      true
    }
    None => false
  }
}

///|
/// Update importance score
pub fn SqliteMemoryPlugin::update_importance(
  self : SqliteMemoryPlugin,
  id : String,
  importance : Double,
) -> Bool {
  match self.memories.get(id) {
    Some(entry) => {
      let updated_entry : SqliteMemoryEntry = {
        id: entry.id,
        content: entry.content,
        embedding: entry.embedding,
        metadata: entry.metadata,
        timestamp: entry.timestamp,
        source: entry.source,
        importance,
      }
      self.memories[id] = updated_entry
      true
    }
    None => false
  }
}

///|
/// Simple square root approximation (Newton's method)
fn sqlite_sqrt(x : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  let mut guess = x / 2.0
  for _i = 0; _i < 20; _i = _i + 1 {
    guess = (guess + x / guess) / 2.0
  }
  guess
}

///|
/// Calculate cosine similarity between two vectors
fn sqlite_cosine_similarity(a : Array[Double], b : Array[Double]) -> Double {
  if a.length() != b.length() || a.length() == 0 {
    return 0.0
  }
  let mut dot_product = 0.0
  let mut norm_a = 0.0
  let mut norm_b = 0.0
  for i = 0; i < a.length(); i = i + 1 {
    dot_product += a[i] * b[i]
    norm_a += a[i] * a[i]
    norm_b += b[i] * b[i]
  }
  if norm_a == 0.0 || norm_b == 0.0 {
    return 0.0
  }
  dot_product / (sqlite_sqrt(norm_a) * sqlite_sqrt(norm_b))
}

///|
/// Search memories by embedding similarity
pub fn SqliteMemoryPlugin::search(
  self : SqliteMemoryPlugin,
  query_embedding : Array[Double],
  limit? : Int? = None,
  min_score? : Double = 0.0,
) -> Array[MemorySearchResult] {
  let results : Array[MemorySearchResult] = []
  let max_results = match limit {
    Some(l) => l
    None => self.config.max_search_results
  }
  for _, entry in self.memories {
    match entry.embedding {
      Some(emb) => {
        let score = sqlite_cosine_similarity(query_embedding, emb)
        if score >= min_score {
          results.push({ entry, score })
        }
      }
      None => ()
    }
  }
  // Sort by score descending (bubble sort for simplicity)
  for i = 0; i < results.length(); i = i + 1 {
    for j = i + 1; j < results.length(); j = j + 1 {
      if results[j].score > results[i].score {
        let temp = results[i]
        results[i] = results[j]
        results[j] = temp
      }
    }
  }
  // Limit results
  if results.length() > max_results {
    let _ = results.drain(max_results, results.length())
  }
  results
}

///|
/// Search memories by text (simple contains match)
pub fn SqliteMemoryPlugin::search_text(
  self : SqliteMemoryPlugin,
  query : String,
  limit? : Int? = None,
) -> Array[SqliteMemoryEntry] {
  let results : Array[SqliteMemoryEntry] = []
  let max_results = match limit {
    Some(l) => l
    None => self.config.max_search_results
  }
  let query_lower = query.to_lower()
  for _, entry in self.memories {
    if entry.content.to_lower().contains(query_lower) {
      results.push(entry)
      if results.length() >= max_results {
        break
      }
    }
  }
  results
}

///|
/// Get recent memories
pub fn SqliteMemoryPlugin::get_recent(
  self : SqliteMemoryPlugin,
  limit? : Int? = None,
) -> Array[SqliteMemoryEntry] {
  let results : Array[SqliteMemoryEntry] = []
  let max_results = match limit {
    Some(l) => l
    None => self.config.max_search_results
  }
  // Collect all entries
  for _, entry in self.memories {
    results.push(entry)
  }
  // Sort by timestamp descending (bubble sort)
  for i = 0; i < results.length(); i = i + 1 {
    for j = i + 1; j < results.length(); j = j + 1 {
      if results[j].timestamp > results[i].timestamp {
        let temp = results[i]
        results[i] = results[j]
        results[j] = temp
      }
    }
  }
  // Limit results
  if results.length() > max_results {
    let _ = results.drain(max_results, results.length())
  }
  results
}

///|
/// Compact memories (remove low importance entries to save space)
pub fn SqliteMemoryPlugin::compact(
  self : SqliteMemoryPlugin,
  keep_count : Int,
) -> Int {
  // Collect all entries with their IDs
  let entries : Array[(String, SqliteMemoryEntry)] = []
  for id, entry in self.memories {
    entries.push((id, entry))
  }
  // Sort by importance descending (bubble sort)
  for i = 0; i < entries.length(); i = i + 1 {
    for j = i + 1; j < entries.length(); j = j + 1 {
      if entries[j].1.importance > entries[i].1.importance {
        let temp = entries[i]
        entries[i] = entries[j]
        entries[j] = temp
      }
    }
  }
  // Remove entries beyond keep_count
  let mut removed = 0
  for i = keep_count; i < entries.length(); i = i + 1 {
    let (id, _) = entries[i]
    self.memories.remove(id)
    removed += 1
  }
  removed
}

///|
/// Get total memory count
pub fn SqliteMemoryPlugin::count(self : SqliteMemoryPlugin) -> Int {
  self.memories.length()
}

///|
/// Clear all memories
pub fn SqliteMemoryPlugin::clear(self : SqliteMemoryPlugin) -> Unit {
  self.memories.clear()
  self.id_gen.reset(1L)
}

///|
/// Convert SqliteMemoryEntry to JSON
fn memory_entry_to_json(entry : SqliteMemoryEntry) -> Json {
  let result : Map[String, Json] = {
    "id": Json::string(entry.id),
    "content": Json::string(entry.content),
    "timestamp": Json::number(entry.timestamp.to_double()),
    "importance": Json::number(entry.importance),
  }
  match entry.metadata {
    Some(m) => result["metadata"] = Json::string(m)
    None => ()
  }
  match entry.source {
    Some(s) => result["source"] = Json::string(s)
    None => ()
  }
  match entry.embedding {
    Some(emb) => {
      let arr : Array[Json] = []
      for v in emb {
        arr.push(Json::number(v))
      }
      result["embedding"] = Json::array(arr)
    }
    None => ()
  }
  Json::object(result)
}

///|
/// Convert MemorySearchResult to JSON
fn memory_search_result_to_json(result : MemorySearchResult) -> Json {
  let obj : Map[String, Json] = {}
  match memory_entry_to_json(result.entry) {
    Object(entry_obj) =>
      for k, v in entry_obj {
        obj[k] = v
      }
    _ => ()
  }
  obj["score"] = Json::number(result.score)
  Json::object(obj)
}

///|
/// Handle JSON-RPC request
pub fn SqliteMemoryPlugin::handle_request(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "remember" => self.handle_remember(request)
    "search" => self.handle_search(request)
    "search_text" => self.handle_search_text(request)
    "get" => self.handle_get(request)
    "forget" => self.handle_forget(request)
    "update_importance" => self.handle_update_importance(request)
    "get_recent" => self.handle_get_recent(request)
    "compact" => self.handle_compact(request)
    "count" => self.handle_count(request)
    "clear" => self.handle_clear(request)
    "connect" => self.handle_connect(request)
    "disconnect" => self.handle_disconnect(request)
    "status" => self.handle_status(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn SqliteMemoryPlugin::handle_remember(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let content = match @interfaces.rpc_require_string(request, "content") {
    Ok(c) => c
    Err(response) => return response
  }
  let metadata = @interfaces.rpc_string_or_none(request, "metadata")
  let source = @interfaces.rpc_string_or_none(request, "source")
  let importance = @interfaces.rpc_double_or_none(request, "importance")
  let embedding = @interfaces.rpc_double_array(request, "embedding")
  let emb : Array[Double]? = if embedding.length() > 0 {
    Some(embedding)
  } else {
    None
  }
  let id = self.remember(
    content,
    embedding=emb,
    metadata~,
    source~,
    importance~,
  )
  let result : Map[String, Json] = {}
  result["id"] = Json::string(id)
  @interfaces.JsonRpcResponse::success(
    result=Json::object(result),
    id=request.id,
  )
}

///|
fn SqliteMemoryPlugin::handle_search(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let embedding = @interfaces.rpc_double_array(request, "embedding")
  if embedding.length() == 0 {
    return @interfaces.rpc_invalid_params(
      "Missing 'embedding' parameter",
      request.id,
    )
  }
  let limit = @interfaces.rpc_int_or_none(request, "limit")
  let min_score = @interfaces.rpc_optional_double(request, "min_score", 0.0)
  let results = self.search(embedding, limit~, min_score~)
  @interfaces.rpc_success_array(
    "results",
    results,
    memory_search_result_to_json,
    request.id,
  )
}

///|
fn SqliteMemoryPlugin::handle_search_text(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let query = match @interfaces.rpc_require_string(request, "query") {
    Ok(q) => q
    Err(response) => return response
  }
  let limit = @interfaces.rpc_int_or_none(request, "limit")
  let results = self.search_text(query, limit~)
  @interfaces.rpc_success_array(
    "results",
    results,
    memory_entry_to_json,
    request.id,
  )
}

///|
fn SqliteMemoryPlugin::handle_get(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let id = match @interfaces.rpc_require_string(request, "id") {
    Ok(i) => i
    Err(response) => return response
  }
  match self.get(id) {
    Some(entry) => {
      let result : Map[String, Json] = {}
      result["entry"] = memory_entry_to_json(entry)
      @interfaces.JsonRpcResponse::success(
        result=Json::object(result),
        id=request.id,
      )
    }
    None => @interfaces.rpc_null_result("entry", request.id)
  }
}

///|
fn SqliteMemoryPlugin::handle_forget(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let id = match @interfaces.rpc_require_string(request, "id") {
    Ok(i) => i
    Err(response) => return response
  }
  let deleted = self.forget(id)
  @interfaces.rpc_success_bool("deleted", deleted, request.id)
}

///|
fn SqliteMemoryPlugin::handle_update_importance(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let id = match @interfaces.rpc_require_string(request, "id") {
    Ok(i) => i
    Err(response) => return response
  }
  let importance = match @interfaces.rpc_require_double(request, "importance") {
    Ok(i) => i
    Err(response) => return response
  }
  let updated = self.update_importance(id, importance)
  @interfaces.rpc_success_bool("updated", updated, request.id)
}

///|
fn SqliteMemoryPlugin::handle_get_recent(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let limit = @interfaces.rpc_int_or_none(request, "limit")
  let results = self.get_recent(limit~)
  @interfaces.rpc_success_array(
    "results",
    results,
    memory_entry_to_json,
    request.id,
  )
}

///|
fn SqliteMemoryPlugin::handle_compact(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let keep_count = match @interfaces.rpc_require_int(request, "keep_count") {
    Ok(k) => k
    Err(response) => return response
  }
  let removed = self.compact(keep_count)
  @interfaces.rpc_success_int("removed", removed, request.id)
}

///|
fn SqliteMemoryPlugin::handle_count(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let count = self.count()
  @interfaces.rpc_success_int("count", count, request.id)
}

///|
fn SqliteMemoryPlugin::handle_clear(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.clear()
  @interfaces.rpc_ok(request.id)
}

///|
fn SqliteMemoryPlugin::handle_connect(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.connect()
  @interfaces.rpc_connect_response(request.id)
}

///|
fn SqliteMemoryPlugin::handle_disconnect(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.disconnect()
  @interfaces.rpc_disconnect_response(request.id)
}

///|
fn SqliteMemoryPlugin::handle_status(
  self : SqliteMemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let extra : Map[String, Json] = {
    "db_path": Json::string(self.config.db_path),
    "count": Json::number(self.memories.length().to_double()),
    "embedding_dimension": Json::number(
      self.config.embedding_dimension.to_double(),
    ),
  }
  @interfaces.rpc_status_response(self.is_connected, extra, request.id)
}
