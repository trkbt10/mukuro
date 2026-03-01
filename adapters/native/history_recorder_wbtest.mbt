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

test "parse_jsonl_records - multiple records" {
  let content =
    #|{"ts":1000,"sid":"test:1","type":"session_meta","payload":{}}
    #|{"ts":2000,"sid":"test:1","type":"user_message","payload":{"content":"hello"}}
    #|{"ts":3000,"sid":"test:1","type":"assistant_message","payload":{"content":"hi"}}
  let records : Array[@interfaces.HistoryRecord] = []
  parse_jsonl_records(content, records)
  assert_eq(records.length(), 3)
}

test "parse_jsonl_records - empty content" {
  let content = ""
  let records : Array[@interfaces.HistoryRecord] = []
  parse_jsonl_records(content, records)
  assert_eq(records.length(), 0)
}

test "parse_jsonl_records - content with empty lines" {
  let content =
    #|{"ts":1000,"sid":"test:1","type":"session_meta","payload":{}}
    #|
    #|{"ts":2000,"sid":"test:1","type":"user_message","payload":{"content":"hello"}}
  let records : Array[@interfaces.HistoryRecord] = []
  parse_jsonl_records(content, records)
  assert_eq(records.length(), 2)
}

test "parse_jsonl_records - actual file content format with unicode" {
  let content =
    #|{"ts":1772283205000,"sid":"web_chat:12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7","type":"session_meta","payload":{"model":"claude-sonnet-4"}}
    #|{"ts":1772283205000,"sid":"web_chat:12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7","type":"user_message","payload":{"content":"こういうこと？"}}
  let records : Array[@interfaces.HistoryRecord] = []
  parse_jsonl_records(content, records)
  assert_eq(records.length(), 2)
  assert_eq(records[0].session_id, "web_chat:12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7")
}

test "file_prefix matching" {
  let session_id = "web_chat:12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7"
  let (channel, chat_id) = @history.split_session_id(session_id)
  let safe_channel = @history.sanitize_path_segment(channel)
  let safe_chat_id = @history.sanitize_path_segment(chat_id)
  let file_prefix = "\{safe_channel}-\{safe_chat_id}-"

  assert_eq(file_prefix, "web_chat-12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7-")

  let filename = "web_chat-12e45cdf-fa19-4d7f-ac77-f8c5ff1138d7-1772283205.jsonl"
  assert_true(filename.has_prefix(file_prefix), msg="filename should have prefix")
  assert_true(filename.has_suffix(".jsonl"), msg="filename should have .jsonl suffix")
}
