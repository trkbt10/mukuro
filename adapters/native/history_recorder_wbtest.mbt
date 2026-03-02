///|
/// NativeHistoryRecorder / NativeHistoryReader のテスト
test "parse_jsonl_records - single record" {
  let content =
    #|{"ts":1772283205000,"sid":"web_chat:abc","type":"session_meta","payload":{"model":"claude-sonnet-4"}}
  let records : Array[@interfaces.HistoryRecord] = []
  parse_jsonl_records(content, records)
  assert_eq(records.length(), 1)
  assert_eq(records[0].session_id, "web_chat:abc")
}

///|
test "parse_jsonl_records - multiple records" {
  let content =
    #|{"ts":1000,"sid":"test:1","type":"session_meta","payload":{}}
    #|{"ts":2000,"sid":"test:1","type":"user_message","payload":{"content":"hello"}}
    #|{"ts":3000,"sid":"test:1","type":"assistant_message","payload":{"content":"hi"}}
  let records : Array[@interfaces.HistoryRecord] = []
  parse_jsonl_records(content, records)
  assert_eq(records.length(), 3)
}

///|
test "parse_jsonl_records - empty content" {
  let content = ""
  let records : Array[@interfaces.HistoryRecord] = []
  parse_jsonl_records(content, records)
  assert_eq(records.length(), 0)
}

///|
test "parse_jsonl_records - content with empty lines" {
  let content =
    #|{"ts":1000,"sid":"test:1","type":"session_meta","payload":{}}
    #|
    #|{"ts":2000,"sid":"test:1","type":"user_message","payload":{"content":"hello"}}
  let records : Array[@interfaces.HistoryRecord] = []
  parse_jsonl_records(content, records)
  assert_eq(records.length(), 2)
}

///|
test "parse_jsonl_records - actual file content format with unicode" {
  let content =
    #|{"ts":1772283205000,"sid":"web_chat:12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7","type":"session_meta","payload":{"model":"claude-sonnet-4"}}
    #|{"ts":1772283205000,"sid":"web_chat:12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7","type":"user_message","payload":{"content":"こういうこと？"}}
  let records : Array[@interfaces.HistoryRecord] = []
  parse_jsonl_records(content, records)
  assert_eq(records.length(), 2)
  assert_eq(
    records[0].session_id,
    "web_chat:12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7",
  )
}

///|
test "file_prefix matching" {
  let session_id = "web_chat:12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7"
  let (channel, chat_id) = @history.split_session_id(session_id)
  let safe_channel = @history.sanitize_path_segment(channel)
  let safe_chat_id = @history.sanitize_path_segment(chat_id)
  let file_prefix = "\{safe_channel}-\{safe_chat_id}-"

  assert_eq(file_prefix, "web_chat-12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7-")

  let filename = "web_chat-12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7-1772283205.jsonl"
  assert_true(
    filename.has_prefix(file_prefix),
    msg="filename should have prefix",
  )
  assert_true(
    filename.has_suffix(".jsonl"),
    msg="filename should have .jsonl suffix",
  )
}

// ============================================================
// NativeHistoryRecorder 統合テスト
// ============================================================

///|
test "NativeHistoryRecorder - open_session creates file and allows recording" {
  // テスト用一時ディレクトリ
  let base_dir = "/tmp/mukuro_test_history_\{c_time()}"
  let recorder = NativeHistoryRecorder::new(base_dir~)
  let session_id = "test:integration_test_1"
  let timestamp = 1772330000000L // 2026-03-01 あたり

  // open_session
  let is_new = recorder.open_session(session_id~, timestamp~) catch {
    _ => fail("open_session should not fail")
  }
  assert_true(is_new, msg="First open should be new session")

  // record
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "model": Json::string("test-model") }),
  }
  recorder.record(record~) catch {
    _ => fail("record should not fail")
  }

  // record another
  let record2 : @interfaces.HistoryRecord = {
    timestamp: timestamp + 1000L,
    session_id,
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({ "content": Json::string("hello") }),
  }
  recorder.record(record=record2) catch {
    _ => fail("record2 should not fail")
  }

  // close
  recorder.close() catch {
    _ => fail("close should not fail")
  }

  // verify file exists and has content
  let reader = NativeHistoryReader::new(base_dir~)
  let records = reader.read_session(session_id~) catch {
    _ => fail("read_session should not fail")
  }
  assert_eq(records.length(), 2)
  assert_eq(records[0].record_type, @interfaces.HistoryRecordType::SessionMeta)
  assert_eq(records[1].record_type, @interfaces.HistoryRecordType::UserMessage)
}

///|
test "NativeHistoryRecorder - record fails if open_session not called" {
  let base_dir = "/tmp/mukuro_test_history_\{c_time()}_2"
  let recorder = NativeHistoryRecorder::new(base_dir~)

  let record : @interfaces.HistoryRecord = {
    timestamp: 1000L,
    session_id: "test:no_open",
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({ "content": Json::string("hello") }),
  }

  // record without open_session should fail
  let result = try {
    recorder.record(record~)
    Ok(())
  } catch {
    @interfaces.HistoryError::IoError(_) => Err("IoError")
    _ => Err("other")
  }
  assert_true(result is Err(_), msg="record without open_session should fail")
}

///|
test "NativeHistoryRecorder via trait object - state persists" {
  // trait object として使用した場合に mutable 状態が保持されるかテスト
  let base_dir = "/tmp/mukuro_test_history_\{c_time()}_3"
  let recorder = NativeHistoryRecorder::new(base_dir~)
  let hr : &@interfaces.HistoryRecorder = recorder
  let session_id = "test:trait_object_test"
  let timestamp = 1772330000000L

  // open_session via trait object
  let is_new = hr.open_session(session_id~, timestamp~) catch {
    _ => fail("open_session should not fail")
  }
  assert_true(is_new, msg="First open should be new session")

  // record via trait object
  let record : @interfaces.HistoryRecord = {
    timestamp,
    session_id,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({ "test": Json::string("value") }),
  }
  hr.record(record~) catch {
    _ => fail("record should not fail")
  }

  // close via trait object
  hr.close() catch {
    _ => fail("close should not fail")
  }

  // verify
  let reader = NativeHistoryReader::new(base_dir~)
  let records = reader.read_session(session_id~) catch {
    _ => fail("read_session should not fail")
  }
  assert_eq(records.length(), 1)
}
