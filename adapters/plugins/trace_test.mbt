///|
/// Trace Plugin Unit Tests

test "TracePluginConfig default values" {
  let config = TracePluginConfig::default(name="test", db_path="/tmp/test.db")
  assert_eq(config.name, "test")
  assert_eq(config.db_path, "/tmp/test.db")
  assert_eq(config.embedding_dimension, 1536)
  assert_eq(config.max_search_results, 5)
}

test "TracePlugin connect and disconnect" {
  let config = TracePluginConfig::default(name="test", db_path="/tmp/test.db")
  let plugin = TracePlugin::new(config)
  assert_false(plugin.is_connected())
  plugin.connect()
  assert_true(plugin.is_connected())
  plugin.disconnect()
  assert_false(plugin.is_connected())
}

test "TracePlugin save and get short-term memory" {
  let config = TracePluginConfig::default(name="test", db_path="/tmp/test.db")
  let plugin = TracePlugin::new(config)
  plugin.connect()

  let entry : @interfaces.ShortTermMemoryEntry = {
    session_id: "web_chat:abc123",
    date: "2026-03-02",
    digest: "Test digest content",
    topics: ["test", "memory"],
    original_message_count: 10,
    estimated_tokens: 50,
    created_at: 1709337600000L,
    source_file_path: "history/2026/03/02/test.jsonl",
  }
  plugin.save_short_term(entry)

  let retrieved = plugin.get_short_term_by_session("web_chat:abc123")
  assert_true(retrieved is Some(_))
  let r = retrieved.unwrap()
  assert_eq(r.session_id, "web_chat:abc123")
  assert_eq(r.digest, "Test digest content")
}

test "TracePlugin get_daily_memory" {
  let config = TracePluginConfig::default(name="test", db_path="/tmp/test.db")
  let plugin = TracePlugin::new(config)
  plugin.connect()

  // Add entries for different dates
  let entry1 : @interfaces.ShortTermMemoryEntry = {
    session_id: "session1",
    date: "2026-03-02",
    digest: "Entry 1",
    topics: [],
    original_message_count: 5,
    estimated_tokens: 25,
    created_at: 1709337600000L,
    source_file_path: "",
  }
  let entry2 : @interfaces.ShortTermMemoryEntry = {
    session_id: "session2",
    date: "2026-03-02",
    digest: "Entry 2",
    topics: [],
    original_message_count: 3,
    estimated_tokens: 15,
    created_at: 1709337700000L,
    source_file_path: "",
  }
  let entry3 : @interfaces.ShortTermMemoryEntry = {
    session_id: "session3",
    date: "2026-03-01",
    digest: "Entry 3",
    topics: [],
    original_message_count: 7,
    estimated_tokens: 35,
    created_at: 1709251200000L,
    source_file_path: "",
  }
  plugin.save_short_term(entry1)
  plugin.save_short_term(entry2)
  plugin.save_short_term(entry3)

  let march2 = plugin.get_daily_memory("2026-03-02")
  assert_eq(march2.length(), 2)

  let march1 = plugin.get_daily_memory("2026-03-01")
  assert_eq(march1.length(), 1)
}

test "TracePlugin delete_short_term" {
  let config = TracePluginConfig::default(name="test", db_path="/tmp/test.db")
  let plugin = TracePlugin::new(config)
  plugin.connect()

  let entry : @interfaces.ShortTermMemoryEntry = {
    session_id: "to_delete",
    date: "2026-03-02",
    digest: "Will be deleted",
    topics: [],
    original_message_count: 1,
    estimated_tokens: 5,
    created_at: 1709337600000L,
    source_file_path: "",
  }
  plugin.save_short_term(entry)
  assert_true(plugin.get_short_term_by_session("to_delete") is Some(_))

  let deleted = plugin.delete_short_term("to_delete")
  assert_true(deleted)
  assert_true(plugin.get_short_term_by_session("to_delete") is None)

  // Delete non-existent
  let not_found = plugin.delete_short_term("non_existent")
  assert_false(not_found)
}

test "TracePlugin save and get segment" {
  let config = TracePluginConfig::default(name="test", db_path="/tmp/test.db")
  let plugin = TracePlugin::new(config)
  plugin.connect()

  let segment : @interfaces.LongTermSegment = {
    id: "seg-001",
    content: "Compressed content",
    embedding: Some([0.1, 0.2, 0.3]),
    source_sessions: ["session1", "session2"],
    time_range_start: 1709251200000L,
    time_range_end: 1709337600000L,
    topics: ["test", "segment"],
    compression_ratio: 0.35,
    created_at: 1709337600000L,
  }
  plugin.save_segment(segment)

  let retrieved = plugin.get_segment("seg-001")
  assert_true(retrieved is Some(_))
  let r = retrieved.unwrap()
  assert_eq(r.id, "seg-001")
  assert_eq(r.content, "Compressed content")
}

test "TracePlugin search_segments_by_topic" {
  let config = TracePluginConfig::default(name="test", db_path="/tmp/test.db")
  let plugin = TracePlugin::new(config)
  plugin.connect()

  let seg1 : @interfaces.LongTermSegment = {
    id: "seg1",
    content: "MoonBit programming",
    embedding: None,
    source_sessions: [],
    time_range_start: 0L,
    time_range_end: 0L,
    topics: ["moonbit", "programming"],
    compression_ratio: 0.5,
    created_at: 0L,
  }
  let seg2 : @interfaces.LongTermSegment = {
    id: "seg2",
    content: "Rust programming",
    embedding: None,
    source_sessions: [],
    time_range_start: 0L,
    time_range_end: 0L,
    topics: ["rust", "programming"],
    compression_ratio: 0.5,
    created_at: 0L,
  }
  plugin.save_segment(seg1)
  plugin.save_segment(seg2)

  let moonbit_results = plugin.search_segments_by_topic(["moonbit"], 10)
  assert_eq(moonbit_results.length(), 1)
  assert_eq(moonbit_results[0].id, "seg1")

  let programming_results = plugin.search_segments_by_topic(["programming"], 10)
  assert_eq(programming_results.length(), 2)
}

test "TracePlugin search_segments_by_vector" {
  let config = TracePluginConfig::default(name="test", db_path="/tmp/test.db")
  let plugin = TracePlugin::new(config)
  plugin.connect()

  let seg1 : @interfaces.LongTermSegment = {
    id: "vec1",
    content: "Similar to query",
    embedding: Some([1.0, 0.0, 0.0]),
    source_sessions: [],
    time_range_start: 0L,
    time_range_end: 0L,
    topics: [],
    compression_ratio: 0.5,
    created_at: 0L,
  }
  let seg2 : @interfaces.LongTermSegment = {
    id: "vec2",
    content: "Different from query",
    embedding: Some([0.0, 1.0, 0.0]),
    source_sessions: [],
    time_range_start: 0L,
    time_range_end: 0L,
    topics: [],
    compression_ratio: 0.5,
    created_at: 0L,
  }
  plugin.save_segment(seg1)
  plugin.save_segment(seg2)

  let query = [1.0, 0.0, 0.0]
  let results = plugin.search_segments_by_vector(query, 10)
  assert_eq(results.length(), 2)
  // First result should be seg1 (exact match)
  let (first_seg, first_score) = results[0]
  assert_eq(first_seg.id, "vec1")
  assert_true(first_score > 0.99) // Should be very close to 1.0
}
