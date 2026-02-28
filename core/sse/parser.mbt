///|
/// SSEイベント（JSONLから解析済み）
pub(all) struct SseEvent {
  /// イベント名（Chat Completionsでは空文字列）
  event : String
  /// データペイロード
  data : Json
}

///|
/// 文字列を行に分割
fn split_lines(s : String) -> Array[String] {
  let lines : Array[String] = []
  let buf = StringBuilder::new()
  for c in s {
    if c == '\n' {
      lines.push(buf.to_string())
      buf.reset()
    } else if c == '\r' {
      // CR は無視（CRLF 対応）
      continue
    } else {
      buf.write_char(c)
    }
  }
  let last = buf.to_string()
  if last.length() > 0 {
    lines.push(last)
  }
  lines
}

///|
/// Chat Completions形式のJSONLをパース
/// フォーマット: 各行がJSON（event:ヘッダーなし）。[DONE]で終端。
pub fn parse_chat_completions_jsonl(content : String) -> Array[SseEvent] raise {
  let events : Array[SseEvent] = []
  let lines = split_lines(content)
  for line in lines {
    let trimmed = line.trim().to_string()
    if trimmed.length() == 0 || trimmed == "[DONE]" {
      continue
    }
    let json = @json.parse(trimmed)
    events.push({ event: "", data: json })
  }
  events
}

///|
/// Responses API / Anthropic Messages形式のJSONLをパース
/// フォーマット: 各行が {"event":"...","data":{...}}
pub fn parse_event_stream_jsonl(content : String) -> Array[SseEvent] raise {
  let events : Array[SseEvent] = []
  let lines = split_lines(content)
  for line in lines {
    let trimmed = line.trim().to_string()
    if trimmed.length() == 0 {
      continue
    }
    let json = @json.parse(trimmed)
    match json {
      { "event": String(event), "data": data, .. } =>
        events.push({ event, data })
      _ => events.push({ event: "", data: json })
    }
  }
  events
}
