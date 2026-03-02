///|
/// Memory Types Unit Tests
test "short_term_entry_to_json roundtrip" {
  let entry : @interfaces.ShortTermMemoryEntry = {
    session_id: "web_chat:abc123",
    date: "2026-03-02",
    digest: "ユーザーはMoonBitでメモリプラグインを実装した",
    topics: ["MoonBit", "memory", "plugin"],
    original_message_count: 15,
    estimated_tokens: 120,
    created_at: 1709337600000L,
    source_file_path: "history/2026/03/02/web_chat-abc123-1709337600.jsonl",
  }
  let json = short_term_entry_to_json(entry)
  let restored = short_term_entry_from_json(json)
  assert_true(restored is Some(_))
  let r = restored.unwrap()
  assert_eq(r.session_id, entry.session_id)
  assert_eq(r.date, entry.date)
  assert_eq(r.digest, entry.digest)
  assert_eq(r.topics.length(), entry.topics.length())
  assert_eq(r.original_message_count, entry.original_message_count)
  assert_eq(r.estimated_tokens, entry.estimated_tokens)
  assert_eq(r.created_at, entry.created_at)
  assert_eq(r.source_file_path, entry.source_file_path)
}

///|
test "short_term_entry_from_json invalid json returns None" {
  let invalid = Json::string("not an object")
  let result = short_term_entry_from_json(invalid)
  assert_true(result is None)
}

///|
test "short_term_entry_from_json missing required field returns None" {
  let json = Json::object({ "date": Json::string("2026-03-02") })
  let result = short_term_entry_from_json(json)
  assert_true(result is None)
}

///|
test "segment_to_json roundtrip with embedding" {
  let segment : @interfaces.LongTermSegment = {
    id: "seg-001",
    content: "圧縮されたコンテンツ",
    embedding: Some([0.1, 0.2, 0.3, 0.4]),
    source_sessions: ["web_chat:abc123", "web_chat:def456"],
    time_range_start: 1709251200000L,
    time_range_end: 1709337600000L,
    topics: ["MoonBit", "memory"],
    compression_ratio: 0.35,
    created_at: 1709337600000L,
  }
  let json = segment_to_json(segment)
  let restored = segment_from_json(json)
  assert_true(restored is Some(_))
  let r = restored.unwrap()
  assert_eq(r.id, segment.id)
  assert_eq(r.content, segment.content)
  assert_true(r.embedding is Some(_))
  assert_eq(r.embedding.unwrap().length(), 4)
  assert_eq(r.source_sessions.length(), 2)
  assert_eq(r.time_range_start, segment.time_range_start)
  assert_eq(r.time_range_end, segment.time_range_end)
}

///|
test "segment_to_json roundtrip without embedding" {
  let segment : @interfaces.LongTermSegment = {
    id: "seg-002",
    content: "埋め込みなしセグメント",
    embedding: None,
    source_sessions: ["cli:main"],
    time_range_start: 1709251200000L,
    time_range_end: 1709337600000L,
    topics: [],
    compression_ratio: 0.5,
    created_at: 1709337600000L,
  }
  let json = segment_to_json(segment)
  let restored = segment_from_json(json)
  assert_true(restored is Some(_))
  let r = restored.unwrap()
  assert_true(r.embedding is None)
}

///|
test "segment_from_json invalid json returns None" {
  let invalid = Json::array([])
  let result = segment_from_json(invalid)
  assert_true(result is None)
}

///|
test "SegmentationConfig default values" {
  let cfg = SegmentationConfig::default()
  assert_eq(cfg.target_chunk_size, 500)
  assert_eq(cfg.min_chunk_size, 100)
  assert_eq(cfg.max_chunk_size, 2000)
  assert_true(cfg.ncd_threshold > 0.3 && cfg.ncd_threshold < 0.5)
  assert_eq(cfg.window_size, 3)
  assert_false(cfg.adaptive)
}

///|
test "BatchDigestConfig default values" {
  let cfg = BatchDigestConfig::default()
  assert_eq(cfg.batch_threshold, 300)
  assert_eq(cfg.max_batch_size, 5)
  assert_eq(cfg.max_batch_chars, 1500)
}

///|
test "IterativeDigestConfig default values" {
  let cfg = IterativeDigestConfig::default()
  assert_true(cfg.target_ratio > 0.2 && cfg.target_ratio < 0.4)
  assert_eq(cfg.max_iterations, 5)
  assert_true(
    cfg.convergence_threshold > 0.0 && cfg.convergence_threshold < 0.1,
  )
}

///|
test "estimate_tokens empty string" {
  let result = estimate_tokens("")
  assert_eq(result, 0)
}

///|
test "estimate_tokens short text" {
  let result = estimate_tokens("Hello")
  // 5 chars / 2 = 2.5 → 3 (rounded up)
  assert_true(result >= 2 && result <= 3)
}

///|
test "estimate_tokens japanese text" {
  let result = estimate_tokens("こんにちは世界")
  // 7 chars / 2 = 3.5 → 4
  assert_true(result >= 3 && result <= 4)
}

///|
test "estimate_tokens long text" {
  let text = "This is a longer piece of text that should have more tokens."
  let result = estimate_tokens(text)
  // ~60 chars / 2 = ~30 tokens
  assert_true(result > 20 && result < 40)
}
