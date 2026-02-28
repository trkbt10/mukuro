///|
/// history_bridge のフラッシュ動作テスト

///|
/// テスト用 HistoryRecorder: 記録内容とフラッシュ状態を追跡する
struct SpyHistoryRecorder {
  records : Array[@interfaces.HistoryRecord]
  mut init_count : Int
  mut flush_count : Int
  mut session_id : String
  mut fail_on_record : Bool
}

///|
fn SpyHistoryRecorder::new() -> SpyHistoryRecorder {
  {
    records: [],
    init_count: 0,
    flush_count: 0,
    session_id: "",
    fail_on_record: false,
  }
}

///|
impl @interfaces.HistoryRecorder for SpyHistoryRecorder with init_session(
  self,
  session_id~,
  timestamp~,
) -> Unit raise @interfaces.HistoryError {
  ignore(timestamp)
  self.init_count += 1
  self.session_id = session_id
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
impl @interfaces.HistoryRecorder for SpyHistoryRecorder with flush(self) -> Unit raise @interfaces.HistoryError {
  self.flush_count += 1
}

///|
test "safe_init_session calls init_session" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  safe_init_session(hr, "test:chat1", 1000L)
  inspect(spy.init_count, content="1")
  inspect(spy.session_id, content="test:chat1")
}

///|
test "safe_init_session with None recorder does nothing" {
  let hr : &@interfaces.HistoryRecorder? = None
  safe_init_session(hr, "test:chat1", 1000L)
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
test "safe_flush increments flush count" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  safe_flush(hr)
  inspect(spy.flush_count, content="1")
}

///|
test "safe_flush with None recorder does nothing" {
  let hr : &@interfaces.HistoryRecorder? = None
  safe_flush(hr)
  // should not panic
}

///|
test "record_session_start writes SessionStart record" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  record_session_start(hr, clk, 5000L, "test:c1", "web_chat", "c1")
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="SessionStart")
  inspect(spy.records[0].timestamp, content="5000")
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
test "record_session_end writes SessionEnd and flushes" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  record_session_end(hr, clk, 5000L, "test:c1", "completed", 3)
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="SessionEnd")
  // flush must be called after session end
  inspect(spy.flush_count, content="1")
}

///|
test "record_error writes Error and flushes" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  record_error(hr, clk, 5000L, "test:c1", "something went wrong")
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="Error")
  // flush must be called after error
  inspect(spy.flush_count, content="1")
}

///|
test "record_rate_limit_error writes Error and flushes" {
  let spy = SpyHistoryRecorder::new()
  let hr : &@interfaces.HistoryRecorder? = Some(spy)
  let clk : &@interfaces.Clock? = None
  record_rate_limit_error(hr, clk, 5000L, "test:c1", 60)
  inspect(spy.records.length(), content="1")
  inspect(spy.records[0].record_type, content="Error")
  inspect(spy.flush_count, content="1")
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
  // Session A: init + SessionStart + UserMessage
  safe_init_session(hr_a, "web_chat:session_a", 1000L)
  record_session_start(hr_a, clk, 1000L, "web_chat:session_a", "web_chat", "session_a")
  record_user_message(hr_a, clk, 1000L, "web_chat:session_a", "hello from A")
  // Session B: init + SessionStart + UserMessage (should not affect A)
  safe_init_session(hr_b, "web_chat:session_b", 2000L)
  record_session_start(hr_b, clk, 2000L, "web_chat:session_b", "web_chat", "session_b")
  record_user_message(hr_b, clk, 2000L, "web_chat:session_b", "hello from B")
  // Session A: AssistantMessage + SessionEnd
  record_assistant_message(hr_a, clk, 3000L, "web_chat:session_a", "reply to A")
  record_session_end(hr_a, clk, 3000L, "web_chat:session_a", "completed", 1)
  // Session B: AssistantMessage + SessionEnd
  record_assistant_message(hr_b, clk, 4000L, "web_chat:session_b", "reply to B")
  record_session_end(hr_b, clk, 4000L, "web_chat:session_b", "completed", 1)
  // A has 4 records, B has 4 records — no cross-contamination
  inspect(spy_a.records.length(), content="4")
  inspect(spy_b.records.length(), content="4")
  inspect(spy_a.init_count, content="1")
  inspect(spy_b.init_count, content="1")
  inspect(spy_a.flush_count, content="1")
  inspect(spy_b.flush_count, content="1")
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
  // init → SessionStart → UserMessage → ToolCall → ToolResult → AssistantMessage → SessionEnd
  safe_init_session(hr, sid, ts)
  record_session_start(hr, clk, ts, sid, "web_chat", "lifecycle_test")
  record_user_message(hr, clk, ts, sid, "what time is it?")
  record_tool_call(
    hr,
    clk,
    ts,
    sid,
    "call_1",
    "get_time",
    Json::object({}),
  )
  record_tool_result(
    hr,
    clk,
    ts,
    sid,
    "call_1",
    @types.ToolResult::Success(content="14:30"),
  )
  record_assistant_message(hr, clk, ts, sid, "It is 14:30")
  record_session_end(hr, clk, ts, sid, "completed", 2)
  // 6 records: SessionStart, UserMessage, ToolCall, ToolResult, AssistantMessage, SessionEnd
  inspect(spy.records.length(), content="6")
  inspect(spy.records[0].record_type, content="SessionStart")
  inspect(spy.records[1].record_type, content="UserMessage")
  inspect(spy.records[2].record_type, content="ToolCall")
  inspect(spy.records[3].record_type, content="ToolResult")
  inspect(spy.records[4].record_type, content="AssistantMessage")
  inspect(spy.records[5].record_type, content="SessionEnd")
  inspect(spy.flush_count, content="1")
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
