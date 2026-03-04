///|
/// Interoperability layer between Chat Completions (Harmony) and Responses API
/// Enables using Responses API interface while communicating via Chat Completions

// =============================================================================
// Responses API Input → Chat Completions Messages
// =============================================================================

///|
/// Responses API input items を Chat Completions messages 形式に変換
/// input: [{ role: "user", content: "..." }, { type: "function_call", ... }, ...]
/// output: Array[@types.ModelMessage]
pub fn responses_input_to_messages(
  input : Array[Json],
) -> Array[@types.ModelMessage] {
  let messages : Array[@types.ModelMessage] = []
  let mut pending_tool_calls : Array[@types.ToolCallRequest] = []
  for item in input {
    match item {
      // System message
      { "role": String("system"), "content": String(content), .. } =>
        messages.push(@types.ModelMessage::System(content))
      // User message
      { "role": String("user"), "content": String(content), .. } => {
        // Flush any pending tool calls as assistant message
        if pending_tool_calls.length() > 0 {
          messages.push(
            @types.ModelMessage::Assistant(
              content="",
              tool_calls=Some(pending_tool_calls),
            ),
          )
          pending_tool_calls = []
        }
        messages.push(@types.ModelMessage::User(content~, name=None))
      }
      // Assistant message (text only)
      { "role": String("assistant"), "content": String(content), .. } => {
        // Flush any pending tool calls first
        if pending_tool_calls.length() > 0 {
          messages.push(
            @types.ModelMessage::Assistant(
              content="",
              tool_calls=Some(pending_tool_calls),
            ),
          )
          pending_tool_calls = []
        }
        messages.push(@types.ModelMessage::Assistant(content~, tool_calls=None))
      }
      // Function call (Responses API format)
      {
        "type": String("function_call"),
        "name": String(name),
        "arguments": String(args_str),
        ..
      } => {
        let id = match item {
          { "call_id": String(cid), .. } => cid
          { "id": String(fid), .. } => fid
          _ => ""
        }
        let arguments : Json = @json.parse(args_str) catch { _ => {} }
        pending_tool_calls.push(
          @types.ToolCallRequest::new(id~, name~, arguments~),
        )
      }
      // Function call output (Responses API format)
      {
        "type": String("function_call_output"),
        "call_id": String(call_id),
        "output": String(output),
        ..
      } => {
        // Flush pending tool calls as assistant message first
        if pending_tool_calls.length() > 0 {
          messages.push(
            @types.ModelMessage::Assistant(
              content="",
              tool_calls=Some(pending_tool_calls),
            ),
          )
          pending_tool_calls = []
        }
        messages.push(
          @types.ModelMessage::ToolResult(tool_call_id=call_id, content=output),
        )
      }
      _ => () // Unknown item type, skip
    }
  }
  // Flush any remaining pending tool calls
  if pending_tool_calls.length() > 0 {
    messages.push(
      @types.ModelMessage::Assistant(
        content="",
        tool_calls=Some(pending_tool_calls),
      ),
    )
  }
  messages
}

// =============================================================================
// ModelResponse → Responses API JSON
// =============================================================================

///|
/// ModelResponse を Responses API レスポンス JSON に変換
pub fn model_response_to_responses_json(
  response : @types.ModelResponse,
  response_id? : String = "resp_generated",
  model? : String = "openai/gpt-oss-20b",
) -> Json {
  match response {
    @types.ModelResponse::Text(content) =>
      {
        "id": response_id,
        "object": "response",
        "status": "completed",
        "output": Json::array([
          {
            "type": "message",
            "role": "assistant",
            "content": Json::array([
              { "type": "output_text", "text": content },
            ]),
          },
        ]),
        "model": model,
      }
    @types.ModelResponse::ToolCalls(calls) => {
      let output : Array[Json] = []
      for call in calls {
        output.push({
          "type": "function_call",
          "id": call.id,
          "call_id": call.id,
          "name": call.name,
          "arguments": call.arguments.stringify(),
          "status": "completed",
        })
      }
      {
        "id": response_id,
        "object": "response",
        "status": "completed",
        "output": Json::array(output),
        "model": model,
      }
    }
    @types.ModelResponse::ModelError(msg) =>
      { "error": { "type": "error", "message": msg } }
    @types.ModelResponse::RateLimited(retry_after~) =>
      {
        "error": {
          "type": "rate_limit_error",
          "message": "Rate limited",
          "retry_after": retry_after,
        },
      }
  }
}

// =============================================================================
// Harmony SSE → Responses API SSE Events
// =============================================================================

///|
/// Harmony Chat Completions の SSE チャンクを Responses API イベント形式に変換
/// 蓄積型: 状態を保持しながら変換イベントを生成
pub struct HarmonyToResponsesTranslator {
  response_id : String
  mut output_index : Int
  mut has_emitted_created : Bool
  mut current_tool_call_id : String
  text_buffer : StringBuilder
  reasoning_buffer : StringBuilder
}

///|
pub fn HarmonyToResponsesTranslator::new(
  response_id? : String = "resp_generated",
) -> HarmonyToResponsesTranslator {
  {
    response_id,
    output_index: 0,
    has_emitted_created: false,
    current_tool_call_id: "",
    text_buffer: StringBuilder::new(),
    reasoning_buffer: StringBuilder::new(),
  }
}

///|
/// Harmony SSE イベントを処理し、Responses API イベントを生成
/// 戻り値: 生成された Responses API イベントの配列 (event_type, data)
pub fn HarmonyToResponsesTranslator::translate(
  self : HarmonyToResponsesTranslator,
  event : @sse.SseEvent,
) -> Array[(String, Json)] {
  let events : Array[(String, Json)] = []
  // Emit response.created on first event
  if not(self.has_emitted_created) {
    events.push((
      "response.created",
      { "type": "response.created", "response": { "id": self.response_id } },
    ))
    self.has_emitted_created = true
  }
  match event.data {
    { "choices": Array(choices), .. } =>
      if choices.length() > 0 {
        let choice = choices[0]
        match choice {
          { "delta": delta, .. } => {
            // Text content delta → response.output_text.delta
            match delta {
              { "content": String(content), .. } =>
                if content.length() > 0 {
                  self.text_buffer.write_string(content)
                  events.push((
                    "response.output_text.delta",
                    {
                      "type": "response.output_text.delta",
                      "delta": content,
                      "output_index": self.output_index,
                    },
                  ))
                }
              _ => ()
            }
            // Reasoning delta (optional, for debugging/logging)
            match delta {
              { "reasoning": String(r), .. } =>
                self.reasoning_buffer.write_string(r)
              _ => ()
            }
            // Tool calls
            match delta {
              { "tool_calls": Array(tc_deltas), .. } =>
                for tc in tc_deltas {
                  let tc_events = self.translate_tool_call(tc)
                  for e in tc_events {
                    events.push(e)
                  }
                }
              _ => ()
            }
          }
          _ => ()
        }
        // Check finish_reason
        match choice {
          { "finish_reason": String("stop"), .. } => {
            events.push((
              "response.output_text.done",
              {
                "type": "response.output_text.done",
                "text": self.text_buffer.to_string(),
                "output_index": self.output_index,
              },
            ))
            events.push(("response.completed", { "type": "response.completed" }))
          }
          { "finish_reason": String("tool_calls"), .. } =>
            events.push(("response.completed", { "type": "response.completed" }))
          _ => ()
        }
      }
    _ => ()
  }
  events
}

///|
fn HarmonyToResponsesTranslator::translate_tool_call(
  self : HarmonyToResponsesTranslator,
  tc : Json,
) -> Array[(String, Json)] {
  let events : Array[(String, Json)] = []
  match tc {
    // New tool call with id and name
    { "id": String(id), "function": { "name": String(name), .. }, .. } => {
      self.current_tool_call_id = id
      self.output_index = self.output_index + 1
      events.push((
        "response.output_item.added",
        {
          "type": "response.output_item.added",
          "output_index": self.output_index,
          "item": {
            "type": "function_call",
            "id": id,
            "call_id": id,
            "name": name,
            "arguments": "",
          },
        },
      ))
      // If arguments are included in first chunk
      match tc {
        { "function": { "arguments": String(args), .. }, .. } =>
          if args.length() > 0 {
            events.push((
              "response.function_call_arguments.delta",
              {
                "type": "response.function_call_arguments.delta",
                "delta": args,
                "output_index": self.output_index,
              },
            ))
          }
        _ => ()
      }
    }
    // Arguments delta for existing tool call
    { "function": { "arguments": String(args), .. }, .. } =>
      if args.length() > 0 {
        events.push((
          "response.function_call_arguments.delta",
          {
            "type": "response.function_call_arguments.delta",
            "delta": args,
            "output_index": self.output_index,
          },
        ))
      }
    _ => ()
  }
  events
}

///|
/// Get accumulated reasoning (for debugging/logging)
pub fn HarmonyToResponsesTranslator::get_reasoning(
  self : HarmonyToResponsesTranslator,
) -> String {
  self.reasoning_buffer.to_string()
}

// =============================================================================
// Full Pipeline: Responses API Request → Chat Completions → Responses API Response
// =============================================================================

///|
/// Responses API リクエストを Chat Completions リクエストボディに変換
pub fn responses_request_to_chat_completions(
  request : Json,
) -> Json {
  let model = match request {
    { "model": String(m), .. } => m
    _ => "openai/gpt-oss-20b"
  }
  let input = match request {
    { "input": Array(items), .. } => items
    _ => []
  }
  let messages = responses_input_to_messages(input)
  let msgs_json = messages_to_openai_json(messages)
  // Build Chat Completions body
  let body : Map[String, Json] = {
    "model": Json::string(model),
    "messages": Json::array(msgs_json),
    "stream": Json::boolean(true),
  }
  // Convert tools
  match request {
    { "tools": Array(tools), .. } =>
      if tools.length() > 0 {
        body["tools"] = Json::array(tools)
        body["tool_choice"] = Json::string("auto")
      }
    _ => ()
  }
  Json::object(body)
}
