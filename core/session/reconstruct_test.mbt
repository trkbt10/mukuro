///|
/// セッション復元ロジックのテスト

///|
test "extract_payload_content: extracts content from object" {
  let payload = Json::object({ "content": Json::string("Hello, world!") })
  let content = extract_payload_content(payload)
  assert_eq(content, "Hello, world!")
}

///|
test "extract_payload_content: returns empty for missing content" {
  let payload = Json::object({ "other": Json::string("value") })
  let content = extract_payload_content(payload)
  assert_eq(content, "")
}

///|
test "extract_payload_name: extracts name from object" {
  let payload = Json::object({
    "content": Json::string("Hello"),
    "name": Json::string("Alice"),
  })
  let name = extract_payload_name(payload)
  assert_eq(name, Some("Alice"))
}

///|
test "extract_payload_name: returns None for missing name" {
  let payload = Json::object({ "content": Json::string("Hello") })
  let name = extract_payload_name(payload)
  assert_eq(name, None)
}

///|
test "extract_tool_result_payload: extracts call_id and content" {
  let payload = Json::object({
    "call_id": Json::string("call_123"),
    "content": Json::string("Tool result"),
  })
  let (call_id, content) = extract_tool_result_payload(payload)
  assert_eq(call_id, "call_123")
  assert_eq(content, "Tool result")
}

///|
test "extract_payload_has_tool_calls: extracts true" {
  let payload = Json::object({ "has_tool_calls": Json::boolean(true) })
  assert_true(extract_payload_has_tool_calls(payload))
}

///|
test "extract_payload_has_tool_calls: extracts false when missing" {
  let payload = Json::object({ "content": Json::string("Hello") })
  assert_false(extract_payload_has_tool_calls(payload))
}

///|
test "extract_tool_call_payload: extracts all fields" {
  let payload = Json::object({
    "call_id": Json::string("call_123"),
    "tool_name": Json::string("my_tool"),
    "arguments": Json::object({ "param": Json::string("value") }),
  })
  let tool_call = extract_tool_call_payload(payload)
  assert_eq(tool_call.id, "call_123")
  assert_eq(tool_call.name, "my_tool")
}

///|
test "reconstruct_session_from_history: empty records returns empty session" {
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="chat_1",
    user_id=None,
  )
  let records : Array[@interfaces.HistoryRecord] = []
  let session = reconstruct_session_from_history(key, records)
  assert_eq(session.history.length(), 0)
  assert_eq(session.created_at, 0L)
}

///|
test "reconstruct_session_from_history: user message is reconstructed" {
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="chat_1",
    user_id=None,
  )
  let records : Array[@interfaces.HistoryRecord] = [
    {
      timestamp: 1000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::UserMessage,
      payload: Json::object({ "content": Json::string("Hello") }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)
  assert_eq(session.history.length(), 1)
  assert_eq(session.created_at, 1000L)
  match session.history[0] {
    @llm_types.ModelMessage::User(content~, ..) => assert_eq(content, "Hello")
    _ => fail("Expected User message")
  }
}

///|
test "reconstruct_session_from_history: ToolCall records populate AssistantMessage.tool_calls" {
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="chat_1",
    user_id=None,
  )
  let records : Array[@interfaces.HistoryRecord] = [
    {
      timestamp: 1000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::UserMessage,
      payload: Json::object({ "content": Json::string("What is the weather?") }),
    },
    {
      timestamp: 2000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string(""),
        "has_tool_calls": Json::boolean(true),
      }),
    },
    {
      timestamp: 2001L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolCall,
      payload: Json::object({
        "call_id": Json::string("call_001"),
        "tool_name": Json::string("get_weather"),
        "arguments": Json::object({ "city": Json::string("Tokyo") }),
      }),
    },
    {
      timestamp: 3000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolResult,
      payload: Json::object({
        "call_id": Json::string("call_001"),
        "content": Json::string("Sunny, 25°C"),
      }),
    },
    {
      timestamp: 4000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string("The weather in Tokyo is sunny, 25°C."),
        "has_tool_calls": Json::boolean(false),
      }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)

  // 4 messages: User, Assistant(with tool_calls), ToolResult, Assistant(final)
  assert_eq(session.history.length(), 4)

  // 2番目のメッセージは ToolCall を含む AssistantMessage
  match session.history[1] {
    @llm_types.ModelMessage::Assistant(content~, tool_calls~) => {
      assert_eq(content, "")
      match tool_calls {
        Some(calls) => {
          assert_eq(calls.length(), 1)
          assert_eq(calls[0].id, "call_001")
          assert_eq(calls[0].name, "get_weather")
        }
        None => fail("Expected tool_calls to be Some, but got None")
      }
    }
    _ => fail("Expected Assistant message at index 1")
  }

  // 3番目のメッセージは ToolResult
  match session.history[2] {
    @llm_types.ModelMessage::ToolResult(tool_call_id~, content~) => {
      assert_eq(tool_call_id, "call_001")
      assert_eq(content, "Sunny, 25°C")
    }
    _ => fail("Expected ToolResult message at index 2")
  }
}

///|
/// 回帰テスト: チェーンされたツールコール（複数回のツール呼び出し）
/// シナリオ: User → ToolCall1 → Result1 → ToolCall2 → Result2 → TextResponse
test "reconstruct_session_from_history: chained_tool_calls" {
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="chat_1",
    user_id=None,
  )
  let records : Array[@interfaces.HistoryRecord] = [
    // User
    {
      timestamp: 1000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::UserMessage,
      payload: Json::object({
        "content": Json::string(
          "List files and then show me the content of the first file",
        ),
      }),
    },
    // Assistant: 1回目のツールコール (ls)
    {
      timestamp: 2000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string(""),
        "has_tool_calls": Json::boolean(true),
      }),
    },
    {
      timestamp: 2001L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolCall,
      payload: Json::object({
        "call_id": Json::string("fc_001"),
        "tool_name": Json::string("shell"),
        "arguments": Json::object({ "command": Json::string("ls") }),
      }),
    },
    // ToolResult
    {
      timestamp: 3000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolResult,
      payload: Json::object({
        "call_id": Json::string("fc_001"),
        "content": Json::string("README.md\nconfig.json\nmain.py"),
      }),
    },
    // Assistant: 2回目のツールコール (cat README.md) - チェーン
    {
      timestamp: 4000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string(""),
        "has_tool_calls": Json::boolean(true),
      }),
    },
    {
      timestamp: 4001L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolCall,
      payload: Json::object({
        "call_id": Json::string("fc_002"),
        "tool_name": Json::string("shell"),
        "arguments": Json::object({ "command": Json::string("cat README.md") }),
      }),
    },
    // ToolResult
    {
      timestamp: 5000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolResult,
      payload: Json::object({
        "call_id": Json::string("fc_002"),
        "content": Json::string("# My Project\n\nThis is a sample project."),
      }),
    },
    // Assistant: 最終テキスト応答
    {
      timestamp: 6000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string("Here are the files and the README content..."),
        "has_tool_calls": Json::boolean(false),
      }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)

  // 6 messages: User, Assistant(tc1), ToolResult1, Assistant(tc2), ToolResult2, Assistant(text)
  assert_eq(session.history.length(), 6)

  // 2番目: Assistant with tool_calls (fc_001)
  match session.history[1] {
    @llm_types.ModelMessage::Assistant(content~, tool_calls~) => {
      assert_eq(content, "")
      match tool_calls {
        Some(calls) => {
          assert_eq(calls.length(), 1)
          assert_eq(calls[0].id, "fc_001")
          assert_eq(calls[0].name, "shell")
        }
        None => fail("Expected tool_calls for fc_001")
      }
    }
    _ => fail("Expected Assistant message at index 1")
  }

  // 4番目: Assistant with tool_calls (fc_002) - チェーンされた2回目
  match session.history[3] {
    @llm_types.ModelMessage::Assistant(content~, tool_calls~) => {
      assert_eq(content, "")
      match tool_calls {
        Some(calls) => {
          assert_eq(calls.length(), 1)
          assert_eq(calls[0].id, "fc_002")
          assert_eq(calls[0].name, "shell")
        }
        None => fail("Expected tool_calls for fc_002")
      }
    }
    _ => fail("Expected Assistant message at index 3")
  }

  // 6番目: Assistant (final text)
  match session.history[5] {
    @llm_types.ModelMessage::Assistant(content~, tool_calls~) => {
      assert_true(content.contains("files"))
      assert_true(tool_calls is None)
    }
    _ => fail("Expected Assistant message at index 5")
  }
}

///|
/// 回帰テスト: 2ターン目のフォローアップ質問
/// シナリオ: Turn1(User→TC→Result→Text) → Turn2(User follow-up)
/// これは元のバグ「2ターン目で ModelCallFailed」の再現テスト
test "reconstruct_session_from_history: two_phase_with_follow_up" {
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="chat_1",
    user_id=None,
  )
  let records : Array[@interfaces.HistoryRecord] = [
    // Turn 1: User asks
    {
      timestamp: 1000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::UserMessage,
      payload: Json::object({ "content": Json::string("List files") }),
    },
    // Turn 1: Assistant calls tool
    {
      timestamp: 2000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string(""),
        "has_tool_calls": Json::boolean(true),
      }),
    },
    {
      timestamp: 2001L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolCall,
      payload: Json::object({
        "call_id": Json::string("fc_abc123"),
        "tool_name": Json::string("shell"),
        "arguments": Json::object({ "command": Json::string("ls") }),
      }),
    },
    // Turn 1: Tool result
    {
      timestamp: 3000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolResult,
      payload: Json::object({
        "call_id": Json::string("fc_abc123"),
        "content": Json::string("file1.txt\nfile2.txt"),
      }),
    },
    // Turn 1: Assistant text response (after tool)
    {
      timestamp: 4000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string("Here are the files: file1.txt, file2.txt"),
        "has_tool_calls": Json::boolean(false),
      }),
    },
    // Turn 2: User follow-up (THIS IS WHERE THE BUG OCCURRED)
    {
      timestamp: 5000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::UserMessage,
      payload: Json::object({
        "content": Json::string("Now show details with ls -la"),
      }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)

  // 5 messages: User, Assistant(tc), ToolResult, Assistant(text), User(follow-up)
  assert_eq(session.history.length(), 5)

  // 重要: 2番目の AssistantMessage に tool_calls が正しく復元されていること
  match session.history[1] {
    @llm_types.ModelMessage::Assistant(tool_calls~, ..) =>
      match tool_calls {
        Some(calls) => {
          assert_eq(calls.length(), 1)
          assert_eq(calls[0].id, "fc_abc123")
          assert_eq(calls[0].name, "shell")
        }
        None =>
          fail(
            "CRITICAL: tool_calls is None! This causes 'Tools should have a name' error",
          )
      }
    _ => fail("Expected Assistant message at index 1")
  }

  // 最後のメッセージがフォローアップ User
  match session.history[4] {
    @llm_types.ModelMessage::User(content~, ..) =>
      assert_eq(content, "Now show details with ls -la")
    _ => fail("Expected User message at index 4")
  }
}

///|
/// 回帰テスト: 純粋テキスト会話の継続（ツール呼び出しなし）
/// シナリオ: Turn1(User→Text) → Turn2(User follow-up)
/// これは「2ターン目で ModelCallFailed」バグの再現テスト（純粋テキスト版）
test "reconstruct_session_from_history: text_only_conversation_continuation" {
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="chat_text_only",
    user_id=None,
  )
  let records : Array[@interfaces.HistoryRecord] = [
    // Turn 1: User asks
    {
      timestamp: 1000L,
      session_id: "test:chat_text_only",
      record_type: @interfaces.HistoryRecordType::UserMessage,
      payload: Json::object({ "content": Json::string("ブースとラプう") }),
    },
    // Turn 1: Assistant responds with text only (no tool calls)
    {
      timestamp: 2000L,
      session_id: "test:chat_text_only",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string(
          "「ブースとラプう」について、もう少し詳しく教えてください。",
        ),
        "has_tool_calls": Json::boolean(false),
      }),
    },
    // Turn 2: User follow-up (THIS IS WHERE THE BUG OCCURRED)
    {
      timestamp: 3000L,
      session_id: "test:chat_text_only",
      record_type: @interfaces.HistoryRecordType::UserMessage,
      payload: Json::object({
        "content": Json::string("bootstrapって完了した？"),
      }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)

  // 3 messages: User, Assistant(text), User(follow-up)
  assert_eq(session.history.length(), 3)

  // 最初のメッセージが User
  match session.history[0] {
    @llm_types.ModelMessage::User(content~, ..) =>
      assert_eq(content, "ブースとラプう")
    _ => fail("Expected User message at index 0")
  }

  // 2番目のメッセージが Assistant (text only, no tool_calls)
  match session.history[1] {
    @llm_types.ModelMessage::Assistant(content~, tool_calls~) => {
      assert_eq(
        content, "「ブースとラプう」について、もう少し詳しく教えてください。",
      )
      // CRITICAL: 純粋テキスト会話では tool_calls は None であること
      // これが Some([]) になっていると、Responses API で問題が発生する可能性がある
      match tool_calls {
        None => () // OK - expected
        Some(calls) =>
          if calls.is_empty() {
            // Some([]) も許容（空配列）
            ()
          } else {
            fail(
              "UNEXPECTED: tool_calls should be None or empty for text-only response",
            )
          }
      }
    }
    _ => fail("Expected Assistant message at index 1")
  }

  // 最後のメッセージが User follow-up
  match session.history[2] {
    @llm_types.ModelMessage::User(content~, ..) =>
      assert_eq(content, "bootstrapって完了した？")
    _ => fail("Expected User message at index 2")
  }
}
