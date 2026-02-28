///|
test "record_type_to_string - all variants" {
  assert_eq(
    record_type_to_string(@interfaces.HistoryRecordType::SessionStart),
    "session_start",
  )
  assert_eq(
    record_type_to_string(@interfaces.HistoryRecordType::UserMessage),
    "user_message",
  )
  assert_eq(
    record_type_to_string(@interfaces.HistoryRecordType::AssistantMessage),
    "assistant_message",
  )
  assert_eq(
    record_type_to_string(@interfaces.HistoryRecordType::ToolCall),
    "tool_call",
  )
  assert_eq(
    record_type_to_string(@interfaces.HistoryRecordType::ToolResult),
    "tool_result",
  )
  assert_eq(
    record_type_to_string(@interfaces.HistoryRecordType::SessionEnd),
    "session_end",
  )
  assert_eq(
    record_type_to_string(@interfaces.HistoryRecordType::Error),
    "error",
  )
}

///|
test "string_to_record_type - all variants" {
  assert_eq(
    string_to_record_type("session_start"),
    Some(@interfaces.HistoryRecordType::SessionStart),
  )
  assert_eq(
    string_to_record_type("user_message"),
    Some(@interfaces.HistoryRecordType::UserMessage),
  )
  assert_eq(
    string_to_record_type("assistant_message"),
    Some(@interfaces.HistoryRecordType::AssistantMessage),
  )
  assert_eq(
    string_to_record_type("tool_call"),
    Some(@interfaces.HistoryRecordType::ToolCall),
  )
  assert_eq(
    string_to_record_type("tool_result"),
    Some(@interfaces.HistoryRecordType::ToolResult),
  )
  assert_eq(
    string_to_record_type("session_end"),
    Some(@interfaces.HistoryRecordType::SessionEnd),
  )
  assert_eq(
    string_to_record_type("error"),
    Some(@interfaces.HistoryRecordType::Error),
  )
}

///|
test "string_to_record_type - unknown returns None" {
  assert_eq(string_to_record_type("unknown"), None)
  assert_eq(string_to_record_type(""), None)
}

///|
test "record_to_json_line - session_start is valid JSON" {
  let record : @interfaces.HistoryRecord = {
    timestamp: 1709164800000L,
    session_id: "web_chat:abc123",
    record_type: @interfaces.HistoryRecordType::SessionStart,
    payload: Json::object({
      "channel": Json::string("web_chat"),
      "chat_id": Json::string("abc123"),
    }),
  }
  let line = record_to_json_line(record)
  let json : Json = @json.parse(line) catch {
    _ => fail("Failed to parse JSON")
  }
  match json {
    Object(obj) => {
      match obj.get("ts") {
        Some(Number(_, ..)) => ()
        _ => fail("Expected ts to be Number")
      }
      match obj.get("sid") {
        Some(String(s)) => assert_eq(s, "web_chat:abc123")
        _ => fail("Expected sid to be String")
      }
      match obj.get("type") {
        Some(String(s)) => assert_eq(s, "session_start")
        _ => fail("Expected type to be String")
      }
    }
    _ => fail("Expected JSON object")
  }
}

///|
test "record_to_json_line - tool_call with arguments" {
  let record : @interfaces.HistoryRecord = {
    timestamp: 1709164803000L,
    session_id: "web_chat:abc123",
    record_type: @interfaces.HistoryRecordType::ToolCall,
    payload: Json::object({
      "call_id": Json::string("tc_1"),
      "tool_name": Json::string("search"),
      "arguments": Json::object({ "query": Json::string("hello world") }),
    }),
  }
  let line = record_to_json_line(record)
  let json : Json = @json.parse(line) catch {
    _ => fail("Failed to parse JSON")
  }
  match json {
    Object(obj) => {
      match obj.get("type") {
        Some(String(s)) => assert_eq(s, "tool_call")
        _ => fail("Expected type to be String")
      }
      match obj.get("payload") {
        Some(Object(payload)) =>
          match payload.get("tool_name") {
            Some(String(s)) => assert_eq(s, "search")
            _ => fail("Expected tool_name to be String")
          }
        _ => fail("Expected payload object")
      }
    }
    _ => fail("Expected JSON object")
  }
}

///|
test "record_to_json_line - escapes special characters" {
  let record : @interfaces.HistoryRecord = {
    timestamp: 1000L,
    session_id: "chan:\"id\nnewline",
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::string("test"),
  }
  let line = record_to_json_line(record)
  let json : Json = @json.parse(line) catch {
    _ => fail("Failed to parse JSON with special chars")
  }
  match json {
    Object(obj) =>
      match obj.get("sid") {
        Some(String(s)) => assert_eq(s, "chan:\"id\nnewline")
        _ => fail("Expected sid string")
      }
    _ => fail("Expected JSON object")
  }
}

///|
test "parse_json_to_record - valid line" {
  let line =
    #|{"ts":1709164800000,"sid":"web_chat:abc","type":"session_start","payload":{"channel":"web_chat"}}
  match parse_json_to_record(line) {
    Some(record) => {
      assert_eq(record.timestamp, 1709164800000L)
      assert_eq(record.session_id, "web_chat:abc")
      assert_eq(record.record_type, @interfaces.HistoryRecordType::SessionStart)
    }
    None => fail("Expected Some record")
  }
}

///|
test "parse_json_to_record - invalid JSON returns None" {
  assert_true(parse_json_to_record("not json") is None)
  assert_true(parse_json_to_record("") is None)
  assert_true(parse_json_to_record("[]") is None)
}

///|
test "parse_json_to_record - missing fields returns None" {
  let no_type =
    #|{"ts":1000,"sid":"x"}
  assert_true(parse_json_to_record(no_type) is None)
  let no_ts =
    #|{"sid":"x","type":"error","payload":null}
  assert_true(parse_json_to_record(no_ts) is None)
}

///|
test "record_to_json_line then parse roundtrip" {
  let original : @interfaces.HistoryRecord = {
    timestamp: 1709168400000L,
    session_id: "discord:def456",
    record_type: @interfaces.HistoryRecordType::ToolResult,
    payload: Json::object({
      "call_id": Json::string("tc_99"),
      "status": Json::string("success"),
      "content": Json::string("Found 3 results"),
    }),
  }
  let line = record_to_json_line(original)
  match parse_json_to_record(line) {
    Some(parsed) => {
      assert_eq(parsed.timestamp, original.timestamp)
      assert_eq(parsed.session_id, original.session_id)
      assert_eq(parsed.record_type, original.record_type)
    }
    None => fail("Roundtrip failed: parse returned None")
  }
}

///|
test "history_dir_for_date - basic" {
  assert_eq(
    history_dir_for_date(".mukuro", 2026, 2, 28),
    ".mukuro/history/2026/02/28",
  )
}

///|
test "history_dir_for_date - zero padding" {
  assert_eq(
    history_dir_for_date(".mukuro", 2026, 1, 5),
    ".mukuro/history/2026/01/05",
  )
}

///|
test "history_dir_for_date - december" {
  assert_eq(
    history_dir_for_date("/home/user/.mukuro", 2025, 12, 31),
    "/home/user/.mukuro/history/2025/12/31",
  )
}

///|
test "history_file_path - basic" {
  let path = history_file_path(
    ".mukuro", "web_chat", "abc123", 2026, 2, 28, 1709164800L,
  )
  assert_eq(path, ".mukuro/history/2026/02/28/web_chat-abc123-1709164800.jsonl")
}

///|
test "history_file_path - sanitizes dangerous characters" {
  let path = history_file_path(
    ".mukuro", "chan/nel", "../evil", 2026, 1, 1, 1000L,
  )
  assert_true(not(path.contains("../")))
  assert_true(path.has_suffix(".jsonl"))
}

///|
test "NoOpHistoryRecorder - does nothing without error" {
  let recorder = @interfaces.NoOpHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder = recorder
  hr.init_session(session_id="test", timestamp=1000L) catch {
    _ => fail("init_session should not fail")
  }
  hr.record(record={
    timestamp: 1000L,
    session_id: "test",
    record_type: @interfaces.HistoryRecordType::SessionStart,
    payload: Json::null(),
  }) catch {
    _ => fail("record should not fail")
  }
  hr.flush() catch {
    _ => fail("flush should not fail")
  }
}
