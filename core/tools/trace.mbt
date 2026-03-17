///|
/// Trace/Recall ツール - 会話履歴の記憶と想起
/// NCD + TF-IDF セグメンテーションで長期記憶を圧縮・検索

// =============================================================================
// Tool Definition
// =============================================================================

///|
pub fn trace_tool() -> @llm_types.ToolDefinition {
  make_tool_definition(
    name="trace",
    description="Recall past conversations and context. Use this to retrieve relevant information from previous sessions. Actions: 'recent' for recent context, 'search' for semantic search, 'by_date' for specific dates, 'by_topic' for topic-based retrieval.",
    parameters=object_schema(
      {
        "action": {
          "type": "string",
          "enum": Json::array([
            Json::string("recent"),
            Json::string("search"),
            Json::string("by_date"),
            Json::string("by_topic"),
            Json::string("segment"),
          ]),
          "description": "Action: 'recent' (last N days), 'search' (semantic), 'by_date', 'by_topic', 'segment' (split text into chunks)",
        },
        "query": string_param(
          "Search query for semantic search (action=search)",
        ),
        "days": {
          "type": "number",
          "description": "Number of days to look back (action=recent, default 7)",
        },
        "date": string_param("Date in YYYY-MM-DD format (action=by_date)"),
        "topics": {
          "type": "array",
          "items": { "type": "string" },
          "description": "List of topics to search (action=by_topic)",
        },
        "text": string_param("Text to segment (action=segment)"),
        "limit": {
          "type": "number",
          "description": "Maximum results to return (default 5)",
        },
      },
      ["action"],
    ),
  )
}

///|
/// Trace tool settings schema for UI
pub fn trace_settings_schema() -> Json {
  build_settings_schema(
    title="Trace/Memory Settings",
    description="Configure conversation memory and recall behavior",
    fields=[
      number_field(
        key="max_short_term_days",
        label="Short-Term Memory Days",
        description="Number of days to keep in short-term memory",
        default_value=7.0,
        min=Some(1.0),
        max=Some(30.0),
      ),
      number_field(
        key="max_search_results",
        label="Max Search Results",
        description="Maximum number of results to return from searches",
        default_value=5.0,
        min=Some(1.0),
        max=Some(20.0),
      ),
      number_field(
        key="ncd_weight",
        label="NCD Weight",
        description="Weight for compression-based similarity (0.0-1.0)",
        default_value=0.5,
        min=Some(0.0),
        max=Some(1.0),
      ),
      number_field(
        key="tfidf_weight",
        label="TF-IDF Weight",
        description="Weight for lexical similarity (0.0-1.0)",
        default_value=0.5,
        min=Some(0.0),
        max=Some(1.0),
      ),
      number_field(
        key="target_segment_size",
        label="Target Segment Size",
        description="Target size for text segments (characters)",
        default_value=500.0,
        min=Some(100.0),
        max=Some(2000.0),
      ),
      toggle_field(
        key="auto_digest",
        label="Auto Digest",
        description="Automatically digest conversations when session ends",
        default_value=true,
      ),
    ],
  )
}

// =============================================================================
// Trace Store (In-Memory Implementation)
// =============================================================================

///|
/// 短期記憶エントリ
pub(all) struct TraceEntry {
  session_id : String
  date : String
  digest : String
  topics : Array[String]
  created_at : Int64
}

///|
/// 長期記憶セグメント
pub(all) struct TraceSegment {
  id : String
  content : String
  topics : Array[String]
  time_range_start : Int64
  time_range_end : Int64
  source_sessions : Array[String]
}

///|
/// Trace Store
pub struct TraceStore {
  short_term : Map[String, TraceEntry]
  long_term : Map[String, TraceSegment]
  mut id_counter : Int
}

///|
pub fn TraceStore::new() -> TraceStore {
  { short_term: {}, long_term: {}, id_counter: 0 }
}

///|
pub fn TraceStore::add_short_term(
  self : TraceStore,
  session_id : String,
  date : String,
  digest : String,
  topics : Array[String],
  created_at : Int64,
) -> Unit {
  self.short_term[session_id] = { session_id, date, digest, topics, created_at }
}

///|
pub fn TraceStore::get_recent(
  self : TraceStore,
  days : Int,
) -> Array[TraceEntry] {
  let result : Array[TraceEntry] = []
  for _, entry in self.short_term {
    result.push(entry)
  }
  // Sort by created_at descending
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
pub fn TraceStore::get_by_date(
  self : TraceStore,
  date : String,
) -> Array[TraceEntry] {
  let result : Array[TraceEntry] = []
  for _, entry in self.short_term {
    if entry.date == date {
      result.push(entry)
    }
  }
  result
}

///|
pub fn TraceStore::search_by_topic(
  self : TraceStore,
  topics : Array[String],
  limit : Int,
) -> Array[TraceSegment] {
  let result : Array[TraceSegment] = []
  for _, segment in self.long_term {
    let mut matches = false
    for topic in topics {
      for seg_topic in segment.topics {
        if seg_topic.to_lower().contains(topic.to_lower()) {
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
pub fn TraceStore::add_segment(
  self : TraceStore,
  content : String,
  topics : Array[String],
  time_range_start : Int64,
  time_range_end : Int64,
  source_sessions : Array[String],
) -> String {
  self.id_counter = self.id_counter + 1
  let id = "seg_\{self.id_counter}"
  self.long_term[id] = {
    id,
    content,
    topics,
    time_range_start,
    time_range_end,
    source_sessions,
  }
  id
}

// =============================================================================
// Tool Implementation
// =============================================================================

///|
/// Traceツールエントリ
pub fn trace_entry() -> ToolEntry {
  {
    name: "trace",
    definition: trace_tool(),
    settings_schema: Some(trace_settings_schema()),
    execute: fn(ctx, args) { execute_trace(ctx.trace, args) },
  }
}

///|
fn execute_trace(store : TraceStore, args : Json) -> ToolExecutionResult {
  let action = match get_string_arg(args, "action") {
    Some(a) => a
    None => return ToolExecutionResult::error("Missing action argument")
  }
  let limit = match args {
    { "limit": Number(n, ..), .. } => n.to_int()
    _ => 5
  }
  match action {
    "recent" => {
      let days = match args {
        { "days": Number(n, ..), .. } => n.to_int()
        _ => 7
      }
      let entries = store.get_recent(days)
      let entries_json : Array[Json] = []
      for i = 0; i < entries.length() && i < limit; i = i + 1 {
        let e = entries[i]
        entries_json.push({
          "session_id": e.session_id,
          "date": e.date,
          "digest": e.digest,
          "topics": Json::array(e.topics.map(fn(t) { Json::string(t) })),
        })
      }
      ToolExecutionResult::success({
        "results": Json::array(entries_json),
        "count": entries_json.length(),
      })
    }
    "by_date" => {
      let date = match get_string_arg(args, "date") {
        Some(d) => d
        None => return ToolExecutionResult::error("Missing date argument")
      }
      let entries = store.get_by_date(date)
      let entries_json : Array[Json] = []
      for i = 0; i < entries.length() && i < limit; i = i + 1 {
        let e = entries[i]
        entries_json.push({
          "session_id": e.session_id,
          "digest": e.digest,
          "topics": Json::array(e.topics.map(fn(t) { Json::string(t) })),
        })
      }
      ToolExecutionResult::success({
        "results": Json::array(entries_json),
        "count": entries_json.length(),
        "date": date,
      })
    }
    "by_topic" => {
      let topics : Array[String] = match args {
        { "topics": Array(arr), .. } =>
          arr.filter_map(fn(j) {
            match j {
              String(s) => Some(s)
              _ => None
            }
          })
        _ => return ToolExecutionResult::error("Missing topics argument")
      }
      let segments = store.search_by_topic(topics, limit)
      let segments_json : Array[Json] = segments.map(fn(s) {
        {
          "id": s.id,
          "content": s.content,
          "topics": Json::array(s.topics.map(fn(t) { Json::string(t) })),
        }
      })
      ToolExecutionResult::success({
        "results": Json::array(segments_json),
        "count": segments_json.length(),
      })
    }
    "search" => {
      let query = match get_string_arg(args, "query") {
        Some(q) => q
        None => return ToolExecutionResult::error("Missing query argument")
      }
      // Simple keyword search in short-term and long-term
      let results : Array[Json] = []
      // Search short-term
      for _, entry in store.short_term {
        if entry.digest.to_lower().contains(query.to_lower()) {
          results.push({
            "type": "short_term",
            "session_id": entry.session_id,
            "content": entry.digest,
            "date": entry.date,
          })
        }
      }
      // Search long-term
      for _, segment in store.long_term {
        if segment.content.to_lower().contains(query.to_lower()) {
          results.push({
            "type": "long_term",
            "id": segment.id,
            "content": segment.content,
          })
        }
      }
      // Limit results
      let limited : Array[Json] = []
      for i = 0; i < results.length() && i < limit; i = i + 1 {
        limited.push(results[i])
      }
      ToolExecutionResult::success({
        "results": Json::array(limited),
        "count": limited.length(),
        "query": query,
      })
    }
    "segment" => {
      let text = match get_string_arg(args, "text") {
        Some(t) => t
        None => return ToolExecutionResult::error("Missing text argument")
      }
      // Use NCD + TF-IDF segmentation from core/trace
      let config = @trace.NcdTfidfConfig::default()
      let result = @trace.segment_by_ncd_tfidf(text, config)
      let chunks_json : Array[Json] = result.chunks.map(fn(c) {
        Json::string(c)
      })
      ToolExecutionResult::success({
        "chunks": Json::array(chunks_json),
        "count": result.chunks.length(),
        "boundaries": Json::array(
          result.boundaries.map(fn(b) { Json::number(b.to_double()) }),
        ),
      })
    }
    _ => ToolExecutionResult::error("Unknown action: \{action}")
  }
}
