///|
/// NativeSessionManager テスト

// ============================================================
// reconstruct_session_from_history テスト
// ============================================================

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
test "reconstruct_session_from_history: SessionMeta is ignored in history" {
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="chat_1",
    user_id=None,
  )
  let records : Array[@interfaces.HistoryRecord] = [
    {
      timestamp: 1000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::SessionMeta,
      payload: Json::object({
        "channel": Json::string("test"),
        "chat_id": Json::string("chat_1"),
      }),
    },
    {
      timestamp: 2000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::UserMessage,
      payload: Json::object({ "content": Json::string("Hello") }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)
  // SessionMeta is not added to history
  assert_eq(session.history.length(), 1)
  // But timestamps should include SessionMeta
  assert_eq(session.created_at, 1000L)
  assert_eq(session.last_active_at, 2000L)
}

// ============================================================
// NativeSessionManager コンストラクタとキャッシュのテスト
// ============================================================

///|
test "NativeSessionManager::new creates manager with empty cache" {
  let mgr = NativeSessionManager::new(
    base_dir="\{@osenv_dirs.temp_dir()}/test",
    cache_max_size=10,
  )
  assert_eq(mgr.base_dir, "\{@osenv_dirs.temp_dir()}/test")
  assert_eq(mgr.cache_max_size, 10)
  assert_eq(mgr.cache.length(), 0)
}

///|
test "add_to_cache: adds session to cache" {
  let mgr = NativeSessionManager::new(
    base_dir="\{@osenv_dirs.temp_dir()}/test",
    cache_max_size=10,
  )
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="chat_1",
    user_id=None,
  )
  let session = @types.Session::new(key, 1000L)
  mgr.add_to_cache(key, session)
  assert_eq(mgr.cache.length(), 1)
  assert_true(mgr.cache.contains(key))
}

///|
test "add_to_cache: evicts all when cache is full" {
  let mgr = NativeSessionManager::new(
    base_dir="\{@osenv_dirs.temp_dir()}/test",
    cache_max_size=2,
  )
  // Add 2 sessions
  let key1 = @types.SessionKey::new(
    channel="test",
    chat_id="chat_1",
    user_id=None,
  )
  let key2 = @types.SessionKey::new(
    channel="test",
    chat_id="chat_2",
    user_id=None,
  )
  mgr.add_to_cache(key1, @types.Session::new(key1, 1000L))
  mgr.add_to_cache(key2, @types.Session::new(key2, 2000L))
  assert_eq(mgr.cache.length(), 2)
  // Add 3rd session - should trigger eviction
  let key3 = @types.SessionKey::new(
    channel="test",
    chat_id="chat_3",
    user_id=None,
  )
  mgr.add_to_cache(key3, @types.Session::new(key3, 3000L))
  // Simplified LRU: all previous entries cleared, only new one remains
  assert_eq(mgr.cache.length(), 1)
  assert_true(mgr.cache.contains(key3))
}

// ============================================================
// SessionManager trait 実装テスト
// ============================================================

///|
test "get: returns None for non-existent session" {
  let mgr = NativeSessionManager::new(
    base_dir="\{@osenv_dirs.temp_dir()}/non_existent_dir_test",
    cache_max_size=10,
  )
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="non_existent",
    user_id=None,
  )
  let result = mgr.get(key) catch { _ => None }
  assert_true(result is None)
}

///|
test "get: returns cached session" {
  let mgr = NativeSessionManager::new(
    base_dir="\{@osenv_dirs.temp_dir()}/test",
    cache_max_size=10,
  )
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="cached",
    user_id=None,
  )
  let session = @types.Session::new(key, 1000L)
  mgr.add_to_cache(key, session)
  let result = mgr.get(key) catch { _ => None }
  assert_true(result is Some(_))
}

///|
test "get_or_create: creates new session with correct timestamp" {
  let mgr = NativeSessionManager::new(
    base_dir="\{@osenv_dirs.temp_dir()}/non_existent_test_dir",
    cache_max_size=10,
  )
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="new_session",
    user_id=None,
  )
  let result = mgr.get_or_create(key, now=5000L) catch {
    e => fail("get_or_create failed: \{e}")
  }
  assert_eq(result.key, key)
  assert_eq(result.created_at, 5000L)
  // Session should be in cache
  assert_true(mgr.cache.contains(key))
}

///|
test "delete: removes session from cache" {
  let mgr = NativeSessionManager::new(
    base_dir="\{@osenv_dirs.temp_dir()}/test",
    cache_max_size=10,
  )
  let key = @types.SessionKey::new(
    channel="test",
    chat_id="to_delete",
    user_id=None,
  )
  let session = @types.Session::new(key, 1000L)
  mgr.add_to_cache(key, session)
  assert_true(mgr.cache.contains(key))
  mgr.delete(key) catch {
    _ => ()
  }
  assert_false(mgr.cache.contains(key))
}

///|
test "list_keys: returns cached keys when no metadata store" {
  let mgr = NativeSessionManager::new(
    base_dir="\{@osenv_dirs.temp_dir()}/test",
    cache_max_size=10,
  )
  let key1 = @types.SessionKey::new(
    channel="test",
    chat_id="chat_1",
    user_id=None,
  )
  let key2 = @types.SessionKey::new(
    channel="test",
    chat_id="chat_2",
    user_id=None,
  )
  mgr.add_to_cache(key1, @types.Session::new(key1, 1000L))
  mgr.add_to_cache(key2, @types.Session::new(key2, 2000L))
  let keys = mgr.list_keys() catch { e => fail("list_keys failed: \{e}") }
  assert_eq(keys.length(), 2)
}

// ============================================================
// ToolCall 復元テスト (回帰テスト)
// reconstruct_session_from_history で ToolCall が復元されることを検証
// ============================================================

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
test "reconstruct_session_from_history: multiple ToolCalls in single AssistantMessage" {
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
      payload: Json::object({
        "content": Json::string("Get weather for Tokyo and Osaka"),
      }),
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
      timestamp: 2002L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolCall,
      payload: Json::object({
        "call_id": Json::string("call_002"),
        "tool_name": Json::string("get_weather"),
        "arguments": Json::object({ "city": Json::string("Osaka") }),
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
      timestamp: 3001L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::ToolResult,
      payload: Json::object({
        "call_id": Json::string("call_002"),
        "content": Json::string("Cloudy, 22°C"),
      }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)

  // 4 messages: User, Assistant(with 2 tool_calls), ToolResult x2
  assert_eq(session.history.length(), 4)

  // AssistantMessage に 2つの ToolCall が含まれる
  match session.history[1] {
    @llm_types.ModelMessage::Assistant(tool_calls~, ..) =>
      match tool_calls {
        Some(calls) => {
          assert_eq(calls.length(), 2)
          assert_eq(calls[0].id, "call_001")
          assert_eq(calls[1].id, "call_002")
        }
        None => fail("Expected tool_calls to be Some, but got None")
      }
    _ => fail("Expected Assistant message at index 1")
  }
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
/// 根本原因3: has_tool_calls: false の場合、tool_calls は None であること
test "reconstruct_session_from_history: has_tool_calls false means tool_calls is None" {
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
    {
      timestamp: 2000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string("Hi there!"),
        "has_tool_calls": Json::boolean(false),
      }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)

  assert_eq(session.history.length(), 2)

  // has_tool_calls: false なので tool_calls は None
  match session.history[1] {
    @llm_types.ModelMessage::Assistant(content~, tool_calls~) => {
      assert_eq(content, "Hi there!")
      match tool_calls {
        None => () // 正しい: tool_calls は None
        Some(_) =>
          fail("Expected tool_calls to be None for has_tool_calls: false")
      }
    }
    _ => fail("Expected Assistant message at index 1")
  }
}

///|
/// 根本原因3: has_tool_calls フラグなしの旧形式データも正しく処理
test "reconstruct_session_from_history: missing has_tool_calls flag treated as false" {
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
    {
      timestamp: 2000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      // has_tool_calls フラグなし（旧形式）
      payload: Json::object({ "content": Json::string("Hi there!") }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)

  match session.history[1] {
    @llm_types.ModelMessage::Assistant(tool_calls~, ..) =>
      match tool_calls {
        None => () // 正しい: フラグなしは false 扱い
        Some(_) =>
          fail("Expected tool_calls to be None for missing has_tool_calls")
      }
    _ => fail("Expected Assistant message at index 1")
  }
}

///|
/// 根本原因2: ToolCall なしのシンプルな会話が正しく復元される
/// (回帰テスト: 既存の単純な User/Assistant 往復が壊れていないことを確認)
test "reconstruct_session_from_history: simple conversation without tools" {
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
    {
      timestamp: 2000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string("Hi!"),
        "has_tool_calls": Json::boolean(false),
      }),
    },
    {
      timestamp: 3000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::UserMessage,
      payload: Json::object({ "content": Json::string("How are you?") }),
    },
    {
      timestamp: 4000L,
      session_id: "test:chat_1",
      record_type: @interfaces.HistoryRecordType::AssistantMessage,
      payload: Json::object({
        "content": Json::string("I'm doing well, thank you!"),
        "has_tool_calls": Json::boolean(false),
      }),
    },
  ]
  let session = reconstruct_session_from_history(key, records)

  // 4 messages: User, Assistant, User, Assistant
  assert_eq(session.history.length(), 4)

  // 全てのメッセージが正しい型
  match session.history[0] {
    @llm_types.ModelMessage::User(content~, ..) => assert_eq(content, "Hello")
    _ => fail("Expected User message at index 0")
  }
  match session.history[1] {
    @llm_types.ModelMessage::Assistant(content~, tool_calls~) => {
      assert_eq(content, "Hi!")
      assert_true(tool_calls is None)
    }
    _ => fail("Expected Assistant message at index 1")
  }
  match session.history[2] {
    @llm_types.ModelMessage::User(content~, ..) =>
      assert_eq(content, "How are you?")
    _ => fail("Expected User message at index 2")
  }
  match session.history[3] {
    @llm_types.ModelMessage::Assistant(content~, ..) =>
      assert_eq(content, "I'm doing well, thank you!")
    _ => fail("Expected Assistant message at index 3")
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
    // User: ファイル一覧と最初のファイルの内容を見せて
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
    // ToolResult: ファイルリスト
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
    // ToolResult: ファイル内容
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

  // 1番目: User
  match session.history[0] {
    @llm_types.ModelMessage::User(content~, ..) =>
      assert_eq(
        content, "List files and then show me the content of the first file",
      )
    _ => fail("Expected User message at index 0")
  }

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

  // 3番目: ToolResult (fc_001)
  match session.history[2] {
    @llm_types.ModelMessage::ToolResult(tool_call_id~, content~) => {
      assert_eq(tool_call_id, "fc_001")
      assert_true(content.contains("README.md"))
    }
    _ => fail("Expected ToolResult at index 2")
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

  // 5番目: ToolResult (fc_002)
  match session.history[4] {
    @llm_types.ModelMessage::ToolResult(tool_call_id~, content~) => {
      assert_eq(tool_call_id, "fc_002")
      assert_true(content.contains("My Project"))
    }
    _ => fail("Expected ToolResult at index 4")
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
