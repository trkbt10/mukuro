///|
/// Memory/RAG Plugin
/// Provides persistent memory with vector search for context retrieval

///|
/// Memory entry with embedding
pub(all) struct MemoryEntry {
  /// Unique ID
  id : String
  /// Content text
  content : String
  /// Embedding vector (normalized)
  embedding : Array[Double]
  /// Metadata
  metadata : Map[String, Json]
  /// Timestamp
  timestamp : Int64
  /// Source (e.g., "conversation", "document", "user")
  source : String
  /// Importance score (0.0 - 1.0)
  importance : Double
}

///|
/// Search result
pub(all) struct SearchResult {
  /// Memory entry
  entry : MemoryEntry
  /// Similarity score (0.0 - 1.0)
  score : Double
}

///|
/// Memory plugin configuration
pub(all) struct MemoryPluginConfig {
  /// Plugin name
  name : String
  /// Embedding dimension
  embedding_dim : Int
  /// Maximum entries
  max_entries : Int
  /// Default search limit
  default_search_limit : Int
  /// Minimum similarity threshold
  min_similarity : Double
  /// Enable auto-compaction
  auto_compact : Bool
}

///|
/// Default memory config
pub fn MemoryPluginConfig::default(name~ : String) -> MemoryPluginConfig {
  {
    name,
    embedding_dim: 1536, // OpenAI ada-002 dimension
    max_entries: 10000,
    default_search_limit: 10,
    min_similarity: 0.7,
    auto_compact: true,
  }
}

///|
/// Memory plugin
pub struct MemoryPlugin {
  config : MemoryPluginConfig
  /// All memory entries
  entries : Map[String, MemoryEntry]
  /// ID generator
  id_gen : @util.IdGenerator
  /// Timestamp provider
  mut get_timestamp : () -> Int64
}

///|
/// Create new memory plugin
pub fn MemoryPlugin::new(config : MemoryPluginConfig) -> MemoryPlugin {
  {
    config,
    entries: {},
    id_gen: @util.IdGenerator::new("mem_"),
    get_timestamp: fn() { 0L },
  }
}

///|
/// Set timestamp provider
pub fn MemoryPlugin::set_timestamp_provider(
  self : MemoryPlugin,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Compute cosine similarity between two vectors
fn cosine_similarity(a : Array[Double], b : Array[Double]) -> Double {
  if a.length() != b.length() || a.length() == 0 {
    return 0.0
  }
  let mut dot_product = 0.0
  let mut norm_a = 0.0
  let mut norm_b = 0.0
  for i = 0; i < a.length(); i = i + 1 {
    dot_product = dot_product + a[i] * b[i]
    norm_a = norm_a + a[i] * a[i]
    norm_b = norm_b + b[i] * b[i]
  }
  if norm_a == 0.0 || norm_b == 0.0 {
    return 0.0
  }
  dot_product / (sqrt(norm_a) * sqrt(norm_b))
}

///|
/// Simple square root approximation
fn sqrt(x : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  // Newton's method
  let mut guess = x / 2.0
  for _i = 0; _i < 20; _i = _i + 1 {
    guess = (guess + x / guess) / 2.0
  }
  guess
}

///|
/// Store a memory entry
pub fn MemoryPlugin::remember(
  self : MemoryPlugin,
  content : String,
  embedding : Array[Double],
  metadata? : Map[String, Json] = {},
  source? : String = "user",
  importance? : Double = 0.5,
) -> String {
  // Check max entries and compact if needed
  if self.config.auto_compact &&
    self.entries.length() >= self.config.max_entries {
    let _ = self.compact()
  }
  let id = self.id_gen.next()
  let timestamp = (self.get_timestamp)()
  let entry : MemoryEntry = {
    id,
    content,
    embedding,
    metadata,
    timestamp,
    source,
    importance,
  }
  self.entries[id] = entry
  id
}

///|
/// Search for similar memories
pub fn MemoryPlugin::search(
  self : MemoryPlugin,
  query_embedding : Array[Double],
  limit? : Int? = None,
  min_similarity? : Double? = None,
  source_filter? : String? = None,
) -> Array[SearchResult] {
  let actual_limit = match limit {
    Some(l) => l
    None => self.config.default_search_limit
  }
  let actual_min_sim = match min_similarity {
    Some(s) => s
    None => self.config.min_similarity
  }
  // Calculate similarities
  let results : Array[SearchResult] = []
  for _, entry in self.entries {
    // Apply source filter
    match source_filter {
      Some(filter) => if entry.source != filter { continue }
      None => ()
    }
    let score = cosine_similarity(query_embedding, entry.embedding)
    if score >= actual_min_sim {
      results.push({ entry, score })
    }
  }
  // Sort by score (descending) - simple bubble sort for now
  for i = 0; i < results.length(); i = i + 1 {
    for j = i + 1; j < results.length(); j = j + 1 {
      if results[j].score > results[i].score {
        let temp = results[i]
        results[i] = results[j]
        results[j] = temp
      }
    }
  }
  // Return top results
  let final_results : Array[SearchResult] = []
  for i = 0; i < results.length() && i < actual_limit; i = i + 1 {
    final_results.push(results[i])
  }
  final_results
}

///|
/// Get memory by ID
pub fn MemoryPlugin::get(self : MemoryPlugin, id : String) -> MemoryEntry? {
  self.entries.get(id)
}

///|
/// Delete memory by ID
pub fn MemoryPlugin::forget(self : MemoryPlugin, id : String) -> Bool {
  match self.entries.get(id) {
    Some(_) => {
      self.entries.remove(id)
      true
    }
    None => false
  }
}

///|
/// Update importance score
pub fn MemoryPlugin::update_importance(
  self : MemoryPlugin,
  id : String,
  importance : Double,
) -> Bool {
  match self.entries.get(id) {
    Some(entry) => {
      let updated : MemoryEntry = {
        id: entry.id,
        content: entry.content,
        embedding: entry.embedding,
        metadata: entry.metadata,
        timestamp: entry.timestamp,
        source: entry.source,
        importance,
      }
      self.entries[id] = updated
      true
    }
    None => false
  }
}

///|
/// Get recent memories
pub fn MemoryPlugin::get_recent(
  self : MemoryPlugin,
  limit : Int,
) -> Array[MemoryEntry] {
  let all : Array[MemoryEntry] = []
  for _, entry in self.entries {
    all.push(entry)
  }
  // Sort by timestamp (descending)
  for i = 0; i < all.length(); i = i + 1 {
    for j = i + 1; j < all.length(); j = j + 1 {
      if all[j].timestamp > all[i].timestamp {
        let temp = all[i]
        all[i] = all[j]
        all[j] = temp
      }
    }
  }
  // Return top results
  let results : Array[MemoryEntry] = []
  for i = 0; i < all.length() && i < limit; i = i + 1 {
    results.push(all[i])
  }
  results
}

///|
/// Compact memory by removing low importance entries
pub fn MemoryPlugin::compact(self : MemoryPlugin) -> Int {
  let threshold = 0.3 // Remove entries with importance below this
  let to_remove : Array[String] = []
  for id, entry in self.entries {
    if entry.importance < threshold {
      to_remove.push(id)
    }
  }
  for id in to_remove {
    self.entries.remove(id)
  }
  to_remove.length()
}

///|
/// Clear all memories
pub fn MemoryPlugin::clear(self : MemoryPlugin) -> Unit {
  self.entries.clear()
}

///|
/// Get memory count
pub fn MemoryPlugin::count(self : MemoryPlugin) -> Int {
  self.entries.length()
}

///|
/// Handle JSON-RPC request
pub fn MemoryPlugin::handle_request(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "remember" => self.handle_remember(request)
    "search" => self.handle_search(request)
    "get" => self.handle_get(request)
    "forget" => self.handle_forget(request)
    "update_importance" => self.handle_update_importance(request)
    "get_recent" => self.handle_get_recent(request)
    "compact" => self.handle_compact(request)
    "clear" => self.handle_clear(request)
    "count" => self.handle_count(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn MemoryPlugin::handle_remember(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let content = match @interfaces.rpc_require_string(request, "content") {
    Ok(c) => c
    Err(response) => return response
  }
  let embedding = @interfaces.rpc_double_array(request, "embedding")
  if embedding.length() == 0 {
    return @interfaces.rpc_invalid_params(
      "Missing or empty 'embedding' parameter",
      request.id,
    )
  }
  let metadata : Map[String, Json] = match
    @interfaces.rpc_object_or_none(request, "metadata") {
    Some(m) => m
    None => {}
  }
  let source = @interfaces.rpc_optional_string(request, "source", "user")
  let importance = @interfaces.rpc_optional_double(request, "importance", 0.5)
  let id = self.remember(content, embedding, metadata~, source~, importance~)
  @interfaces.JsonRpcResponse::success(result={ "id": id }, id=request.id)
}

///|
fn MemoryPlugin::handle_search(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let embedding = @interfaces.rpc_double_array(request, "embedding")
  if embedding.length() == 0 {
    return @interfaces.rpc_invalid_params(
      "Missing or empty 'embedding' parameter",
      request.id,
    )
  }
  let limit = @interfaces.rpc_int_or_none(request, "limit")
  let min_similarity = @interfaces.rpc_double_or_none(request, "min_similarity")
  let source_filter = @interfaces.rpc_string_or_none(request, "source")
  let results = self.search(embedding, limit~, min_similarity~, source_filter~)
  let results_json : Array[Json] = []
  for r in results {
    let entry_json : Map[String, Json] = {
      "id": r.entry.id,
      "content": r.entry.content,
      "source": r.entry.source,
      "importance": Json::number(r.entry.importance),
      "timestamp": Json::number(r.entry.timestamp.to_double()),
      "score": Json::number(r.score),
    }
    results_json.push(Json::object(entry_json))
  }
  @interfaces.JsonRpcResponse::success(
    result={ "results": Json::array(results_json) },
    id=request.id,
  )
}

///|
fn MemoryPlugin::handle_get(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let mem_id = match @interfaces.rpc_require_string(request, "id") {
    Ok(id) => id
    Err(response) => return response
  }
  match self.get(mem_id) {
    Some(entry) =>
      @interfaces.JsonRpcResponse::success(
        result={
          "id": entry.id,
          "content": entry.content,
          "source": entry.source,
          "importance": Json::number(entry.importance),
          "timestamp": Json::number(entry.timestamp.to_double()),
        },
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Memory not found",
        id=request.id,
      )
  }
}

///|
fn MemoryPlugin::handle_forget(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let mem_id = match @interfaces.rpc_require_string(request, "id") {
    Ok(id) => id
    Err(response) => return response
  }
  let forgot = self.forget(mem_id)
  @interfaces.rpc_success_bool("deleted", forgot, request.id)
}

///|
fn MemoryPlugin::handle_update_importance(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let mem_id = match @interfaces.rpc_require_string(request, "id") {
    Ok(id) => id
    Err(response) => return response
  }
  let importance = match @interfaces.rpc_require_double(request, "importance") {
    Ok(imp) => imp
    Err(response) => return response
  }
  let updated = self.update_importance(mem_id, importance)
  @interfaces.rpc_success_bool("updated", updated, request.id)
}

///|
fn MemoryPlugin::handle_get_recent(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let limit = @interfaces.rpc_optional_int(request, "limit", 10)
  let entries = self.get_recent(limit)
  let entries_json : Array[Json] = []
  for entry in entries {
    let entry_json : Map[String, Json] = {
      "id": entry.id,
      "content": entry.content,
      "source": entry.source,
      "importance": Json::number(entry.importance),
      "timestamp": Json::number(entry.timestamp.to_double()),
    }
    entries_json.push(Json::object(entry_json))
  }
  @interfaces.JsonRpcResponse::success(
    result={ "entries": Json::array(entries_json) },
    id=request.id,
  )
}

///|
fn MemoryPlugin::handle_compact(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let removed = self.compact()
  @interfaces.JsonRpcResponse::success(
    result={ "removed": Json::number(removed.to_double()) },
    id=request.id,
  )
}

///|
fn MemoryPlugin::handle_clear(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.clear()
  @interfaces.rpc_ok(request.id)
}

///|
fn MemoryPlugin::handle_count(
  self : MemoryPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let cnt = self.count()
  @interfaces.rpc_success_int("count", cnt, request.id)
}
