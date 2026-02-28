///|
/// Builtin Tools Tests (Agent-internal tools only)

// =============================================================================
// Memory Tool Tests
// =============================================================================

///|
test "MemoryStore::new creates empty store" {
  let store = MemoryStore::new()
  inspect(store.keys().length(), content="0")
}

///|
test "MemoryStore::set and get work correctly" {
  let store = MemoryStore::new()
  store.set("key1", { "data": "value" })
  match store.get("key1") {
    Some({ "data": "value", .. }) => ()
    _ => fail("Expected stored value")
  }
  inspect(store.get("missing"), content="None")
}

///|
test "MemoryStore::has returns correct values" {
  let store = MemoryStore::new()
  inspect(store.has("key"), content="false")
  store.set("key", { "value": 1 })
  inspect(store.has("key"), content="true")
}

///|
test "MemoryStore::delete removes entries" {
  let store = MemoryStore::new()
  store.set("key", { "value": 1 })
  inspect(store.delete("key"), content="true")
  inspect(store.has("key"), content="false")
  inspect(store.delete("nonexistent"), content="false")
}

///|
test "MemoryStore::keys returns all keys" {
  let store = MemoryStore::new()
  store.set("a", { "v": 1 })
  store.set("b", { "v": 2 })
  store.set("c", { "v": 3 })
  let keys = store.keys()
  inspect(keys.length(), content="3")
}

///|
test "MemoryStore::clear removes all entries" {
  let store = MemoryStore::new()
  store.set("a", { "v": 1 })
  store.set("b", { "v": 2 })
  store.clear()
  inspect(store.keys().length(), content="0")
}

///|
test "execute_memory_tool get action retrieves value" {
  let store = MemoryStore::new()
  store.set("mykey", { "myvalue": 42 })
  let args : Json = { "action": "get", "key": "mykey" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
}

///|
test "execute_memory_tool get action returns error for missing key" {
  let store = MemoryStore::new()
  let args : Json = { "action": "get", "key": "missing" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

///|
test "execute_memory_tool set action stores value" {
  let store = MemoryStore::new()
  let args : Json = {
    "action": "set",
    "key": "newkey",
    "value": { "data": "test" },
  }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  inspect(store.has("newkey"), content="true")
}

///|
test "execute_memory_tool delete action removes entry" {
  let store = MemoryStore::new()
  store.set("toremove", { "v": 1 })
  let args : Json = { "action": "delete", "key": "toremove" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  inspect(store.has("toremove"), content="false")
}

///|
test "execute_memory_tool list action returns all keys" {
  let store = MemoryStore::new()
  store.set("k1", { "v": 1 })
  store.set("k2", { "v": 2 })
  let args : Json = { "action": "list" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "count": Number(count, ..), .. } =>
      assert_true(count > 1.0 && count < 3.0)
    _ => fail("Expected count in data")
  }
}

///|
test "execute_memory_tool search action finds matching keys" {
  let store = MemoryStore::new()
  store.set("user_alice", { "name": "Alice" })
  store.set("user_bob", { "name": "Bob" })
  store.set("config", { "setting": 1 })
  let args : Json = { "action": "search", "query": "user" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "count": Number(count, ..), .. } =>
      assert_true(count > 1.0 && count < 3.0)
    _ => fail("Expected count in data")
  }
}

///|
test "execute_memory_tool returns error for missing action" {
  let store = MemoryStore::new()
  let args : Json = { "key": "value" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

///|
test "execute_memory_tool returns error for unknown action" {
  let store = MemoryStore::new()
  let args : Json = { "action": "invalid_action" }
  let result = execute_memory_tool(store, args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

// =============================================================================
// DateTime Tool Tests
// =============================================================================

///|
extern "js" fn js_to_iso8601(ms : Double) -> String =
  #|(ms) => {
  #|  if (!Number.isFinite(ms)) return `invalid:${String(ms)}`;
  #|  const d = new Date(ms);
  #|  return Number.isNaN(d.getTime()) ? `invalid:${String(ms)}` : d.toISOString();
  #|}

///|
test "get_current_time_seconds returns non-negative value" {
  let seconds = get_current_time_seconds()
  assert_true(seconds >= 0L)
}

///|
test "execute_datetime_tool now action returns timestamp" {
  let args : Json = { "action": "now" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "timestamp_ms": Number(_), "iso8601": String(_), .. } => ()
    _ => fail("Expected timestamp data")
  }
}

///|
test "execute_datetime_tool timestamp action returns unix timestamp" {
  let args : Json = { "action": "timestamp" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "timestamp": Number(_), .. } => ()
    _ => fail("Expected timestamp in data")
  }
}

///|
test "execute_datetime_tool format action returns formatted string" {
  let args : Json = { "action": "format", "format": "ISO8601" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "formatted": String(s), .. } => assert_true(s.length() > 0)
    _ => fail("Expected formatted string in data")
  }
}

///|
test "execute_datetime_tool now action matches Node.js ISO8601" {
  let args : Json = { "action": "now" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "timestamp_ms": Number(ms, ..), "iso8601": String(iso), .. } =>
      inspect(iso, content=js_to_iso8601(ms))
    _ => fail("Expected timestamp and iso8601")
  }
}

///|
test "execute_datetime_tool returns error for missing action" {
  let args : Json = { "format": "ISO8601" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

///|
test "execute_datetime_tool returns error for unknown action" {
  let args : Json = { "action": "invalid" }
  let result = execute_datetime_tool(args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

// =============================================================================
// Spawn Tool Tests
// =============================================================================

///|
test "SubAgentConfig::default has reasonable values" {
  let config = SubAgentConfig::default(name="test")
  inspect(config.name, content="test")
  inspect(config.max_turns, content="10")
  assert_true(config.system_prompt.length() > 0)
}

///|
test "SubAgentManager::new creates empty manager" {
  let manager = SubAgentManager::new()
  inspect(manager.next_id, content="1")
}

///|
test "SubAgentManager::generate_id increments counter" {
  let manager = SubAgentManager::new()
  let id1 = manager.generate_id()
  let id2 = manager.generate_id()
  inspect(id1, content="agent_1")
  inspect(id2, content="agent_2")
  inspect(manager.next_id, content="3")
}

///|
test "execute_spawn_tool create action creates agent" {
  let manager = SubAgentManager::new()
  let args : Json = {
    "action": "create",
    "name": "test_agent",
    "message": "Do something",
  }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "agent_id": String(id), "status": "created", .. } =>
      inspect(id, content="agent_1")
    _ => fail("Expected agent_id in result")
  }
}

///|
test "execute_spawn_tool create action requires message" {
  let manager = SubAgentManager::new()
  let args : Json = { "action": "create", "name": "test" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

///|
test "execute_spawn_tool status action returns agent status" {
  let manager = SubAgentManager::new()
  let create_args : Json = { "action": "create", "message": "task" }
  ignore(execute_spawn_tool(manager, create_args))
  let args : Json = { "action": "status", "agent_id": "agent_1" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "agent_id": "agent_1", "status": "created", .. } => ()
    _ => fail("Expected agent data")
  }
}

///|
test "execute_spawn_tool status action returns error for unknown agent" {
  let manager = SubAgentManager::new()
  let args : Json = { "action": "status", "agent_id": "unknown" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

///|
test "execute_spawn_tool cancel action cancels agent" {
  let manager = SubAgentManager::new()
  let create_args : Json = { "action": "create", "message": "task" }
  ignore(execute_spawn_tool(manager, create_args))
  let args : Json = { "action": "cancel", "agent_id": "agent_1" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "status": "cancelled", .. } => ()
    _ => fail("Expected cancelled status")
  }
}

///|
test "execute_spawn_tool result action returns agent result" {
  let manager = SubAgentManager::new()
  let create_args : Json = { "action": "create", "message": "task" }
  ignore(execute_spawn_tool(manager, create_args))
  let args : Json = { "action": "result", "agent_id": "agent_1" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
}

///|
test "execute_spawn_tool returns error for missing action" {
  let manager = SubAgentManager::new()
  let args : Json = { "name": "test" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

///|
test "execute_spawn_tool returns error for unknown action" {
  let manager = SubAgentManager::new()
  let args : Json = { "action": "invalid" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

// =============================================================================
// Dispatch Tests
// =============================================================================

///|
test "has_builtin_tool returns true for agent tools" {
  assert_true(has_builtin_tool("datetime"))
  assert_true(has_builtin_tool("memory"))
  assert_true(has_builtin_tool("spawn"))
  assert_true(has_builtin_tool("message"))
  assert_true(not(has_builtin_tool("web")))
  assert_true(not(has_builtin_tool("shell")))
  assert_true(not(has_builtin_tool("filesystem")))
  assert_true(not(has_builtin_tool("nonexistent")))
}

// =============================================================================
// Helper
// =============================================================================

///|
fn assert_true(condition : Bool) -> Unit raise {
  if not(condition) {
    fail("Assertion failed: expected true")
  }
}
