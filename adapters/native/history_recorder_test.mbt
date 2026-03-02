///|
/// NativeHistoryRecorder integration tests
/// Tests actual file I/O to verify history recording works

///|
/// Timestamp for 2026-03-01 21:00:00 UTC (in milliseconds)
fn test_timestamp() -> Int64 {
  1772366400000L
}

///|
test "NativeHistoryRecorder creates file on open_session" {
  // Use PID + counter for uniqueness
  let base_dir = "/tmp/mukuro_h1_\{c_getpid()}"
  let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
  let recorder = NativeHistoryRecorder::new(base_dir~)
  let timestamp = test_timestamp()
  let is_new = recorder.open_session(
    session_id="test_channel:test_chat_001",
    timestamp~,
  ) catch {
    e => {
      let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
      fail("open_session failed: \{e}")
    }
  }
  assert_true(is_new)
  recorder.close() catch {
    _ => ()
  }
  // Verify file was created
  let dir = "\{base_dir}/history/2026/03/01"
  let entries = native_list_dir_entries(dir)
  assert_true(entries.length() > 0)
  let has_jsonl = entries.iter().any(fn(e) { e.has_suffix(".jsonl") })
  assert_true(has_jsonl)
  let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
}

///|
test "NativeHistoryRecorder writes record to file" {
  let base_dir = "/tmp/mukuro_h2_\{c_getpid()}"
  let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
  let recorder = NativeHistoryRecorder::new(base_dir~)
  let timestamp = test_timestamp()
  let _ = recorder.open_session(
    session_id="test_channel:test_chat_002",
    timestamp~,
  ) catch {
    e => {
      let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
      fail("open_session failed: \{e}")
    }
  }
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id: "test_channel:test_chat_002",
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: { "content": "Hello, world!" },
  }
  recorder.record(record~) catch {
    e => fail("record failed: \{e}")
  }
  recorder.close() catch {
    _ => ()
  }
  // Read back the file content
  let dir = "\{base_dir}/history/2026/03/01"
  let entries = native_list_dir_entries(dir)
  assert_true(entries.length() > 0)
  let file_name = entries[0]
  let file_path = "\{dir}/\{file_name}"
  let content = native_read_file_text(file_path) catch {
    _ => fail("read failed")
  }
  assert_true(content.length() > 0)
  assert_true(content.contains("user_message"))
  assert_true(content.contains("Hello, world!"))
  let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
}

///|
test "NativeHistoryRecorder read-write round-trip via Reader" {
  let base_dir = "/tmp/mukuro_h3_\{c_getpid()}"
  let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
  let recorder = NativeHistoryRecorder::new(base_dir~)
  let timestamp = test_timestamp()
  let session_id = "web_chat:roundtrip_unique_123"
  let is_new = recorder.open_session(session_id~, timestamp~) catch {
    e => {
      let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
      fail("open_session failed: \{e}")
    }
  }
  assert_true(is_new)
  // Write SessionMeta
  let meta_record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: { "channel": "web_chat", "chat_id": "roundtrip_unique_123" },
  }
  recorder.record(record=meta_record) catch {
    e => fail("record failed: \{e}")
  }
  // Write UserMessage
  let user_record : @interfaces.HistoryRecord = {
    timestamp: timestamp + 1000L,
    session_id,
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: { "content": "Test message" },
  }
  recorder.record(record=user_record) catch {
    e => fail("record failed: \{e}")
  }
  recorder.close() catch {
    _ => ()
  }
  // Read back via NativeHistoryReader
  let reader = NativeHistoryReader::new(base_dir~)
  let records = reader.read_session(session_id~) catch {
    e => fail("read_session failed: \{e}")
  }
  assert_eq(records.length(), 2)
  assert_true(
    records[0].record_type is @interfaces.HistoryRecordType::SessionMeta,
  )
  assert_true(
    records[1].record_type is @interfaces.HistoryRecordType::UserMessage,
  )
  let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
}

///|
test "NativeHistoryRecorder raises NotInitialized when not open" {
  let recorder = NativeHistoryRecorder::new(base_dir="/tmp/mukuro_h4")
  let record : @interfaces.HistoryRecord = {
    timestamp: 0L,
    session_id: "test",
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: {},
  }
  let result : Result[Unit, @interfaces.HistoryError] = try? recorder.record(
    record~,
  )
  match result {
    Err(@interfaces.HistoryError::NotInitialized) => ()
    Err(e) => fail("expected NotInitialized, got \{e}")
    Ok(_) => fail("expected error, got success")
  }
}

///|
test "NativeHistoryRecorder flushes after each record" {
  let base_dir = "/tmp/mukuro_h5_\{c_getpid()}"
  let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
  let recorder = NativeHistoryRecorder::new(base_dir~)
  let timestamp = test_timestamp()
  let session_id = "flush_test:chat1"
  let _ = recorder.open_session(session_id~, timestamp~) catch {
    e => {
      let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
      fail("open_session failed: \{e}")
    }
  }
  // Write first record
  let record1 : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: { "content": "First" },
  }
  recorder.record(record=record1) catch {
    e => fail("record failed: \{e}")
  }
  // Read immediately (before close) to verify flush
  let dir = "\{base_dir}/history/2026/03/01"
  let entries = native_list_dir_entries(dir)
  assert_true(entries.length() > 0)
  let file_path = "\{dir}/\{entries[0]}"
  let content = native_read_file_text(file_path) catch {
    _ => fail("read failed")
  }
  assert_true(content.contains("First"))
  recorder.close() catch {
    _ => ()
  }
  let _ = c_system_bytes(string_to_utf8_cstring("rm -rf \{base_dir}"))
}
