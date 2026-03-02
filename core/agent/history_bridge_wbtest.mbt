///|
/// history_bridge のテスト

///|
/// テスト用 HistoryRecorder: 記録内容と状態を追跡する
struct SpyHistoryRecorder {
  records : Array[@interfaces.HistoryRecord]
  mut open_count : Int
  mut close_count : Int
  mut session_id : String
  mut fail_on_record : Bool
  /// open_session の戻り値を制御
  mut is_new_session : Bool
}

///|
fn SpyHistoryRecorder::new() -> SpyHistoryRecorder {
  {
    records: [],
    open_count: 0,
    close_count: 0,
    session_id: "",
    fail_on_record: false,
    is_new_session: true,
  }
}

///|
impl @interfaces.HistoryRecorder for SpyHistoryRecorder with open_session(
  self,
  session_id~,
  timestamp~,
) -> Bool raise @interfaces.HistoryError {
  ignore(timestamp)
  self.open_count += 1
  self.session_id = session_id
  self.is_new_session
}

///|
impl @interfaces.HistoryRecorder for SpyHistoryRecorder with record(
  self,
  record~,
) -> Unit raise @interfaces.HistoryError {
  if self.fail_on_record {
    raise @interfaces.HistoryError::IoError("simulated write failure")
  }
  self.records.push(record)
}

///|
impl @interfaces.HistoryRecorder for SpyHistoryRecorder with close(self) -> Unit raise @interfaces.HistoryError {
  self.close_count += 1
}

///|
test "safe_open_session returns is_new_session true" {
  let spy = SpyHistoryRecorder::new()
  spy.is_new_session = true
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let result = safe_open_session(hr, "test:chat1", 1000L)
  inspect(result, content="Some(true)")
  inspect(spy.open_count, content="1")
  inspect(spy.session_id, content="test:chat1")
}

///|
test "safe_open_session returns is_new_session false for continuing session" {
  let spy = SpyHistoryRecorder::new()
  spy.is_new_session = false
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let result = safe_open_session(hr, "test:chat1", 1000L)
  inspect(result, content="Some(false)")
  inspect(spy.open_count, content="1")
}

///|
test "safe_open_session with None recorder returns None" {
  let hr : &@interfaces.HistoryRecorder? = None
  let result = safe_open_session(hr, "test:chat1", 1000L)
  inspect(result, content="None")
}

///|
test "safe_close calls close" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  safe_close(hr)
  inspect(spy.close_count, content="1")
}

///|
test "safe_close with None recorder does nothing" {
  let hr : &@interfaces.HistoryRecorder? = None
  safe_close(hr)
  // should not panic
}

///|
test "safe_record appends to recorder" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let record : @interfaces.HistoryRecord = {
    timestamp: 1000L,
    session_id: "test:chat1",
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({ "content": Json::string("hello") }),
  }
  safe_record(hr, record)
  inspect(spy.records.length(), content="1")
}

///|
test "safe_record swallows errors silently" {
  let spy = SpyHistoryRecorder::new()
  spy.fail_on_record = true
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let record : @interfaces.HistoryRecord = {
    timestamp: 1000L,
    session_id: "test:chat1",
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({ "content": Json::string("hello") }),
  }
  // should not panic even though recording fails
  safe_record(hr, record)
  inspect(spy.records.length(), content="0")
}

///|
test "record_user_message writes UserMessage record" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  record_user_message(hr, clk, 5000L, "test:c1", "hello world")
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="UserMessage")
}

///|
test "record_assistant_message writes AssistantMessage record" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  record_assistant_message(hr, clk, 5000L, "test:c1", "I can help")
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="AssistantMessage")
}

///|
test "record_tool_call writes ToolCall record" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  record_tool_call(
    hr,
    clk,
    5000L,
    "test:c1",
    "call_1",
    "read_file",
    Json::object({ "path": Json::string("/tmp/a") }),
  )
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="ToolCall")
}

///|
test "record_tool_result writes ToolResult record" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  record_tool_result(
    hr,
    clk,
    5000L,
    "test:c1",
    "call_1",
    @types.ToolResult::Success(content="file content"),
  )
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="ToolResult")
}

///|
test "record_error writes Error record" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  record_error(hr, clk, 5000L, "test:c1", "something went wrong")
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="Error")
  // close is NOT called by record_error — session lifecycle managed externally
  inspect(spy.close_count, content="0")
}

///|
test "independent recorders do not interfere with each other" {
  // 並行セッション安全性の検証:
  // 独立した SpyHistoryRecorder インスタンスは相互に影響しない
  let spy_a = SpyHistoryRecorder::new()
  let spy_b = SpyHistoryRecorder::new()
  let hr_a : &@interfaces.HistoryRecorder? = Some(spy_a)
  let hr_b : &@interfaces.HistoryRecorder? = Some(spy_b)
  let clk : &@interfaces.Clock? = None
  // Session A: open → UserMessage → AssistantMessage → close
  let _ = safe_open_session(hr_a, "web_chat:session_a", 1000L)
  record_user_message(hr_a, clk, 1000L, "web_chat:session_a", "hello from A")
  // Session B: open → UserMessage → AssistantMessage → close
  let _ = safe_open_session(hr_b, "web_chat:session_b", 2000L)
  record_user_message(hr_b, clk, 2000L, "web_chat:session_b", "hello from B")
  // Session A: AssistantMessage + close
  record_assistant_message(hr_a, clk, 3000L, "web_chat:session_a", "reply to A")
  safe_close(hr_a)
  // Session B: AssistantMessage + close
  record_assistant_message(hr_b, clk, 4000L, "web_chat:session_b", "reply to B")
  safe_close(hr_b)
  // A has 2 records, B has 2 records — no cross-contamination
  inspect(spy_a.records.length(), content="2")
  inspect(spy_b.records.length(), content="2")
  inspect(spy_a.open_count, content="1")
  inspect(spy_b.open_count, content="1")
  inspect(spy_a.close_count, content="1")
  inspect(spy_b.close_count, content="1")
  // Verify session IDs are correct
  inspect(spy_a.session_id, content="web_chat:session_a")
  inspect(spy_b.session_id, content="web_chat:session_b")
}

///|
test "full session lifecycle records all events" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  let sid = "web_chat:lifecycle_test"
  let ts = 10000L
  // open → SessionMeta → UserMessage → ToolCall → ToolResult → AssistantMessage → close
  let is_new = safe_open_session(hr, sid, ts)
  inspect(is_new, content="Some(true)")
  record_session_meta(
    hr,
    clk,
    ts,
    sid,
    Json::object({ "model": Json::string("claude-sonnet-4") }),
  )
  record_user_message(hr, clk, ts, sid, "what time is it?")
  record_tool_call(hr, clk, ts, sid, "call_1", "get_time", Json::object({}))
  record_tool_result(
    hr,
    clk,
    ts,
    sid,
    "call_1",
    @types.ToolResult::Success(content="14:30"),
  )
  record_assistant_message(hr, clk, ts, sid, "It is 14:30")
  safe_close(hr)
  // 5 records: SessionMeta, UserMessage, ToolCall, ToolResult, AssistantMessage
  inspect(spy.records.length(), content="5")
  inspect(spy.records[0].record_type, content="SessionMeta")
  inspect(spy.records[1].record_type, content="UserMessage")
  inspect(spy.records[2].record_type, content="ToolCall")
  inspect(spy.records[3].record_type, content="ToolResult")
  inspect(spy.records[4].record_type, content="AssistantMessage")
  inspect(spy.close_count, content="1")
}

///|
test "record_session_meta writes SessionMeta record" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  let payload = Json::object({
    "model": Json::string("claude-sonnet-4-20250514"),
    "max_iterations": Json::number(10.0),
    "tools": Json::array([Json::string("shell"), Json::string("web")]),
  })
  record_session_meta(hr, clk, 5000L, "test:c1", payload)
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="SessionMeta")
  inspect(spy.records[0].timestamp, content="5000")
  inspect(spy.records[0].session_id, content="test:c1")
  match spy.records[0].payload {
    Object(obj) =>
      match obj.get("model") {
        Some(String(s)) => inspect(s, content="claude-sonnet-4-20250514")
        _ => fail("Expected model to be String")
      }
    _ => fail("Expected JSON object payload")
  }
}

///|
test "record_session_meta with None recorder does nothing" {
  let hr : &@interfaces.HistoryRecorder? = None
  let clk : &@interfaces.Clock? = None
  record_session_meta(hr, clk, 5000L, "test:c1", Json::object({}))
  // should not panic
}
