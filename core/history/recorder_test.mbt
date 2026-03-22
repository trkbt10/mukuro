///|
test "record_type_to_string - all variants" {
  assert_eq(
    record_type_to_string(@interfaces.HistoryRecordType::SessionMeta),
    "session_meta",
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
    record_type_to_string(@interfaces.HistoryRecordType::Error),
    "error",
  )
}

///|
test "string_to_record_type - all variants" {
  assert_eq(
    string_to_record_type("session_meta"),
    Some(@interfaces.HistoryRecordType::SessionMeta),
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
test "record_to_json_line - session_meta roundtrip" {
  let record : @interfaces.HistoryRecord = {
    timestamp: 1709164800000L,
    session_id: "web_chat:abc123",
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::object({
      "model": Json::string("claude-sonnet-4-20250514"),
      "max_iterations": Json::number(10.0),
      "tools": Json::array([Json::string("shell"), Json::string("web")]),
      "tool_count": Json::number(2.0),
      "system_prompt": Json::string("You are a helpful assistant."),
    }),
  }
  let line = record_to_json_line(record)
  let parsed = parse_json_to_record(line)
  match parsed {
    Some(r) => {
      assert_eq(r.timestamp, 1709164800000L)
      assert_eq(r.session_id, "web_chat:abc123")
      assert_eq(r.record_type, @interfaces.HistoryRecordType::SessionMeta)
      match r.payload {
        Object(obj) => {
          match obj.get("model") {
            Some(String(s)) => assert_eq(s, "claude-sonnet-4-20250514")
            _ => fail("Expected model to be String")
          }
          match obj.get("tool_count") {
            Some(Number(n, ..)) => assert_eq(n, 2.0)
            _ => fail("Expected tool_count to be Number")
          }
        }
        _ => fail("Expected JSON object payload")
      }
    }
    None => fail("Failed to parse session_meta record")
  }
}

///|
test "record_to_json_line - user_message is valid JSON" {
  let record : @interfaces.HistoryRecord = {
    timestamp: 1709164800000L,
    session_id: "web_chat:abc123",
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({ "content": Json::string("hello world") }),
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
        Some(String(s)) => assert_eq(s, "user_message")
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
    #|{"ts":1709164800000,"sid":"web_chat:abc","type":"session_meta","payload":{"model":"claude-sonnet-4"}}
  match parse_json_to_record(line) {
    Some(record) => {
      assert_eq(record.timestamp, 1709164800000L)
      assert_eq(record.session_id, "web_chat:abc")
      assert_eq(record.record_type, @interfaces.HistoryRecordType::SessionMeta)
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
    history_dir_for_date("/test/base", 2026, 2, 28),
    "/test/base/history/2026/02/28",
  )
}

///|
test "history_dir_for_date - zero padding" {
  assert_eq(
    history_dir_for_date("/test/base", 2026, 1, 5),
    "/test/base/history/2026/01/05",
  )
}

///|
test "history_dir_for_date - december" {
  assert_eq(
    history_dir_for_date("/home/user/data", 2025, 12, 31),
    "/home/user/data/history/2025/12/31",
  )
}

///|
test "history_file_path - basic" {
  let path = history_file_path(
    "/test/base", "web_chat", "abc123", 2026, 2, 28, 1709164800L,
  )
  assert_eq(
    path, "/test/base/history/2026/02/28/web_chat-abc123-1709164800.jsonl",
  )
}

///|
test "history_file_path - sanitizes dangerous characters" {
  let path = history_file_path(
    "/test/base", "chan/nel", "../evil", 2026, 1, 1, 1000L,
  )
  assert_true(not(path.contains("../")))
  assert_true(path.has_suffix(".jsonl"))
}

///|
test "parse_int_string - valid numbers" {
  assert_eq(parse_int_string("123"), Some(123))
  assert_eq(parse_int_string("0"), Some(0))
  assert_eq(parse_int_string("2026"), Some(2026))
}

///|
test "parse_int_string - invalid input" {
  assert_eq(parse_int_string(""), None)
  assert_eq(parse_int_string("abc"), None)
  assert_eq(parse_int_string("12a"), None)
  assert_eq(parse_int_string("-5"), None)
}

///|
test "parse_history_filename - basic" {
  match parse_history_filename("web_chat-abc-1709164800.jsonl") {
    Some((channel, chat_id, epoch)) => {
      assert_eq(channel, "web_chat")
      assert_eq(chat_id, "abc")
      assert_eq(epoch, 1709164800L)
    }
    None => fail("Expected Some")
  }
}

///|
test "parse_history_filename - complex chat_id with dashes" {
  match parse_history_filename("discord-room-abc-def-1709164800.jsonl") {
    Some((channel, chat_id, epoch)) => {
      assert_eq(channel, "discord")
      assert_eq(chat_id, "room-abc-def")
      assert_eq(epoch, 1709164800L)
    }
    None => fail("Expected Some")
  }
}

///|
test "parse_history_filename - no extension returns None" {
  assert_true(parse_history_filename("web_chat-abc-1709164800.txt") is None)
  assert_true(parse_history_filename("web_chat-abc-1709164800") is None)
}

///|
test "parse_history_filename - missing dash returns None" {
  assert_true(parse_history_filename("nodash.jsonl") is None)
}

///|
test "parse_history_filename - invalid epoch returns None" {
  assert_true(parse_history_filename("web_chat-abc-notanumber.jsonl") is None)
}

///|
test "parse_history_filename - empty string returns None" {
  assert_true(parse_history_filename("") is None)
}

///|
test "NoOpHistoryRecorder - does nothing without error" {
  let recorder = @interfaces.NoOpHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder = recorder
  let is_new = hr.open_session(session_id="test", timestamp=1000L) catch {
    _ => fail("open_session should not fail")
  }
  assert_true(is_new)
  hr.record(record={
    timestamp: 1000L,
    session_id: "test",
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload: Json::null(),
  }) catch {
    _ => fail("record should not fail")
  }
  hr.close() catch {
    _ => fail("close should not fail")
  }
}

///|
test "NoOpHistoryReader - returns empty arrays" {
  let reader = @interfaces.NoOpHistoryReader::new()
  let hr : &@interfaces.HistoryReader = reader
  let records = hr.read_session(session_id="test") catch {
    _ => fail("read_session should not fail")
  }
  assert_eq(records.length(), 0)
  let sessions = hr.list_sessions(year=2026, month=2, day=28) catch {
    _ => fail("list_sessions should not fail")
  }
  assert_eq(sessions.length(), 0)
  let dates = hr.list_dates() catch { _ => fail("list_dates should not fail") }
  assert_eq(dates.length(), 0)
}
