///|
/// Trace Plugin - Conversation Memory Compression and Recall
/// Provides short-term/long-term memory with NCD segmentation and vector search

///|
/// Trace plugin configuration
pub(all) struct TracePluginConfig {
  /// Plugin name
  name : String
  /// Database file path
  db_path : String
  /// Embedding dimension (default 1536 for OpenAI)
  embedding_dimension : Int
  /// Maximum search results
  max_search_results : Int
  /// Target digest ratio (0.0 - 1.0)
  target_digest_ratio : Double
  /// Max tokens for short-term memory in system prompt
  max_short_term_tokens : Int
}

///|
/// Default trace plugin config
pub fn TracePluginConfig::default(
  name~ : String,
  db_path~ : String,
) -> TracePluginConfig {
  {
    name,
    db_path,
    embedding_dimension: 1536,
    max_search_results: 5,
    target_digest_ratio: 0.3,
    max_short_term_tokens: 2000,
  }
}

///|
/// Trace plugin
pub struct TracePlugin {
  config : TracePluginConfig
  /// Short-term memory entries (in-memory cache)
  short_term : Map[String, @interfaces.ShortTermMemoryEntry]
  /// Long-term segments (in-memory cache)
  long_term : Map[String, @interfaces.LongTermSegment]
  /// Connection state
  mut is_connected : Bool
  /// Timestamp provider
  mut get_timestamp : () -> Int64
  /// ID generator
  id_gen : @util.IdGenerator
}

///|
/// Create new trace plugin
pub fn TracePlugin::new(config : TracePluginConfig) -> TracePlugin {
  {
    config,
    short_term: {},
    long_term: {},
    is_connected: false,
    get_timestamp: fn() { 0L },
    id_gen: @util.IdGenerator::new("trace_"),
  }
}

///|
/// Set timestamp provider
pub fn TracePlugin::set_timestamp_provider(
  self : TracePlugin,
  provider : () -> Int64,
) -> Unit {
  self.get_timestamp = provider
}

///|
/// Connect to database
pub fn TracePlugin::connect(self : TracePlugin) -> Unit {
  // In-memory implementation
  // Native SQLite would create schema:
  // CREATE TABLE short_term_memory (
  //   id INTEGER PRIMARY KEY,
  //   session_id TEXT UNIQUE NOT NULL,
  //   date TEXT NOT NULL,
  //   digest TEXT NOT NULL,
  //   topics TEXT,
  //   original_message_count INTEGER,
  //   estimated_tokens INTEGER,
  //   created_at INTEGER,
  //   source_file_path TEXT
  // );
  // CREATE TABLE long_term_segments (
  //   id TEXT PRIMARY KEY,
  //   content TEXT NOT NULL,
  //   embedding BLOB,
  //   source_sessions TEXT,
  //   time_range_start INTEGER,
  //   time_range_end INTEGER,
  //   topics TEXT,
  //   compression_ratio REAL,
  //   created_at INTEGER
  // );
  self.is_connected = true
}

///|
/// Disconnect
pub fn TracePlugin::disconnect(self : TracePlugin) -> Unit {
  self.is_connected = false
}

///|
/// Check if connected
pub fn TracePlugin::is_connected(self : TracePlugin) -> Bool {
  self.is_connected
}

// =============================================================================
// Short-Term Memory Operations
// =============================================================================

///|
/// Save short-term memory entry
pub fn TracePlugin::save_short_term(
  self : TracePlugin,
  entry : @interfaces.ShortTermMemoryEntry,
) -> Unit {
  self.short_term[entry.session_id] = entry
}

///|
/// Get short-term memory by session ID
pub fn TracePlugin::get_short_term_by_session(
  self : TracePlugin,
  session_id : String,
) -> @interfaces.ShortTermMemoryEntry? {
  self.short_term.get(session_id)
}

///|
/// Get daily short-term memories
pub fn TracePlugin::get_daily_memory(
  self : TracePlugin,
  date : String,
) -> Array[@interfaces.ShortTermMemoryEntry] {
  let result : Array[@interfaces.ShortTermMemoryEntry] = []
  for _, entry in self.short_term {
    if entry.date == date {
      result.push(entry)
    }
  }
  result
}

///|
/// Get recent short-term memories (last N days)
pub fn TracePlugin::list_recent_short_term(
  self : TracePlugin,
  days : Int,
) -> Array[@interfaces.ShortTermMemoryEntry] {
  // In-memory: return all (proper implementation would filter by date)
  let result : Array[@interfaces.ShortTermMemoryEntry] = []
  for _, entry in self.short_term {
    result.push(entry)
  }
  // Sort by created_at descending (bubble sort for simplicity)
  for i = 0; i < result.length(); i = i + 1 {
    for j = i + 1; j < result.length(); j = j + 1 {
      if result[j].created_at > result[i].created_at {
        let temp = result[i]
        result[i] = result[j]
        result[j] = temp
      }
    }
  }
  ignore(days)
  result
}

///|
/// Delete short-term memory
pub fn TracePlugin::delete_short_term(
  self : TracePlugin,
  session_id : String,
) -> Bool {
  match self.short_term.get(session_id) {
    Some(_) => {
      self.short_term.remove(session_id)
      true
    }
    None => false
  }
}

// =============================================================================
// Long-Term Memory Operations
// =============================================================================

///|
/// Save long-term segment
pub fn TracePlugin::save_segment(
  self : TracePlugin,
  segment : @interfaces.LongTermSegment,
) -> Unit {
  self.long_term[segment.id] = segment
}

///|
/// Get segment by ID
pub fn TracePlugin::get_segment(
  self : TracePlugin,
  id : String,
) -> @interfaces.LongTermSegment? {
  self.long_term.get(id)
}

///|
/// Search segments by vector similarity
pub fn TracePlugin::search_segments_by_vector(
  self : TracePlugin,
  embedding : Array[Double],
  limit : Int,
) -> Array[(@interfaces.LongTermSegment, Double)] {
  let results : Array[(@interfaces.LongTermSegment, Double)] = []
  for _, segment in self.long_term {
    match segment.embedding {
      Some(seg_emb) => {
        let score = trace_cosine_similarity(embedding, seg_emb)
        results.push((segment, score))
      }
      None => ()
    }
  }
  // Sort by score descending
  for i = 0; i < results.length(); i = i + 1 {
    for j = i + 1; j < results.length(); j = j + 1 {
      if results[j].1 > results[i].1 {
        let temp = results[i]
        results[i] = results[j]
        results[j] = temp
      }
    }
  }
  // Return top N
  let final_results : Array[(@interfaces.LongTermSegment, Double)] = []
  for i = 0; i < results.length() && i < limit; i = i + 1 {
    final_results.push(results[i])
  }
  final_results
}

///|
/// Get segments by time range
pub fn TracePlugin::get_segments_by_time(
  self : TracePlugin,
  start : Int64,
  end : Int64,
) -> Array[@interfaces.LongTermSegment] {
  let result : Array[@interfaces.LongTermSegment] = []
  for _, segment in self.long_term {
    if segment.time_range_start >= start && segment.time_range_end <= end {
      result.push(segment)
    }
  }
  result
}

///|
/// Search segments by topic
pub fn TracePlugin::search_segments_by_topic(
  self : TracePlugin,
  topics : Array[String],
  limit : Int,
) -> Array[@interfaces.LongTermSegment] {
  let result : Array[@interfaces.LongTermSegment] = []
  for _, segment in self.long_term {
    // Check if any topic matches
    let mut matches = false
    for topic in topics {
      for seg_topic in segment.topics {
        if seg_topic == topic {
          matches = true
          break
        }
      }
      if matches {
        break
      }
    }
    if matches {
      result.push(segment)
      if result.length() >= limit {
        break
      }
    }
  }
  result
}

///|
/// Delete segment
pub fn TracePlugin::delete_segment(self : TracePlugin, id : String) -> Bool {
  match self.long_term.get(id) {
    Some(_) => {
      self.long_term.remove(id)
      true
    }
    None => false
  }
}

// =============================================================================
// Utility Functions
// =============================================================================

///|
/// Cosine similarity between two vectors
fn trace_cosine_similarity(a : Array[Double], b : Array[Double]) -> Double {
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
  dot_product / (trace_sqrt(norm_a) * trace_sqrt(norm_b))
}

///|
/// Square root approximation
fn trace_sqrt(x : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  let mut guess = x / 2.0
  for _i = 0; _i < 20; _i = _i + 1 {
    guess = (guess + x / guess) / 2.0
  }
  guess
}

// =============================================================================
// JSON-RPC Interface
// =============================================================================

///|
/// Handle JSON-RPC request
pub fn TracePlugin::handle_request(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    // Short-term memory
    "save_short_term" => self.handle_save_short_term(request)
    "get_short_term" => self.handle_get_short_term(request)
    "get_daily" => self.handle_get_daily(request)
    "list_recent" => self.handle_list_recent(request)
    "delete_short_term" => self.handle_delete_short_term(request)
    // Long-term memory
    "save_segment" => self.handle_save_segment(request)
    "get_segment" => self.handle_get_segment(request)
    "search_by_vector" => self.handle_search_by_vector(request)
    "search_by_time" => self.handle_search_by_time(request)
    "search_by_topic" => self.handle_search_by_topic(request)
    "delete_segment" => self.handle_delete_segment(request)
    // Recall
    "recall" => self.handle_recall(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn TracePlugin::handle_save_short_term(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let session_id = match @interfaces.rpc_require_string(request, "session_id") {
    Ok(s) => s
    Err(resp) => return resp
  }
  let date = match @interfaces.rpc_require_string(request, "date") {
    Ok(s) => s
    Err(resp) => return resp
  }
  let digest = match @interfaces.rpc_require_string(request, "digest") {
    Ok(s) => s
    Err(resp) => return resp
  }
  let topics = @interfaces.rpc_string_array(request, "topics")
  let original_message_count = @interfaces.rpc_optional_int(
    request,
    "original_message_count",
    0,
  )
  let estimated_tokens = @interfaces.rpc_optional_int(
    request,
    "estimated_tokens",
    0,
  )
  let source_file_path = @interfaces.rpc_optional_string(
    request,
    "source_file_path",
    "",
  )
  let entry : @interfaces.ShortTermMemoryEntry = {
    session_id,
    date,
    digest,
    topics,
    original_message_count,
    estimated_tokens,
    created_at: (self.get_timestamp)(),
    source_file_path,
  }
  self.save_short_term(entry)
  @interfaces.rpc_ok(request.id)
}

///|
fn TracePlugin::handle_get_short_term(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let session_id = match @interfaces.rpc_require_string(request, "session_id") {
    Ok(s) => s
    Err(resp) => return resp
  }
  match self.get_short_term_by_session(session_id) {
    Some(entry) =>
      @interfaces.JsonRpcResponse::success(
        result={
          "session_id": entry.session_id,
          "date": entry.date,
          "digest": entry.digest,
          "topics": Json::array(entry.topics.map(fn(t) { Json::string(t) })),
          "original_message_count": Json::number(entry.original_message_count.to_double()),
          "estimated_tokens": Json::number(entry.estimated_tokens.to_double()),
          "created_at": Json::number(entry.created_at.to_double()),
          "source_file_path": entry.source_file_path,
        },
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Short-term memory not found",
        id=request.id,
      )
  }
}

///|
fn TracePlugin::handle_get_daily(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let date = match @interfaces.rpc_require_string(request, "date") {
    Ok(s) => s
    Err(resp) => return resp
  }
  let entries = self.get_daily_memory(date)
  let entries_json : Array[Json] = entries.map(
    fn(e) {
      Json::object({
        "session_id": e.session_id,
        "date": e.date,
        "digest": e.digest,
        "estimated_tokens": Json::number(e.estimated_tokens.to_double()),
      })
    },
  )
  @interfaces.JsonRpcResponse::success(
    result={ "entries": Json::array(entries_json) },
    id=request.id,
  )
}

///|
fn TracePlugin::handle_list_recent(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let days = @interfaces.rpc_optional_int(request, "days", 7)
  let entries = self.list_recent_short_term(days)
  let entries_json : Array[Json] = entries.map(
    fn(e) {
      Json::object({
        "session_id": e.session_id,
        "date": e.date,
        "digest": e.digest,
        "estimated_tokens": Json::number(e.estimated_tokens.to_double()),
      })
    },
  )
  @interfaces.JsonRpcResponse::success(
    result={ "entries": Json::array(entries_json) },
    id=request.id,
  )
}

///|
fn TracePlugin::handle_delete_short_term(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let session_id = match @interfaces.rpc_require_string(request, "session_id") {
    Ok(s) => s
    Err(resp) => return resp
  }
  let deleted = self.delete_short_term(session_id)
  @interfaces.rpc_success_bool("deleted", deleted, request.id)
}

///|
fn TracePlugin::handle_save_segment(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let id = self.id_gen.next()
  let content = match @interfaces.rpc_require_string(request, "content") {
    Ok(s) => s
    Err(resp) => return resp
  }
  let embedding_arr = @interfaces.rpc_double_array(request, "embedding")
  let embedding : Array[Double]? = if embedding_arr.length() > 0 {
    Some(embedding_arr)
  } else {
    None
  }
  let source_sessions = @interfaces.rpc_string_array(request, "source_sessions")
  let time_range_start : Int64 = @interfaces.rpc_optional_double(
      request,
      "time_range_start",
      0.0,
    )
    .to_int64()
  let time_range_end : Int64 = @interfaces.rpc_optional_double(
      request,
      "time_range_end",
      0.0,
    )
    .to_int64()
  let topics = @interfaces.rpc_string_array(request, "topics")
  let compression_ratio = @interfaces.rpc_optional_double(
    request,
    "compression_ratio",
    1.0,
  )
  let segment : @interfaces.LongTermSegment = {
    id,
    content,
    embedding,
    source_sessions,
    time_range_start,
    time_range_end,
    topics,
    compression_ratio,
    created_at: (self.get_timestamp)(),
  }
  self.save_segment(segment)
  @interfaces.JsonRpcResponse::success(result={ "id": id }, id=request.id)
}

///|
fn TracePlugin::handle_get_segment(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let id = match @interfaces.rpc_require_string(request, "id") {
    Ok(s) => s
    Err(resp) => return resp
  }
  match self.get_segment(id) {
    Some(seg) => {
      let embedding_json : Json = match seg.embedding {
        Some(emb) => Json::array(emb.map(fn(v) { Json::number(v) }))
        None => Json::null()
      }
      @interfaces.JsonRpcResponse::success(
        result={
          "id": seg.id,
          "content": seg.content,
          "embedding": embedding_json,
          "source_sessions": Json::array(seg.source_sessions.map(fn(s) {
            Json::string(s)
          })),
          "time_range_start": Json::number(seg.time_range_start.to_double()),
          "time_range_end": Json::number(seg.time_range_end.to_double()),
          "topics": Json::array(seg.topics.map(fn(t) { Json::string(t) })),
          "compression_ratio": Json::number(seg.compression_ratio),
          "created_at": Json::number(seg.created_at.to_double()),
        },
        id=request.id,
      )
    }
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Segment not found",
        id=request.id,
      )
  }
}

///|
fn TracePlugin::handle_search_by_vector(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let embedding = @interfaces.rpc_double_array(request, "embedding")
  if embedding.length() == 0 {
    return @interfaces.rpc_invalid_params(
      "Missing or empty 'embedding' parameter",
      request.id,
    )
  }
  let limit = @interfaces.rpc_optional_int(
    request,
    "limit",
    self.config.max_search_results,
  )
  let results = self.search_segments_by_vector(embedding, limit)
  let results_json : Array[Json] = results.map(
    fn(r) {
      let (seg, score) = r
      Json::object({
        "id": seg.id,
        "content": seg.content,
        "score": Json::number(score),
        "time_range_start": Json::number(seg.time_range_start.to_double()),
        "time_range_end": Json::number(seg.time_range_end.to_double()),
      })
    },
  )
  @interfaces.JsonRpcResponse::success(
    result={ "results": Json::array(results_json) },
    id=request.id,
  )
}

///|
fn TracePlugin::handle_search_by_time(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let start : Int64 = @interfaces.rpc_optional_double(request, "start", 0.0)
    .to_int64()
  let end : Int64 = @interfaces.rpc_optional_double(
      request,
      "end",
      9999999999999.0,
    )
    .to_int64()
  let segments = self.get_segments_by_time(start, end)
  let segments_json : Array[Json] = segments.map(
    fn(seg) {
      Json::object({
        "id": seg.id,
        "content": seg.content,
        "time_range_start": Json::number(seg.time_range_start.to_double()),
        "time_range_end": Json::number(seg.time_range_end.to_double()),
      })
    },
  )
  @interfaces.JsonRpcResponse::success(
    result={ "segments": Json::array(segments_json) },
    id=request.id,
  )
}

///|
fn TracePlugin::handle_search_by_topic(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let topics = @interfaces.rpc_string_array(request, "topics")
  if topics.length() == 0 {
    return @interfaces.rpc_invalid_params(
      "Missing or empty 'topics' parameter",
      request.id,
    )
  }
  let limit = @interfaces.rpc_optional_int(
    request,
    "limit",
    self.config.max_search_results,
  )
  let segments = self.search_segments_by_topic(topics, limit)
  let segments_json : Array[Json] = segments.map(
    fn(seg) {
      Json::object({
        "id": seg.id,
        "content": seg.content,
        "topics": Json::array(seg.topics.map(fn(t) { Json::string(t) })),
      })
    },
  )
  @interfaces.JsonRpcResponse::success(
    result={ "segments": Json::array(segments_json) },
    id=request.id,
  )
}

///|
fn TracePlugin::handle_delete_segment(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let id = match @interfaces.rpc_require_string(request, "id") {
    Ok(s) => s
    Err(resp) => return resp
  }
  let deleted = self.delete_segment(id)
  @interfaces.rpc_success_bool("deleted", deleted, request.id)
}

///|
/// Handle recall request - searches both short-term and long-term memory
fn TracePlugin::handle_recall(
  self : TracePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let action = @interfaces.rpc_optional_string(request, "action", "search")
  match action {
    "search" => {
      // Vector search in long-term memory
      let embedding = @interfaces.rpc_double_array(request, "embedding")
      if embedding.length() == 0 {
        return @interfaces.rpc_invalid_params(
          "Missing 'embedding' for search action",
          request.id,
        )
      }
      let limit = @interfaces.rpc_optional_int(request, "limit", 5)
      let results = self.search_segments_by_vector(embedding, limit)
      let results_json : Array[Json] = results.map(
        fn(r) {
          let (seg, score) = r
          Json::object({
            "content": seg.content,
            "score": Json::number(score),
            "source_type": "long_term",
            "source_sessions": Json::array(seg.source_sessions.map(fn(s) {
              Json::string(s)
            })),
          })
        },
      )
      @interfaces.JsonRpcResponse::success(
        result={ "results": Json::array(results_json) },
        id=request.id,
      )
    }
    "recent" => {
      // Get recent short-term memories
      let days = @interfaces.rpc_optional_int(request, "days", 7)
      let entries = self.list_recent_short_term(days)
      let entries_json : Array[Json] = entries.map(
        fn(e) {
          Json::object({
            "content": e.digest,
            "source_type": "short_term",
            "session_id": e.session_id,
            "date": e.date,
          })
        },
      )
      @interfaces.JsonRpcResponse::success(
        result={ "results": Json::array(entries_json) },
        id=request.id,
      )
    }
    "by_date" => {
      let date = match @interfaces.rpc_require_string(request, "date") {
        Ok(s) => s
        Err(resp) => return resp
      }
      let entries = self.get_daily_memory(date)
      let entries_json : Array[Json] = entries.map(
        fn(e) {
          Json::object({
            "content": e.digest,
            "source_type": "short_term",
            "session_id": e.session_id,
          })
        },
      )
      @interfaces.JsonRpcResponse::success(
        result={ "results": Json::array(entries_json) },
        id=request.id,
      )
    }
    "by_topic" => {
      let topics = @interfaces.rpc_string_array(request, "topics")
      if topics.length() == 0 {
        return @interfaces.rpc_invalid_params(
          "Missing 'topics' for by_topic action",
          request.id,
        )
      }
      let limit = @interfaces.rpc_optional_int(request, "limit", 5)
      let segments = self.search_segments_by_topic(topics, limit)
      let results_json : Array[Json] = segments.map(
        fn(seg) {
          Json::object({
            "content": seg.content,
            "source_type": "long_term",
            "topics": Json::array(seg.topics.map(fn(t) { Json::string(t) })),
          })
        },
      )
      @interfaces.JsonRpcResponse::success(
        result={ "results": Json::array(results_json) },
        id=request.id,
      )
    }
    _ =>
      @interfaces.rpc_invalid_params(
        "Invalid action: \{action}. Use 'search', 'recent', 'by_date', or 'by_topic'",
        request.id,
      )
  }
}
