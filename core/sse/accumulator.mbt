///|
/// ツールコール蓄積用の内部構造
struct ToolCallAcc {
  id : String
  name : String
  arguments : StringBuilder
}

// =============================================================================
// Chat Completions Accumulator
// =============================================================================

///|
/// OpenAI Chat Completions ストリームアキュムレータ
/// choices[0].delta からテキストとツールコールを蓄積
pub struct ChatCompletionsAccumulator {
  text : StringBuilder
  tool_calls : Array[ToolCallAcc]
  mut finish_reason : String
}

///|
pub fn ChatCompletionsAccumulator::new() -> ChatCompletionsAccumulator {
  { text: StringBuilder::new(), tool_calls: [], finish_reason: "" }
}

///|
/// チャンクイベントを処理
pub fn ChatCompletionsAccumulator::feed(
  self : ChatCompletionsAccumulator,
  event : SseEvent,
) -> Unit {
  match event.data {
    { "choices": Array(choices), .. } =>
      if choices.length() > 0 {
        let choice = choices[0]
        match choice {
          { "delta": delta, .. } => {
            // テキストデルタ
            match delta {
              { "content": String(content), .. } =>
                self.text.write_string(content)
              _ => ()
            }
            // ツールコールデルタ
            match delta {
              { "tool_calls": Array(tc_deltas), .. } =>
                for tc in tc_deltas {
                  self.process_tool_call_delta(tc)
                }
              _ => ()
            }
          }
          _ => ()
        }
        // finish_reason
        match choice {
          { "finish_reason": String(fr), .. } => self.finish_reason = fr
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn ChatCompletionsAccumulator::process_tool_call_delta(
  self : ChatCompletionsAccumulator,
  tc : Json,
) -> Unit {
  match tc {
    { "id": String(id), "function": { "name": String(name), .. }, .. } => {
      // 新規ツールコール
      let acc : ToolCallAcc = {
        id,
        name,
        arguments: StringBuilder::new(),
      }
      match tc {
        { "function": { "arguments": String(args), .. }, .. } =>
          acc.arguments.write_string(args)
        _ => ()
      }
      self.tool_calls.push(acc)
    }
    { "function": { "arguments": String(args), .. }, .. } =>
      // 既存ツールコールへの引数追加
      if self.tool_calls.length() > 0 {
        self.tool_calls[self.tool_calls.length() - 1].arguments.write_string(
          args,
        )
      }
    _ => ()
  }
}

///|
/// 最終結果を取得
pub fn ChatCompletionsAccumulator::finish(
  self : ChatCompletionsAccumulator,
) -> @types.ModelResponse {
  if self.finish_reason == "tool_calls" && self.tool_calls.length() > 0 {
    let calls : Array[@types.ToolCallRequest] = []
    for tc in self.tool_calls {
      let args_str = tc.arguments.to_string()
      let arguments : Json = @json.parse(args_str) catch { _ => {} }
      calls.push(@types.ToolCallRequest::new(id=tc.id, name=tc.name, arguments~))
    }
    @types.ModelResponse::ToolCalls(calls)
  } else {
    @types.ModelResponse::Text(self.text.to_string())
  }
}

// =============================================================================
// Responses API Accumulator
// =============================================================================

///|
/// OpenAI/Groq Responses API ストリームアキュムレータ
/// response.output_text.delta, response.function_call_arguments.delta 等を蓄積
pub struct ResponsesApiAccumulator {
  text : StringBuilder
  function_calls : Array[ToolCallAcc]
  mut completed : Bool
}

///|
pub fn ResponsesApiAccumulator::new() -> ResponsesApiAccumulator {
  { text: StringBuilder::new(), function_calls: [], completed: false }
}

///|
/// SSEイベントを処理
pub fn ResponsesApiAccumulator::feed(
  self : ResponsesApiAccumulator,
  event : SseEvent,
) -> Unit {
  match event.event {
    "response.output_text.delta" =>
      match event.data {
        { "delta": String(delta), .. } => self.text.write_string(delta)
        _ => ()
      }
    "response.output_item.added" =>
      match event.data {
        {
          "item": {
            "type": String("function_call"),
            "name": String(name),
            ..
          } as item,
          ..
        } => {
          let id = match item {
            { "call_id": String(cid), .. } => cid
            { "id": String(fid), .. } => fid
            _ => ""
          }
          self.function_calls.push(
            { id, name, arguments: StringBuilder::new() },
          )
        }
        _ => ()
      }
    "response.function_call_arguments.delta" =>
      match event.data {
        { "delta": String(delta), .. } =>
          if self.function_calls.length() > 0 {
            self.function_calls[self.function_calls.length() - 1]
            .arguments
            .write_string(delta)
          }
        _ => ()
      }
    "response.completed" => self.completed = true
    _ => () // reasoning, content_part, ping, etc.
  }
}

///|
/// 最終結果を取得
pub fn ResponsesApiAccumulator::finish(
  self : ResponsesApiAccumulator,
) -> @types.ModelResponse {
  if self.function_calls.length() > 0 {
    let calls : Array[@types.ToolCallRequest] = []
    for fc in self.function_calls {
      let args_str = fc.arguments.to_string()
      let arguments : Json = @json.parse(args_str) catch { _ => {} }
      calls.push(
        @types.ToolCallRequest::new(id=fc.id, name=fc.name, arguments~),
      )
    }
    @types.ModelResponse::ToolCalls(calls)
  } else {
    @types.ModelResponse::Text(self.text.to_string())
  }
}

// =============================================================================
// Anthropic Messages Accumulator
// =============================================================================

///|
/// Anthropic Messages API ストリームアキュムレータ
/// content_block_delta (text_delta / input_json_delta) を蓄積
pub struct AnthropicMessagesAccumulator {
  text : StringBuilder
  tool_calls : Array[ToolCallAcc]
  mut stop_reason : String
}

///|
pub fn AnthropicMessagesAccumulator::new() -> AnthropicMessagesAccumulator {
  { text: StringBuilder::new(), tool_calls: [], stop_reason: "" }
}

///|
/// SSEイベントを処理
pub fn AnthropicMessagesAccumulator::feed(
  self : AnthropicMessagesAccumulator,
  event : SseEvent,
) -> Unit {
  match event.event {
    "content_block_start" =>
      match event.data {
        {
          "content_block": {
            "type": String("tool_use"),
            "id": String(id),
            "name": String(name),
            ..
          },
          ..
        } =>
          self.tool_calls.push(
            { id, name, arguments: StringBuilder::new() },
          )
        _ => ()
      }
    "content_block_delta" =>
      match event.data {
        { "delta": { "type": String("text_delta"), "text": String(t), .. }, .. } =>
          self.text.write_string(t)
        {
          "delta": {
            "type": String("input_json_delta"),
            "partial_json": String(pj),
            ..
          },
          ..
        } =>
          if self.tool_calls.length() > 0 {
            self.tool_calls[self.tool_calls.length() - 1]
            .arguments
            .write_string(pj)
          }
        _ => ()
      }
    "message_delta" =>
      match event.data {
        { "delta": { "stop_reason": String(sr), .. }, .. } =>
          self.stop_reason = sr
        _ => ()
      }
    _ => () // message_start, content_block_stop, ping, message_stop
  }
}

///|
/// 最終結果を取得
pub fn AnthropicMessagesAccumulator::finish(
  self : AnthropicMessagesAccumulator,
) -> @types.ModelResponse {
  if self.stop_reason == "tool_use" && self.tool_calls.length() > 0 {
    let calls : Array[@types.ToolCallRequest] = []
    for tc in self.tool_calls {
      let args_str = tc.arguments.to_string()
      let arguments : Json = @json.parse(args_str) catch { _ => {} }
      calls.push(@types.ToolCallRequest::new(id=tc.id, name=tc.name, arguments~))
    }
    @types.ModelResponse::ToolCalls(calls)
  } else {
    @types.ModelResponse::Text(self.text.to_string())
  }
}

// =============================================================================
// Convenience functions
// =============================================================================

///|
/// Chat Completions JSONLを一括処理してModelResponseを返す
pub fn accumulate_chat_completions(content : String) -> @types.ModelResponse raise {
  let events = parse_chat_completions_jsonl(content)
  let acc = ChatCompletionsAccumulator::new()
  for event in events {
    acc.feed(event)
  }
  acc.finish()
}

///|
/// Responses API JSONLを一括処理してModelResponseを返す
pub fn accumulate_responses_api(content : String) -> @types.ModelResponse raise {
  let events = parse_event_stream_jsonl(content)
  let acc = ResponsesApiAccumulator::new()
  for event in events {
    acc.feed(event)
  }
  acc.finish()
}

///|
/// Anthropic Messages JSONLを一括処理してModelResponseを返す
pub fn accumulate_anthropic_messages(
  content : String,
) -> @types.ModelResponse raise {
  let events = parse_event_stream_jsonl(content)
  let acc = AnthropicMessagesAccumulator::new()
  for event in events {
    acc.feed(event)
  }
  acc.finish()
}
