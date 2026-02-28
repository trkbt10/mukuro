///|
/// SSE Parser & Accumulator Tests
/// テストデータは testdata/sse_fixtures/ から抽出した実際のAPIレスポンス

// =============================================================================
// Helper
// =============================================================================

///|
fn assert_true(condition : Bool) -> Unit raise {
  if not(condition) {
    fail("Assertion failed: expected true")
  }
}

// =============================================================================
// JSONL Parser Tests
// =============================================================================

///|
test "parse_chat_completions_jsonl handles basic stream" {
  let jsonl =
    #| {"choices":[{"delta":{"role":"assistant","content":""},"finish_reason":null}]}
    #| {"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}
    #| {"choices":[{"delta":{},"finish_reason":"stop"}]}
    #| [DONE]
  let events = parse_chat_completions_jsonl(jsonl)
  inspect(events.length(), content="3")
  // All events have empty event name
  inspect(events[0].event, content="")
  inspect(events[1].event, content="")
  inspect(events[2].event, content="")
}

///|
test "parse_event_stream_jsonl handles event+data format" {
  let jsonl =
    #| {"event":"message_start","data":{"type":"message_start"}}
    #| {"event":"content_block_delta","data":{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hi"}}}
    #| {"event":"message_stop","data":{"type":"message_stop"}}
  let events = parse_event_stream_jsonl(jsonl)
  inspect(events.length(), content="3")
  inspect(events[0].event, content="message_start")
  inspect(events[1].event, content="content_block_delta")
  inspect(events[2].event, content="message_stop")
}

///|
test "parse_chat_completions_jsonl skips empty lines and DONE" {
  let jsonl =
    #| {"choices":[{"delta":{"content":"x"},"finish_reason":null}]}
    #|
    #| [DONE]
  let events = parse_chat_completions_jsonl(jsonl)
  inspect(events.length(), content="1")
}

// =============================================================================
// Chat Completions Accumulator Tests
// =============================================================================

///|
test "ChatCompletionsAccumulator accumulates text" {
  let jsonl =
    #| {"choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{"content":"Four"},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
    #| [DONE]
  let result = accumulate_chat_completions(jsonl)
  match result {
    @types.ModelResponse::Text(content) => inspect(content, content="Four")
    _ => fail("Expected Text response")
  }
}

///|
test "ChatCompletionsAccumulator accumulates tool calls" {
  let jsonl =
    #| {"choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{"tool_calls":[{"id":"call_abc","type":"function","function":{"name":"get_weather","arguments":"{\"location\":\"Tokyo\"}"}}]},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
    #| [DONE]
  let result = accumulate_chat_completions(jsonl)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].id, content="call_abc")
      inspect(calls[0].name, content="get_weather")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "ChatCompletionsAccumulator with Groq reasoning + text (fixture)" {
  // Groq Chat Completions: reasoning tokens then text content
  let jsonl =
    #| {"choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{"reasoning":"Thinking...","channel":"analysis"},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{"content":"Four"},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
    #| [DONE]
  let result = accumulate_chat_completions(jsonl)
  match result {
    @types.ModelResponse::Text(content) =>
      // reasoning is skipped, only content is accumulated
      inspect(content, content="Four")
    _ => fail("Expected Text response")
  }
}

///|
test "ChatCompletionsAccumulator with Groq reasoning + tool call (fixture)" {
  // Groq Chat Completions: reasoning then tool call
  let jsonl =
    #| {"choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{"reasoning":"Use get_weather","channel":"analysis"},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{"tool_calls":[{"id":"fc_123","type":"function","function":{"name":"get_weather","arguments":"{\"location\":\"Tokyo\"}"}}]},"finish_reason":null}]}
    #| {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
    #| [DONE]
  let result = accumulate_chat_completions(jsonl)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
    }
    _ => fail("Expected ToolCalls response")
  }
}

// =============================================================================
// Responses API Accumulator Tests (OpenAI fixtures)
// =============================================================================

///|
test "ResponsesApiAccumulator text stream (OpenAI fixture)" {
  // From testdata/sse_fixtures/openai/responses/text_stream.jsonl
  let jsonl =
    #| {"event":"response.created","data":{"type":"response.created","response":{"id":"resp_03d6218e6a2496a80069a2578004508191ad80650c5e9738aa","status":"in_progress"},"sequence_number":0}}
    #| {"event":"response.in_progress","data":{"type":"response.in_progress","sequence_number":1}}
    #| {"event":"response.output_item.added","data":{"type":"response.output_item.added","item":{"id":"msg_1","type":"message","status":"in_progress","content":[],"role":"assistant"},"output_index":0,"sequence_number":2}}
    #| {"event":"response.content_part.added","data":{"type":"response.content_part.added","content_index":0,"output_index":0,"part":{"type":"output_text","text":""},"sequence_number":3}}
    #| {"event":"response.output_text.delta","data":{"type":"response.output_text.delta","content_index":0,"delta":"Four","output_index":0,"sequence_number":4}}
    #| {"event":"response.output_text.delta","data":{"type":"response.output_text.delta","content_index":0,"delta":".","output_index":0,"sequence_number":5}}
    #| {"event":"response.output_text.done","data":{"type":"response.output_text.done","text":"Four.","sequence_number":6}}
    #| {"event":"response.content_part.done","data":{"type":"response.content_part.done","sequence_number":7}}
    #| {"event":"response.output_item.done","data":{"type":"response.output_item.done","sequence_number":8}}
    #| {"event":"response.completed","data":{"type":"response.completed","sequence_number":9}}
  let result = accumulate_responses_api(jsonl)
  match result {
    @types.ModelResponse::Text(content) => inspect(content, content="Four.")
    _ => fail("Expected Text response")
  }
}

///|
test "ResponsesApiAccumulator tool call stream (OpenAI fixture)" {
  // From testdata/sse_fixtures/openai/responses/toolcall_stream.jsonl
  let jsonl =
    #| {"event":"response.created","data":{"type":"response.created","sequence_number":0}}
    #| {"event":"response.in_progress","data":{"type":"response.in_progress","sequence_number":1}}
    #| {"event":"response.output_item.added","data":{"type":"response.output_item.added","item":{"id":"fc_abc","type":"function_call","status":"in_progress","arguments":"","call_id":"call_mzdCc2x7eXWn1S6gQJ4nJ6n5","name":"get_weather"},"output_index":0,"sequence_number":2}}
    #| {"event":"response.function_call_arguments.delta","data":{"type":"response.function_call_arguments.delta","delta":"{\"","item_id":"fc_abc","output_index":0,"sequence_number":3}}
    #| {"event":"response.function_call_arguments.delta","data":{"type":"response.function_call_arguments.delta","delta":"location","item_id":"fc_abc","output_index":0,"sequence_number":4}}
    #| {"event":"response.function_call_arguments.delta","data":{"type":"response.function_call_arguments.delta","delta":"\":\"","item_id":"fc_abc","output_index":0,"sequence_number":5}}
    #| {"event":"response.function_call_arguments.delta","data":{"type":"response.function_call_arguments.delta","delta":"Tokyo","item_id":"fc_abc","output_index":0,"sequence_number":6}}
    #| {"event":"response.function_call_arguments.delta","data":{"type":"response.function_call_arguments.delta","delta":"\"}","item_id":"fc_abc","output_index":0,"sequence_number":7}}
    #| {"event":"response.function_call_arguments.done","data":{"type":"response.function_call_arguments.done","arguments":"{\"location\":\"Tokyo\"}","sequence_number":8}}
    #| {"event":"response.output_item.done","data":{"type":"response.output_item.done","sequence_number":9}}
    #| {"event":"response.completed","data":{"type":"response.completed","sequence_number":10}}
  let result = accumulate_responses_api(jsonl)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
      inspect(calls[0].id, content="call_mzdCc2x7eXWn1S6gQJ4nJ6n5")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "ResponsesApiAccumulator with reasoning (Groq fixture)" {
  // Groq Responses API includes reasoning events before text
  let jsonl =
    #| {"event":"response.created","data":{"type":"response.created","sequence_number":0}}
    #| {"event":"response.in_progress","data":{"type":"response.in_progress","sequence_number":1}}
    #| {"event":"response.output_item.added","data":{"type":"response.output_item.added","item":{"type":"reasoning","id":"r1"},"sequence_number":2}}
    #| {"event":"response.reasoning_text.delta","data":{"type":"response.reasoning_text.delta","delta":"Thinking...","sequence_number":3}}
    #| {"event":"response.output_item.added","data":{"type":"response.output_item.added","item":{"type":"message","id":"msg1","role":"assistant","content":[]},"sequence_number":4}}
    #| {"event":"response.output_text.delta","data":{"type":"response.output_text.delta","delta":"Four","sequence_number":5}}
    #| {"event":"response.output_text.done","data":{"type":"response.output_text.done","text":"Four","sequence_number":6}}
    #| {"event":"response.completed","data":{"type":"response.completed","sequence_number":7}}
  let result = accumulate_responses_api(jsonl)
  match result {
    @types.ModelResponse::Text(content) =>
      // reasoning is skipped, only text output accumulated
      inspect(content, content="Four")
    _ => fail("Expected Text response")
  }
}

// =============================================================================
// Anthropic Messages Accumulator Tests
// =============================================================================

///|
test "AnthropicMessagesAccumulator text stream (fixture)" {
  // From testdata/sse_fixtures/anthropic/messages/text_stream.jsonl
  let jsonl =
    #| {"event":"message_start","data":{"type":"message_start","message":{"model":"claude-sonnet-4-6","id":"msg_1","type":"message","role":"assistant","content":[],"stop_reason":null}}}
    #| {"event":"content_block_start","data":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}}
    #| {"event":"ping","data":{"type":"ping"}}
    #| {"event":"content_block_delta","data":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Four"}}}
    #| {"event":"content_block_stop","data":{"type":"content_block_stop","index":0}}
    #| {"event":"message_delta","data":{"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null}}}
    #| {"event":"message_stop","data":{"type":"message_stop"}}
  let result = accumulate_anthropic_messages(jsonl)
  match result {
    @types.ModelResponse::Text(content) => inspect(content, content="Four")
    _ => fail("Expected Text response")
  }
}

///|
test "AnthropicMessagesAccumulator tool call stream (fixture)" {
  // From testdata/sse_fixtures/anthropic/messages/toolcall_stream.jsonl
  let jsonl =
    #| {"event":"message_start","data":{"type":"message_start","message":{"model":"claude-sonnet-4-6","id":"msg_1","type":"message","role":"assistant","content":[],"stop_reason":null}}}
    #| {"event":"content_block_start","data":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}}
    #| {"event":"ping","data":{"type":"ping"}}
    #| {"event":"content_block_delta","data":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"I'll check the weather in"}}}
    #| {"event":"content_block_delta","data":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" Tokyo for you!"}}}
    #| {"event":"content_block_stop","data":{"type":"content_block_stop","index":0}}
    #| {"event":"content_block_start","data":{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_012sP6GVXanr3ThJqSTEzXGs","name":"get_weather","input":{}}}}
    #| {"event":"content_block_delta","data":{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":""}}}
    #| {"event":"content_block_delta","data":{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"location"}}}
    #| {"event":"content_block_delta","data":{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\": \"T"}}}
    #| {"event":"content_block_delta","data":{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"okyo\"}"}}}
    #| {"event":"content_block_stop","data":{"type":"content_block_stop","index":1}}
    #| {"event":"message_delta","data":{"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null}}}
    #| {"event":"message_stop","data":{"type":"message_stop"}}
  let result = accumulate_anthropic_messages(jsonl)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].id, content="toolu_012sP6GVXanr3ThJqSTEzXGs")
      inspect(calls[0].name, content="get_weather")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "AnthropicMessagesAccumulator text-only without tool_use stop_reason" {
  // When stop_reason is "end_turn", even if there happens to be text,
  // it should return Text response
  let jsonl =
    #| {"event":"message_start","data":{"type":"message_start","message":{"id":"msg_1"}}}
    #| {"event":"content_block_start","data":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}}
    #| {"event":"content_block_delta","data":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello world"}}}
    #| {"event":"content_block_stop","data":{"type":"content_block_stop","index":0}}
    #| {"event":"message_delta","data":{"type":"message_delta","delta":{"stop_reason":"end_turn"}}}
    #| {"event":"message_stop","data":{"type":"message_stop"}}
  let result = accumulate_anthropic_messages(jsonl)
  match result {
    @types.ModelResponse::Text(content) =>
      inspect(content, content="Hello world")
    _ => fail("Expected Text response")
  }
}

// =============================================================================
// Responses API Non-Streaming Parser Tests
// =============================================================================

///|
test "parse_responses_api_response text (OpenAI fixture)" {
  // Based on testdata/sse_fixtures/openai/responses/text_nonstream.json
  let json : Json = {
    "output": Json::array([
      {
        "id": "msg_1",
        "type": "message",
        "status": "completed",
        "content": Json::array([
          { "type": "output_text", "annotations": Json::array([]), "text": "Four." },
        ]),
        "role": "assistant",
      },
    ]),
    "status": "completed",
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::Text(content) => inspect(content, content="Four.")
    _ => fail("Expected Text response")
  }
}

///|
test "parse_responses_api_response tool call (OpenAI fixture)" {
  // Based on testdata/sse_fixtures/openai/responses/toolcall_nonstream.json
  let json : Json = {
    "output": Json::array([
      {
        "id": "fc_1",
        "type": "function_call",
        "status": "completed",
        "arguments": "{\"location\":\"Tokyo\"}",
        "call_id": "call_eArLoUy4ikZiEzhId8UK1v2l",
        "name": "get_weather",
      },
    ]),
    "status": "completed",
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
      inspect(calls[0].id, content="call_eArLoUy4ikZiEzhId8UK1v2l")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "parse_responses_api_response with reasoning + text (Groq fixture)" {
  // Based on testdata/sse_fixtures/groq/responses/text_nonstream.json
  // Has reasoning output (skipped) then message output
  let json : Json = {
    "output": Json::array([
      {
        "type": "reasoning",
        "id": "r1",
        "content": Json::array([
          { "type": "reasoning_text", "text": "The user wants 2+2..." },
        ]),
      },
      {
        "type": "message",
        "id": "msg_1",
        "status": "completed",
        "role": "assistant",
        "content": Json::array([
          { "type": "output_text", "text": "4" },
        ]),
      },
    ]),
    "status": "completed",
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::Text(content) =>
      // reasoning is skipped
      inspect(content, content="4")
    _ => fail("Expected Text response")
  }
}

///|
test "parse_responses_api_response with reasoning + function_call (Groq fixture)" {
  // Based on testdata/sse_fixtures/groq/responses/toolcall_nonstream.json
  let json : Json = {
    "output": Json::array([
      {
        "type": "reasoning",
        "id": "r1",
        "content": Json::array([
          { "type": "reasoning_text", "text": "Use get_weather tool." },
        ]),
      },
      {
        "type": "function_call",
        "id": "fc_349411e2",
        "status": "completed",
        "call_id": "fc_349411e2",
        "name": "get_weather",
        "arguments": "{\"location\":\"Tokyo\"}",
      },
    ]),
    "status": "completed",
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
    }
    _ => fail("Expected ToolCalls response")
  }
}

///|
test "parse_responses_api_response error" {
  let json : Json = {
    "error": { "message": "Invalid API key", "type": "invalid_request_error" },
  }
  let result = parse_responses_api_response(json)
  match result {
    @types.ModelResponse::ModelError(msg) =>
      inspect(msg, content="Invalid API key")
    _ => fail("Expected ModelError response")
  }
}

// =============================================================================
// History IO Tests (ModelMessage JSON roundtrip)
// =============================================================================

///|
/// ModelMessage を JSON に変換（テスト用）
fn model_message_to_json(msg : @types.ModelMessage) -> Json {
  match msg {
    @types.ModelMessage::System(text) =>
      { "role": "system", "content": text }
    @types.ModelMessage::User(content~, name~) =>
      match name {
        Some(n) => { "role": "user", "content": content, "name": n }
        None => { "role": "user", "content": content }
      }
    @types.ModelMessage::Assistant(content~, tool_calls~) =>
      match tool_calls {
        Some(calls) => {
          let tc_json : Array[Json] = []
          for call in calls {
            tc_json.push({
              "id": call.id,
              "name": call.name,
              "arguments": call.arguments,
            })
          }
          {
            "role": "assistant",
            "content": content,
            "tool_calls": Json::array(tc_json),
          }
        }
        None => { "role": "assistant", "content": content }
      }
    @types.ModelMessage::ToolResult(tool_call_id~, content~) =>
      { "role": "tool", "tool_call_id": tool_call_id, "content": content }
  }
}

///|
/// JSON から ModelMessage に復元（テスト用）
fn json_to_model_message(json : Json) -> @types.ModelMessage? {
  match json {
    { "role": String("system"), "content": String(text), .. } =>
      Some(@types.ModelMessage::System(text))
    { "role": String("user"), "content": String(content), .. } => {
      let name = match json {
        { "name": String(n), .. } => Some(n)
        _ => None
      }
      Some(@types.ModelMessage::User(content~, name~))
    }
    { "role": String("assistant"), "content": String(content), .. } => {
      let tool_calls : Array[@types.ToolCallRequest]? = match json {
        { "tool_calls": Array(tcs), .. } => {
          let calls : Array[@types.ToolCallRequest] = []
          for tc in tcs {
            match tc {
              {
                "id": String(id),
                "name": String(name),
                "arguments": arguments,
                ..
              } =>
                calls.push(
                  @types.ToolCallRequest::new(id~, name~, arguments~),
                )
              _ => ()
            }
          }
          if calls.length() > 0 { Some(calls) } else { None }
        }
        _ => None
      }
      Some(@types.ModelMessage::Assistant(content~, tool_calls~))
    }
    {
      "role": String("tool"),
      "tool_call_id": String(tool_call_id),
      "content": String(content),
      ..
    } => Some(@types.ModelMessage::ToolResult(tool_call_id~, content~))
    _ => None
  }
}

///|
test "history IO: System message roundtrip" {
  let msg = @types.ModelMessage::System("You are a helpful assistant.")
  let json = model_message_to_json(msg)
  let restored = json_to_model_message(json)
  match restored {
    Some(@types.ModelMessage::System(text)) =>
      inspect(text, content="You are a helpful assistant.")
    _ => fail("System message roundtrip failed")
  }
}

///|
test "history IO: User message roundtrip" {
  let msg = @types.ModelMessage::User(
    content="What is 2+2?",
    name=Some("Alice"),
  )
  let json = model_message_to_json(msg)
  let restored = json_to_model_message(json)
  match restored {
    Some(@types.ModelMessage::User(content~, name~)) => {
      inspect(content, content="What is 2+2?")
      match name {
        Some(n) => inspect(n, content="Alice")
        None => fail("Expected name")
      }
    }
    _ => fail("User message roundtrip failed")
  }
}

///|
test "history IO: User message without name roundtrip" {
  let msg = @types.ModelMessage::User(content="Hello", name=None)
  let json = model_message_to_json(msg)
  let restored = json_to_model_message(json)
  match restored {
    Some(@types.ModelMessage::User(content~, name~)) => {
      inspect(content, content="Hello")
      match name {
        None => ()
        Some(_) => fail("Expected no name")
      }
    }
    _ => fail("User message roundtrip failed")
  }
}

///|
test "history IO: Assistant message roundtrip" {
  let msg = @types.ModelMessage::Assistant(content="Four.", tool_calls=None)
  let json = model_message_to_json(msg)
  let restored = json_to_model_message(json)
  match restored {
    Some(@types.ModelMessage::Assistant(content~, tool_calls~)) => {
      inspect(content, content="Four.")
      match tool_calls {
        None => ()
        Some(_) => fail("Expected no tool calls")
      }
    }
    _ => fail("Assistant message roundtrip failed")
  }
}

///|
test "history IO: Assistant message with tool calls roundtrip" {
  let calls = [
    @types.ToolCallRequest::new(
      id="call_abc",
      name="get_weather",
      arguments={ "location": "Tokyo" },
    ),
  ]
  let msg = @types.ModelMessage::Assistant(
    content="",
    tool_calls=Some(calls),
  )
  let json = model_message_to_json(msg)
  let restored = json_to_model_message(json)
  match restored {
    Some(@types.ModelMessage::Assistant(content~, tool_calls~)) => {
      inspect(content, content="")
      match tool_calls {
        Some(tcs) => {
          inspect(tcs.length(), content="1")
          inspect(tcs[0].id, content="call_abc")
          inspect(tcs[0].name, content="get_weather")
        }
        None => fail("Expected tool calls")
      }
    }
    _ => fail("Assistant message roundtrip failed")
  }
}

///|
test "history IO: ToolResult message roundtrip" {
  let msg = @types.ModelMessage::ToolResult(
    tool_call_id="call_abc",
    content="{\"temperature\":22,\"condition\":\"Partly cloudy\"}",
  )
  let json = model_message_to_json(msg)
  let restored = json_to_model_message(json)
  match restored {
    Some(@types.ModelMessage::ToolResult(tool_call_id~, content~)) => {
      inspect(tool_call_id, content="call_abc")
      assert_true(content.contains("temperature"))
    }
    _ => fail("ToolResult message roundtrip failed")
  }
}

///|
test "history IO: full conversation roundtrip" {
  // Simulate a full conversation: system -> user -> assistant -> tool_result -> assistant
  let conversation : Array[@types.ModelMessage] = [
    @types.ModelMessage::System("You are a helpful assistant."),
    @types.ModelMessage::User(
      content="What is the weather in Tokyo?",
      name=None,
    ),
    @types.ModelMessage::Assistant(
      content="",
      tool_calls=Some([
        @types.ToolCallRequest::new(
          id="call_001",
          name="get_weather",
          arguments={ "location": "Tokyo" },
        ),
      ]),
    ),
    @types.ModelMessage::ToolResult(
      tool_call_id="call_001",
      content="{\"temperature\":22,\"condition\":\"Partly cloudy\",\"humidity\":65}",
    ),
    @types.ModelMessage::Assistant(
      content="The weather in Tokyo is partly cloudy, 22°C with 65% humidity.",
      tool_calls=None,
    ),
  ]
  // Serialize all messages
  let json_messages : Array[Json] = []
  for msg in conversation {
    json_messages.push(model_message_to_json(msg))
  }
  // Deserialize all messages
  let restored : Array[@types.ModelMessage] = []
  for json in json_messages {
    match json_to_model_message(json) {
      Some(msg) => restored.push(msg)
      None => fail("Failed to restore message")
    }
  }
  // Verify count
  inspect(restored.length(), content="5")
  // Verify types
  match restored[0] {
    @types.ModelMessage::System(_) => ()
    _ => fail("Expected System")
  }
  match restored[1] {
    @types.ModelMessage::User(..) => ()
    _ => fail("Expected User")
  }
  match restored[2] {
    @types.ModelMessage::Assistant(tool_calls=Some(calls), ..) =>
      inspect(calls[0].name, content="get_weather")
    _ => fail("Expected Assistant with tool calls")
  }
  match restored[3] {
    @types.ModelMessage::ToolResult(tool_call_id~, ..) =>
      inspect(tool_call_id, content="call_001")
    _ => fail("Expected ToolResult")
  }
  match restored[4] {
    @types.ModelMessage::Assistant(content~, tool_calls=None) =>
      assert_true(content.contains("22"))
    _ => fail("Expected Assistant text")
  }
}

// =============================================================================
// Streaming ↔ Non-streaming consistency tests
// =============================================================================

///|
test "Responses API: streaming and non-streaming produce same text" {
  // Streaming result
  let stream_jsonl =
    #| {"event":"response.created","data":{"type":"response.created"}}
    #| {"event":"response.output_item.added","data":{"type":"response.output_item.added","item":{"type":"message","id":"m1","content":[],"role":"assistant"},"output_index":0}}
    #| {"event":"response.output_text.delta","data":{"type":"response.output_text.delta","delta":"Four."}}
    #| {"event":"response.output_text.done","data":{"type":"response.output_text.done","text":"Four."}}
    #| {"event":"response.completed","data":{"type":"response.completed"}}
  let stream_result = accumulate_responses_api(stream_jsonl)
  // Non-streaming result
  let nonstream_json : Json = {
    "output": Json::array([
      {
        "type": "message",
        "content": Json::array([
          { "type": "output_text", "text": "Four." },
        ]),
        "role": "assistant",
      },
    ]),
  }
  let nonstream_result = parse_responses_api_response(nonstream_json)
  // Both should produce the same text
  match (stream_result, nonstream_result) {
    (@types.ModelResponse::Text(s), @types.ModelResponse::Text(ns)) =>
      inspect(s, content=ns)
    _ => fail("Expected matching Text responses")
  }
}

///|
test "Responses API: streaming and non-streaming produce same tool call" {
  // Streaming result
  let stream_jsonl =
    #| {"event":"response.created","data":{"type":"response.created"}}
    #| {"event":"response.output_item.added","data":{"type":"response.output_item.added","item":{"type":"function_call","id":"fc1","call_id":"call_xyz","name":"get_weather","arguments":""},"output_index":0}}
    #| {"event":"response.function_call_arguments.delta","data":{"type":"response.function_call_arguments.delta","delta":"{\"location\":\"Tokyo\"}"}}
    #| {"event":"response.function_call_arguments.done","data":{"type":"response.function_call_arguments.done","arguments":"{\"location\":\"Tokyo\"}"}}
    #| {"event":"response.completed","data":{"type":"response.completed"}}
  let stream_result = accumulate_responses_api(stream_jsonl)
  // Non-streaming result
  let nonstream_json : Json = {
    "output": Json::array([
      {
        "type": "function_call",
        "id": "fc1",
        "call_id": "call_xyz",
        "name": "get_weather",
        "arguments": "{\"location\":\"Tokyo\"}",
      },
    ]),
  }
  let nonstream_result = parse_responses_api_response(nonstream_json)
  // Both should produce tool calls with same name
  match (stream_result, nonstream_result) {
    (
      @types.ModelResponse::ToolCalls(s_calls),
      @types.ModelResponse::ToolCalls(ns_calls),
    ) => {
      inspect(s_calls.length(), content="1")
      inspect(ns_calls.length(), content="1")
      inspect(s_calls[0].name, content=ns_calls[0].name)
    }
    _ => fail("Expected matching ToolCalls responses")
  }
}
