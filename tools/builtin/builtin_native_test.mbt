///|
/// Native-specific tests for builtin tools
/// Tests datetime, memory, spawn, message tools and time FFI

// ============================================================================
// Time Function Tests (Native FFI)
// ============================================================================

///|
test "get_current_time_ms returns positive value after 2020" {
  let ts = get_current_time_ms()
  // Should be after 2020-01-01 (1577836800000 ms)
  assert_true(ts > 1577836800000L)
}

///|
test "get_current_time_seconds returns positive value after 2020" {
  let ts = get_current_time_seconds()
  // Should be after 2020-01-01 (1577836800 seconds)
  assert_true(ts > 1577836800L)
}

///|
test "get_current_time_ms and seconds are consistent" {
  let ms = get_current_time_ms()
  let sec = get_current_time_seconds()
  // ms/1000 should equal seconds (within 1 second tolerance)
  let diff = (ms / 1000L) - sec
  assert_true(diff >= -1L && diff <= 1L)
}

///|
test "get_current_time_ms is monotonic" {
  let ts1 = get_current_time_ms()
  let ts2 = get_current_time_ms()
  // ts2 should be >= ts1
  assert_true(ts2 >= ts1)
  // And shouldn't be too far apart (within 1 second)
  assert_true(ts2 - ts1 < 1000L)
}

// ============================================================================
// DateTime Tool Tests (Native)
// ============================================================================

///|
test "datetime tool now action returns valid timestamp" {
  let args : Json = { "action": "now" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "timestamp_ms": Number(ts, ..), .. } => {
          // Timestamp should be a positive number after year 2020
          let ts_int = ts.to_int64()
          assert_true(ts_int > 1577836800000L)
        }
        _ => fail("Expected timestamp_ms in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "datetime tool timestamp action returns valid timestamp" {
  let args : Json = { "action": "timestamp" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "timestamp": Number(ts, ..), .. } => {
          let ts_int = ts.to_int64()
          assert_true(ts_int > 1577836800000L)
        }
        _ => fail("Expected timestamp in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "datetime tool format action with ISO8601" {
  let args : Json = { "action": "format", "format": "ISO8601" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "formatted": String(formatted), .. } => {
          // ISO8601 format: YYYY-MM-DDTHH:MM:SS.mmmZ
          assert_true(formatted.length() > 0)
          assert_true(formatted.contains("T"))
          assert_true(formatted.contains("Z"))
        }
        _ => fail("Expected formatted in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "datetime tool format action with UNIX" {
  let args : Json = { "action": "format", "format": "UNIX" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "formatted": String(formatted), .. } => {
          // UNIX timestamp should be a number string (10+ digits for current epoch)
          assert_true(formatted.length() >= 10)
        }
        _ => fail("Expected formatted in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "datetime tool missing action returns error" {
  let args : Json = {}
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error status for missing action")
  }
}

///|
test "datetime tool unknown action returns error" {
  let args : Json = { "action": "unknown" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error status for unknown action")
  }
}

// ============================================================================
// Memory Tool Tests (Native)
// ============================================================================

///|
test "memory store set and get" {
  let store = MemoryStore::new()
  store.set("key1", Json::string("value1"))
  match store.get("key1") {
    Some(String(v)) => assert_eq(v, "value1")
    _ => fail("Expected to get stored value")
  }
}

///|
test "memory store get nonexistent key returns None" {
  let store = MemoryStore::new()
  match store.get("nonexistent") {
    None => ()
    Some(_) => fail("Expected None for nonexistent key")
  }
}

///|
test "memory store delete existing key" {
  let store = MemoryStore::new()
  store.set("key1", Json::string("value1"))
  let deleted = store.delete("key1")
  assert_true(deleted)
  match store.get("key1") {
    None => ()
    Some(_) => fail("Expected key to be deleted")
  }
}

///|
test "memory store delete nonexistent key returns false" {
  let store = MemoryStore::new()
  let deleted = store.delete("nonexistent")
  assert_true(not(deleted))
}

///|
test "memory store keys returns all keys" {
  let store = MemoryStore::new()
  store.set("a", Json::number(1))
  store.set("b", Json::number(2))
  store.set("c", Json::number(3))
  let keys = store.keys()
  assert_eq(keys.length(), 3)
}

///|
test "memory store clear removes all entries" {
  let store = MemoryStore::new()
  store.set("a", Json::number(1))
  store.set("b", Json::number(2))
  store.clear()
  assert_eq(store.keys().length(), 0)
}

///|
test "memory store has returns correct value" {
  let store = MemoryStore::new()
  store.set("exists", Json::number(1))
  assert_true(store.has("exists"))
  assert_true(not(store.has("not_exists")))
}

///|
test "memory tool set action" {
  let store = MemoryStore::new()
  let args : Json = { "action": "set", "key": "test_key", "value": "test_value" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match store.get("test_key") {
        Some(String(v)) => assert_eq(v, "test_value")
        _ => fail("Value not stored correctly")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "memory tool get action" {
  let store = MemoryStore::new()
  store.set("test_key", Json::string("test_value"))
  let args : Json = { "action": "get", "key": "test_key" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "value": String(v), .. } => assert_eq(v, "test_value")
        _ => fail("Expected value in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "memory tool get nonexistent key returns error" {
  let store = MemoryStore::new()
  let args : Json = { "action": "get", "key": "nonexistent" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for nonexistent key")
  }
}

///|
test "memory tool list action" {
  let store = MemoryStore::new()
  store.set("a", Json::number(1))
  store.set("b", Json::number(2))
  let args : Json = { "action": "list" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "count": Number(count, ..), .. } => assert_eq(count.to_int(), 2)
        _ => fail("Expected count in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "memory tool search action" {
  let store = MemoryStore::new()
  store.set("user_name", Json::string("Alice"))
  store.set("user_age", Json::number(30))
  store.set("settings", Json::string("dark"))
  let args : Json = { "action": "search", "query": "user" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "count": Number(count, ..), .. } => assert_eq(count.to_int(), 2)
        _ => fail("Expected count in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "memory tool delete action" {
  let store = MemoryStore::new()
  store.set("to_delete", Json::number(1))
  let args : Json = { "action": "delete", "key": "to_delete" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "deleted": True, .. } => ()
        { "deleted": False, .. } => fail("Expected deleted to be true")
        _ => fail("Expected deleted in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

// ============================================================================
// Spawn Tool Tests (Native)
// ============================================================================

///|
test "spawn tool create action" {
  let manager = SubAgentManager::new()
  let args : Json = {
    "action": "create",
    "name": "test_agent",
    "message": "Hello agent",
  }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "agent_id": String(id), "status": String(status), .. } => {
          assert_true(id.has_prefix("agent_"))
          assert_eq(status, "created")
        }
        _ => fail("Expected agent_id and status in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "spawn tool status action" {
  let manager = SubAgentManager::new()
  // First create an agent
  let create_args : Json = { "action": "create", "message": "test" }
  let create_result = execute_spawn_tool(manager, create_args)
  let agent_id = match create_result.data {
    { "agent_id": String(id), .. } => id
    _ => {
      fail("Failed to create agent")
      return
    }
  }
  // Now check status
  let status_args : Json = { "action": "status", "agent_id": agent_id }
  let result = execute_spawn_tool(manager, status_args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "status": String(status), .. } => assert_eq(status, "created")
        _ => fail("Expected status in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "spawn tool cancel action" {
  let manager = SubAgentManager::new()
  // First create an agent
  let create_args : Json = { "action": "create", "message": "test" }
  let create_result = execute_spawn_tool(manager, create_args)
  let agent_id = match create_result.data {
    { "agent_id": String(id), .. } => id
    _ => {
      fail("Failed to create agent")
      return
    }
  }
  // Now cancel it
  let cancel_args : Json = { "action": "cancel", "agent_id": agent_id }
  let result = execute_spawn_tool(manager, cancel_args)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match result.data {
        { "status": String(status), .. } => assert_eq(status, "cancelled")
        _ => fail("Expected status in result data")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "spawn tool status for nonexistent agent returns error" {
  let manager = SubAgentManager::new()
  let args : Json = { "action": "status", "agent_id": "nonexistent" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for nonexistent agent")
  }
}

///|
test "spawn tool generate_id increments" {
  let manager = SubAgentManager::new()
  let id1 = manager.generate_id()
  let id2 = manager.generate_id()
  let id3 = manager.generate_id()
  assert_eq(id1, "agent_1")
  assert_eq(id2, "agent_2")
  assert_eq(id3, "agent_3")
}

// ============================================================================
// Message Tool Tests (Native)
// ============================================================================

///|
test "message tool send action" {
  let mut sent_message : @types.OutboundMessage? = None
  let send_fn = fn(msg : @types.OutboundMessage) { sent_message = Some(msg) }
  let args : Json = {
    "action": "send",
    "channel": "test_channel",
    "chat_id": "test_chat",
    "content": "Hello world",
  }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match sent_message {
        Some(msg) => {
          assert_eq(msg.channel, "test_channel")
          assert_eq(msg.chat_id, "test_chat")
          assert_eq(msg.content, "Hello world")
        }
        None => fail("Message was not sent")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "message tool reply action" {
  let mut sent_message : @types.OutboundMessage? = None
  let send_fn = fn(msg : @types.OutboundMessage) { sent_message = Some(msg) }
  let args : Json = {
    "action": "reply",
    "channel": "test_channel",
    "chat_id": "test_chat",
    "content": "Reply content",
    "message_id": "original_msg_123",
  }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Success => {
      match sent_message {
        Some(msg) => {
          assert_eq(msg.content, "Reply content")
          match msg.reply_to {
            Some(reply_to) => assert_eq(reply_to, "original_msg_123")
            None => fail("Expected reply_to to be set")
          }
        }
        None => fail("Message was not sent")
      }
    }
    _ => fail("Expected success status")
  }
}

///|
test "message tool missing channel returns error" {
  let send_fn = fn(_msg : @types.OutboundMessage) { () }
  let args : Json = { "action": "send", "chat_id": "test", "content": "test" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for missing channel")
  }
}

///|
test "message tool missing chat_id returns error" {
  let send_fn = fn(_msg : @types.OutboundMessage) { () }
  let args : Json = { "action": "send", "channel": "test", "content": "test" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for missing chat_id")
  }
}

///|
test "message tool missing content returns error" {
  let send_fn = fn(_msg : @types.OutboundMessage) { () }
  let args : Json = { "action": "send", "channel": "test", "chat_id": "test" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for missing content")
  }
}

///|
test "message tool edit action returns not implemented error" {
  let send_fn = fn(_msg : @types.OutboundMessage) { () }
  let args : Json = { "action": "edit" }
  let result = execute_message_tool(args, send_fn)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for edit action")
  }
}

///|
test "build_outbound_message creates correct message" {
  let msg = build_outbound_message("ch1", "chat1", "hello", Some("reply_id"))
  assert_eq(msg.channel, "ch1")
  assert_eq(msg.chat_id, "chat1")
  assert_eq(msg.content, "hello")
  match msg.reply_to {
    Some(r) => assert_eq(r, "reply_id")
    None => fail("Expected reply_to")
  }
}

// ============================================================================
// Dispatch Tests (Native)
// ============================================================================

///|
test "has_builtin_tool returns true for known tools" {
  assert_true(has_builtin_tool("datetime"))
  assert_true(has_builtin_tool("memory"))
  assert_true(has_builtin_tool("spawn"))
  assert_true(has_builtin_tool("message"))
}

///|
test "has_builtin_tool returns false for unknown tools" {
  assert_true(not(has_builtin_tool("unknown")))
  assert_true(not(has_builtin_tool("")))
  assert_true(not(has_builtin_tool("DateTime")))
}

///|
test "is_sync_builtin_tool returns true for all builtin tools" {
  assert_true(is_sync_builtin_tool("datetime"))
  assert_true(is_sync_builtin_tool("memory"))
  assert_true(is_sync_builtin_tool("spawn"))
  assert_true(is_sync_builtin_tool("message"))
}

///|
test "execute_builtin_tool returns None for unknown tool" {
  let ctx = BuiltinToolContext::new(fn(_msg) { () })
  let result = execute_builtin_tool(ctx, "unknown", {})
  match result {
    None => ()
    Some(_) => fail("Expected None for unknown tool")
  }
}

///|
test "execute_builtin_tool dispatches to datetime tool" {
  let ctx = BuiltinToolContext::new(fn(_msg) { () })
  let result = execute_builtin_tool(ctx, "datetime", { "action": "now" })
  match result {
    Some(r) =>
      match r.status {
        @defs.ToolResultStatus::Success => ()
        _ => fail("Expected success from datetime tool")
      }
    None => fail("Expected Some for datetime tool")
  }
}

///|
test "execute_builtin_tool dispatches to memory tool" {
  let ctx = BuiltinToolContext::new(fn(_msg) { () })
  let _ = execute_builtin_tool(
    ctx,
    "memory",
    { "action": "set", "key": "k", "value": "v" },
  )
  let result = execute_builtin_tool(
    ctx,
    "memory",
    { "action": "get", "key": "k" },
  )
  match result {
    Some(r) =>
      match r.status {
        @defs.ToolResultStatus::Success => ()
        _ => fail("Expected success from memory tool")
      }
    None => fail("Expected Some for memory tool")
  }
}

// ============================================================================
// Helper
// ============================================================================

///|
fn assert_true(condition : Bool) -> Unit raise {
  if not(condition) {
    fail("Assertion failed: expected true")
  }
}
