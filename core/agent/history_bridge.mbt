///|
/// エージェントループ用の履歴記録ヘルパー
/// sync/async 両ループで共有される記録ロジックを集約

///|
/// 現在時刻を取得する（Clock があればそれを使用、なければ fallback）
fn get_event_timestamp(clock : &@interfaces.Clock?, fallback : Int64) -> Int64 {
  match clock {
    Some(c) => c.now_ms()
    None => fallback
  }
}

///|
/// 履歴レコーダーを安全に初期化する（失敗は無視）
fn safe_init_session(
  recorder : &@interfaces.HistoryRecorder?,
  session_id : String,
  timestamp : Int64,
) -> Unit {
  match recorder {
    Some(r) => r.init_session(session_id~, timestamp~) catch { _ => () }
    None => ()
  }
}

///|
/// 履歴レコードを安全に記録する（失敗は無視）
fn safe_record(
  recorder : &@interfaces.HistoryRecorder?,
  record : @interfaces.HistoryRecord,
) -> Unit {
  match recorder {
    Some(r) => r.record(record~) catch { _ => () }
    None => ()
  }
}

///|
/// 履歴レコーダーを安全にフラッシュする（失敗は無視）
fn safe_flush(recorder : &@interfaces.HistoryRecorder?) -> Unit {
  match recorder {
    Some(r) => r.flush() catch { _ => () }
    None => ()
  }
}

///|
/// ToolResult の内容を (status, content) に変換する
fn tool_result_content(result : @types.ToolResult) -> (String, String) {
  match result {
    Success(content~) => ("success", content)
    Error(message~) => ("error", message)
    RequiresAction(next_tool~, ..) => ("requires_action", next_tool)
  }
}

///|
/// SessionStart を記録
fn record_session_start(
  hr : &@interfaces.HistoryRecorder?,
  clock : &@interfaces.Clock?,
  fallback_ts : Int64,
  sid : String,
  channel : String,
  chat_id : String,
) -> Unit {
  safe_record(hr, {
    timestamp: get_event_timestamp(clock, fallback_ts),
    session_id: sid,
    record_type: @interfaces.HistoryRecordType::SessionStart,
    payload: Json::object({
      "channel": Json::string(channel),
      "chat_id": Json::string(chat_id),
    }),
  })
}

///|
/// SessionMeta を記録（モデル名、設定値、システムプロンプト、ツール一覧等）
fn record_session_meta(
  hr : &@interfaces.HistoryRecorder?,
  clock : &@interfaces.Clock?,
  fallback_ts : Int64,
  sid : String,
  payload : Json,
) -> Unit {
  safe_record(hr, {
    timestamp: get_event_timestamp(clock, fallback_ts),
    session_id: sid,
    record_type: @interfaces.HistoryRecordType::SessionMeta,
    payload,
  })
}

///|
/// UserMessage を記録
fn record_user_message(
  hr : &@interfaces.HistoryRecorder?,
  clock : &@interfaces.Clock?,
  fallback_ts : Int64,
  sid : String,
  content : String,
) -> Unit {
  safe_record(hr, {
    timestamp: get_event_timestamp(clock, fallback_ts),
    session_id: sid,
    record_type: @interfaces.HistoryRecordType::UserMessage,
    payload: Json::object({ "content": Json::string(content) }),
  })
}

///|
/// AssistantMessage を記録
fn record_assistant_message(
  hr : &@interfaces.HistoryRecorder?,
  clock : &@interfaces.Clock?,
  fallback_ts : Int64,
  sid : String,
  content : String,
) -> Unit {
  safe_record(hr, {
    timestamp: get_event_timestamp(clock, fallback_ts),
    session_id: sid,
    record_type: @interfaces.HistoryRecordType::AssistantMessage,
    payload: Json::object({
      "content": Json::string(content),
      "has_tool_calls": Json::boolean(false),
    }),
  })
}

///|
/// ToolCall を記録
fn record_tool_call(
  hr : &@interfaces.HistoryRecorder?,
  clock : &@interfaces.Clock?,
  fallback_ts : Int64,
  sid : String,
  call_id : String,
  tool_name : String,
  arguments : Json,
) -> Unit {
  safe_record(hr, {
    timestamp: get_event_timestamp(clock, fallback_ts),
    session_id: sid,
    record_type: @interfaces.HistoryRecordType::ToolCall,
    payload: Json::object({
      "call_id": Json::string(call_id),
      "tool_name": Json::string(tool_name),
      "arguments": arguments,
    }),
  })
}

///|
/// ToolResult を記録
fn record_tool_result(
  hr : &@interfaces.HistoryRecorder?,
  clock : &@interfaces.Clock?,
  fallback_ts : Int64,
  sid : String,
  call_id : String,
  result : @types.ToolResult,
) -> Unit {
  let (status, content) = tool_result_content(result)
  safe_record(hr, {
    timestamp: get_event_timestamp(clock, fallback_ts),
    session_id: sid,
    record_type: @interfaces.HistoryRecordType::ToolResult,
    payload: Json::object({
      "call_id": Json::string(call_id),
      "status": Json::string(status),
      "content": Json::string(content),
    }),
  })
}

///|
/// SessionEnd を記録してフラッシュ
fn record_session_end(
  hr : &@interfaces.HistoryRecorder?,
  clock : &@interfaces.Clock?,
  fallback_ts : Int64,
  sid : String,
  reason : String,
  iterations : Int,
) -> Unit {
  safe_record(hr, {
    timestamp: get_event_timestamp(clock, fallback_ts),
    session_id: sid,
    record_type: @interfaces.HistoryRecordType::SessionEnd,
    payload: Json::object({
      "reason": Json::string(reason),
      "iterations": Json::number(iterations.to_double()),
    }),
  })
  safe_flush(hr)
}

///|
/// Error を記録してフラッシュ
fn record_error(
  hr : &@interfaces.HistoryRecorder?,
  clock : &@interfaces.Clock?,
  fallback_ts : Int64,
  sid : String,
  message : String,
) -> Unit {
  safe_record(hr, {
    timestamp: get_event_timestamp(clock, fallback_ts),
    session_id: sid,
    record_type: @interfaces.HistoryRecordType::Error,
    payload: Json::object({ "message": Json::string(message) }),
  })
  safe_flush(hr)
}

///|
/// RateLimit Error を記録してフラッシュ
fn record_rate_limit_error(
  hr : &@interfaces.HistoryRecorder?,
  clock : &@interfaces.Clock?,
  fallback_ts : Int64,
  sid : String,
  retry_after : Int,
) -> Unit {
  safe_record(hr, {
    timestamp: get_event_timestamp(clock, fallback_ts),
    session_id: sid,
    record_type: @interfaces.HistoryRecordType::Error,
    payload: Json::object({
      "message": Json::string("Rate limited"),
      "retry_after": Json::number(retry_after.to_double()),
    }),
  })
  safe_flush(hr)
}
