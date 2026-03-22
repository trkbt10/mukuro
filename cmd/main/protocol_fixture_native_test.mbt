///|
/// Protocol Fixture Tests (Native only)
/// Tests that read real API response fixtures from testdata/sse_fixtures/
/// and verify protocol parsing produces correct results.
///
/// These tests ensure our parsers handle actual API responses
/// from OpenAI, Groq, and Anthropic providers.

///|
fn fixture_path(relative : String) -> String {
  "testdata/sse_fixtures/\{relative}"
}

///|
fn read_fixture(path : String) -> String raise {
  let buffer_len = 131072
  let buffer = Bytes::new(buffer_len)
  let read_len = @native.c_read_text_file_bytes(
    @native.string_to_utf8_cstring(path),
    buffer,
    buffer_len,
  )
  if read_len < 0 {
    fail("Fixture file not found: \{path}")
  }
  match @bytes.decode_utf8(buffer[:read_len]) {
    Some(s) => s
    None => fail("UTF-8 decode failed for: \{path}")
  }
}

///|
fn read_fixture_json(relative : String) -> Json raise {
  let content = read_fixture(fixture_path(relative))
  @json.parse(content) catch {
    _ => fail("JSON parse failed for: \{relative}")
  }
}

///|
fn fixture_assert_true(condition : Bool) -> Unit raise {
  if not(condition) {
    fail("Assertion failed: expected true")
  }
}

// =============================================================================
// OpenAI Responses API — Non-streaming Fixtures
// =============================================================================

///|
test "fixture: OpenAI Responses API text non-stream" {
  let json = read_fixture_json("openai/responses/text_nonstream.json")
  let result = @openai.parse_responses_api_response(json)
  match result {
    @llm_types.ModelResponse::Text(text) => inspect(text, content="Four.")
    _ => fail("Expected Text response")
  }
}

///|
test "fixture: OpenAI Responses API toolcall non-stream" {
  let json = read_fixture_json("openai/responses/toolcall_nonstream.json")
  let result = @openai.parse_responses_api_response(json)
  match result {
    @llm_types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response")
  }
}

// =============================================================================
// Groq Responses API — Non-streaming Fixtures (has reasoning + message)
// =============================================================================

///|
test "fixture: Groq Responses API text non-stream" {
  let json = read_fixture_json("groq/responses/text_nonstream.json")
  let result = @openai.parse_responses_api_response(json)
  match result {
    @llm_types.ModelResponse::Text(text) => inspect(text, content="4")
    _ => fail("Expected Text response")
  }
}

///|
test "fixture: Groq Responses API toolcall non-stream" {
  let json = read_fixture_json("groq/responses/toolcall_nonstream.json")
  let result = @openai.parse_responses_api_response(json)
  match result {
    @llm_types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response")
  }
}

// =============================================================================
// Groq Chat Completions — Non-streaming Fixtures
// =============================================================================

///|
test "fixture: Groq Chat Completions text non-stream" {
  let json = read_fixture_json("groq/chat_completions/text_nonstream.json")
  let result = @openai.parse_chat_response(json)
  match result {
    @llm_types.ModelResponse::Text(text) => inspect(text, content="four")
    _ => fail("Expected Text response")
  }
}

///|
test "fixture: Groq Chat Completions toolcall non-stream" {
  let json = read_fixture_json("groq/chat_completions/toolcall_nonstream.json")
  let result = @openai.parse_chat_response(json)
  match result {
    @llm_types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response")
  }
}

// =============================================================================
// Anthropic Messages — Non-streaming Fixtures
// =============================================================================

///|
test "fixture: Anthropic Messages text non-stream" {
  let json = read_fixture_json("anthropic/messages/text_nonstream.json")
  let result = @anthropic.parse_response(json)
  match result {
    @llm_types.ModelResponse::Text(text) => inspect(text, content="Four")
    _ => fail("Expected Text response")
  }
}

///|
test "fixture: Anthropic Messages toolcall non-stream" {
  let json = read_fixture_json("anthropic/messages/toolcall_nonstream.json")
  let result = @anthropic.parse_response(json)
  match result {
    @llm_types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response")
  }
}

// =============================================================================
// Error Response Fixtures
// =============================================================================

///|
test "fixture: OpenAI auth error via Chat Completions parser" {
  let json = read_fixture_json("openai/errors/auth_error.json")
  let result = @openai.parse_chat_response(json)
  match result {
    @llm_types.ModelResponse::ModelError(msg) =>
      fixture_assert_true(msg.contains("API key"))
    _ => fail("Expected ModelError response")
  }
}

///|
test "fixture: OpenAI auth error via Responses API parser" {
  let json = read_fixture_json("openai/errors/auth_error.json")
  let result = @openai.parse_responses_api_response(json)
  match result {
    @llm_types.ModelResponse::ModelError(msg) =>
      fixture_assert_true(msg.contains("API key"))
    _ => fail("Expected ModelError response")
  }
}

///|
test "fixture: Groq auth error" {
  let json = read_fixture_json("groq/errors/auth_error.json")
  let result = @openai.parse_chat_response(json)
  match result {
    @llm_types.ModelResponse::ModelError(msg) =>
      fixture_assert_true(msg.contains("Invalid API Key"))
    _ => fail("Expected ModelError response")
  }
}

///|
test "fixture: Anthropic auth error" {
  let json = read_fixture_json("anthropic/errors/auth_error.json")
  let result = @anthropic.parse_response(json)
  match result {
    @llm_types.ModelResponse::ModelError(msg) =>
      fixture_assert_true(msg.contains("invalid x-api-key"))
    _ => fail("Expected ModelError response")
  }
}

// =============================================================================
// SSE Streaming JSONL Fixtures — Parse verification
// =============================================================================

///|
test "fixture: Groq Chat Completions text stream JSONL parses" {
  let content = read_fixture(
    fixture_path("groq/chat_completions/text_stream.jsonl"),
  )
  let events = @sse.parse_jsonl(content)
  // 34 data lines + [DONE] (skipped) = 34 events
  fixture_assert_true(events.length() > 10)
  // Last event should have finish_reason "stop"
  let last = events[events.length() - 1]
  let s = last.data.stringify()
  fixture_assert_true(s.contains("\"finish_reason\":\"stop\""))
}

///|
test "fixture: Groq Chat Completions toolcall stream JSONL parses" {
  let content = read_fixture(
    fixture_path("groq/chat_completions/toolcall_stream.jsonl"),
  )
  let events = @sse.parse_jsonl(content)
  fixture_assert_true(events.length() > 5)
  // Should contain tool_calls in some event
  let full = content
  fixture_assert_true(full.contains("get_weather"))
  fixture_assert_true(full.contains("\"finish_reason\":\"tool_calls\""))
}

///|
test "fixture: OpenAI Responses text stream JSONL parses" {
  let content = read_fixture(fixture_path("openai/responses/text_stream.jsonl"))
  let events = @sse.parse_jsonl(content)
  fixture_assert_true(events.length() > 5)
  // Should have response.completed event
  let mut has_completed = false
  for e in events {
    if e.event == "response.completed" {
      has_completed = true
    }
  }
  fixture_assert_true(has_completed)
  // Should contain "Four." in text delta
  fixture_assert_true(content.contains("Four"))
}

///|
test "fixture: Anthropic Messages text stream JSONL parses" {
  let content = read_fixture(
    fixture_path("anthropic/messages/text_stream.jsonl"),
  )
  let events = @sse.parse_jsonl(content)
  fixture_assert_true(events.length() > 3)
  // Should have message_start and message_stop events
  let mut has_start = false
  let mut has_stop = false
  for e in events {
    if e.event == "message_start" {
      has_start = true
    }
    if e.event == "message_stop" {
      has_stop = true
    }
  }
  fixture_assert_true(has_start)
  fixture_assert_true(has_stop)
  // Should contain "Four" in content delta
  fixture_assert_true(content.contains("Four"))
}

// =============================================================================
// SSE Streaming — Accumulator end-to-end with real fixtures
// =============================================================================

///|
test "fixture: Groq Chat Completions text stream accumulates to text" {
  let content = read_fixture(
    fixture_path("groq/chat_completions/text_stream.jsonl"),
  )
  let result = @openai.accumulate_chat_completions(content)
  match result {
    @llm_types.ModelResponse::Text(text) => inspect(text, content="Four")
    _ => fail("Expected Text response from accumulated stream")
  }
}

///|
test "fixture: Groq Chat Completions toolcall stream accumulates to tool calls" {
  let content = read_fixture(
    fixture_path("groq/chat_completions/toolcall_stream.jsonl"),
  )
  let result = @openai.accumulate_chat_completions(content)
  match result {
    @llm_types.ModelResponse::ToolCalls(calls) => {
      inspect(calls.length(), content="1")
      inspect(calls[0].name, content="get_weather")
      match calls[0].arguments {
        { "location": String(loc), .. } => inspect(loc, content="Tokyo")
        _ => fail("Expected location argument")
      }
    }
    _ => fail("Expected ToolCalls response from accumulated stream")
  }
}

///|
test "fixture: OpenAI Responses text stream accumulates to text" {
  let content = read_fixture(fixture_path("openai/responses/text_stream.jsonl"))
  let result = @openai.accumulate_responses_api(content)
  match result {
    @llm_types.ModelResponse::Text(text) => inspect(text, content="Four.")
    _ => fail("Expected Text response from accumulated stream")
  }
}

///|
test "fixture: Anthropic Messages text stream accumulates to text" {
  let content = read_fixture(
    fixture_path("anthropic/messages/text_stream.jsonl"),
  )
  let result = @anthropic.accumulate_messages(content)
  match result {
    @llm_types.ModelResponse::Text(text) => inspect(text, content="Four")
    _ => fail("Expected Text response from accumulated stream")
  }
}

// =============================================================================
// Cross-format consistency: streaming vs non-streaming produce same result
// =============================================================================

///|
test "fixture: OpenAI Responses text — stream vs non-stream consistent" {
  // Non-streaming
  let ns_json = read_fixture_json("openai/responses/text_nonstream.json")
  let ns_result = @openai.parse_responses_api_response(ns_json)
  // Streaming
  let s_content = read_fixture(
    fixture_path("openai/responses/text_stream.jsonl"),
  )
  let s_result = @openai.accumulate_responses_api(s_content)
  match (ns_result, s_result) {
    (
      @llm_types.ModelResponse::Text(ns_text),
      @llm_types.ModelResponse::Text(s_text),
    ) => inspect(ns_text, content=s_text)
    _ => fail("Expected both to be Text responses")
  }
}

///|
test "fixture: Anthropic Messages text — stream vs non-stream consistent" {
  // Non-streaming
  let ns_json = read_fixture_json("anthropic/messages/text_nonstream.json")
  let ns_result = @anthropic.parse_response(ns_json)
  // Streaming
  let s_content = read_fixture(
    fixture_path("anthropic/messages/text_stream.jsonl"),
  )
  let s_result = @anthropic.accumulate_messages(s_content)
  match (ns_result, s_result) {
    (
      @llm_types.ModelResponse::Text(ns_text),
      @llm_types.ModelResponse::Text(s_text),
    ) => inspect(ns_text, content=s_text)
    _ => fail("Expected both to be Text responses")
  }
}
