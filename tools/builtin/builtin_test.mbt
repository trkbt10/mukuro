///|
/// Builtin Tools Tests

// =============================================================================
// ToolExecutionResult Tests
// =============================================================================

///|
test "ToolExecutionResult::success creates success result" {
  let result = ToolExecutionResult::success({ "key": "value" })
  match result.status {
    ToolResultStatus::Success => ()
    _ => fail("Expected Success status")
  }
  inspect(result.error_message, content="None")
}

///|
test "ToolExecutionResult::error creates error result" {
  let result = ToolExecutionResult::error("Something went wrong")
  match result.status {
    ToolResultStatus::Error => ()
    _ => fail("Expected Error status")
  }
  inspect(result.error_message, content="Some(\"Something went wrong\")")
}

///|
test "ToolExecutionResult::requires_confirmation creates confirmation result" {
  let result = ToolExecutionResult::requires_confirmation({ "action": "delete" })
  match result.status {
    ToolResultStatus::RequiresConfirmation => ()
    _ => fail("Expected RequiresConfirmation status")
  }
  inspect(result.error_message, content="None")
}

// =============================================================================
// Argument Helper Tests
// =============================================================================

///|
test "get_string_arg extracts string from JSON object" {
  let args : Json = { "name": "Alice", "age": 30 }
  inspect(get_string_arg(args, "name"), content="Some(\"Alice\")")
  inspect(get_string_arg(args, "missing"), content="None")
  inspect(get_string_arg(args, "age"), content="None")
}

///|
test "get_string_arg returns None for non-object JSON" {
  let args : Json = Json::array([])
  inspect(get_string_arg(args, "name"), content="None")
}

///|
test "require_string_arg raises error for missing argument" {
  let args : Json = { "other": "value" }
  let result : Result[String, ToolExecutionError] = Ok(
    require_string_arg(args, "name"),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(ToolExecutionError::InvalidArguments(msg)) =>
      assert_true(msg.contains("name"))
    _ => fail("Expected InvalidArguments error")
  }
}

///|
test "require_string_arg returns value for present argument" {
  let args : Json = { "name": "Bob" }
  let result = require_string_arg(args, "name") catch { _ => "" }
  inspect(result, content="Bob")
}

///|
test "get_int_arg extracts integer from JSON object" {
  let args : Json = { "count": 42, "name": "test" }
  inspect(get_int_arg(args, "count"), content="Some(42)")
  inspect(get_int_arg(args, "missing"), content="None")
  inspect(get_int_arg(args, "name"), content="None")
}

///|
test "get_bool_arg extracts boolean from JSON object" {
  let args : Json = { "active": true, "disabled": false, "name": "test" }
  inspect(get_bool_arg(args, "active"), content="Some(true)")
  inspect(get_bool_arg(args, "disabled"), content="Some(false)")
  inspect(get_bool_arg(args, "missing"), content="None")
  inspect(get_bool_arg(args, "name"), content="None")
}

///|
test "get_array_arg extracts array from JSON object" {
  let args : Json = {
    "items": Json::array([Json::number(1.0), Json::number(2.0)]),
    "name": "test",
  }
  match get_array_arg(args, "items") {
    Some(arr) => inspect(arr.length(), content="2")
    None => fail("Expected array")
  }
  inspect(get_array_arg(args, "missing"), content="None")
  inspect(get_array_arg(args, "name"), content="None")
}

// =============================================================================
// Schema Helper Tests
// =============================================================================

///|
test "make_tool_definition creates valid definition" {
  let def = make_tool_definition(name="test_tool", description="A test tool", parameters={
    "type": "object",
  })
  inspect(def.name, content="test_tool")
  inspect(def.description, content="A test tool")
}

///|
test "string_param creates string schema" {
  let schema = string_param("A description", true)
  match schema {
    { "type": "string", "description": "A description", .. } => ()
    _ => fail("Invalid schema")
  }
}

///|
test "integer_param creates integer schema" {
  let schema = integer_param("Count of items")
  match schema {
    { "type": "integer", "description": "Count of items", .. } => ()
    _ => fail("Invalid schema")
  }
}

///|
test "boolean_param creates boolean schema" {
  let schema = boolean_param("Enable feature")
  match schema {
    { "type": "boolean", "description": "Enable feature", .. } => ()
    _ => fail("Invalid schema")
  }
}

///|
test "object_schema creates object schema with required fields" {
  let schema = object_schema(
    { "name": { "type": "string" }, "age": { "type": "integer" } },
    ["name"],
  )
  match schema {
    { "type": "object", "properties": Object(_), "required": Array(req), .. } => {
      inspect(req.length(), content="1")
      match req[0] {
        String(s) => inspect(s, content="name")
        _ => fail("Expected string in required array")
      }
    }
    _ => fail("Invalid schema")
  }
}

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
    ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
}

///|
test "execute_memory_tool get action returns error for missing key" {
  let store = MemoryStore::new()
  let args : Json = { "action": "get", "key": "missing" }
  let result = execute_memory_tool(store, args)
  match result.status {
    ToolResultStatus::Error => ()
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
    ToolResultStatus::Success => ()
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
    ToolResultStatus::Success => ()
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
    ToolResultStatus::Success => ()
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
    ToolResultStatus::Success => ()
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
    ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

///|
test "execute_memory_tool returns error for unknown action" {
  let store = MemoryStore::new()
  let args : Json = { "action": "invalid_action" }
  let result = execute_memory_tool(store, args)
  match result.status {
    ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

// =============================================================================
// DateTime Tool Tests
// =============================================================================

///|
test "get_current_time_seconds returns non-negative value" {
  let seconds = get_current_time_seconds()
  assert_true(seconds >= 0L)
}

///|
test "datetime_tool_definition has correct name" {
  let def = datetime_tool_definition()
  inspect(def.name, content="datetime")
}

///|
test "execute_datetime_tool now action returns timestamp" {
  let args : Json = { "action": "now" }
  let result = execute_datetime_tool(args)
  match result.status {
    ToolResultStatus::Success => ()
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
    ToolResultStatus::Success => ()
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
    ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
  match result.data {
    { "formatted": String(s), .. } => assert_true(s.length() > 0)
    _ => fail("Expected formatted string in data")
  }
}

///|
test "execute_datetime_tool returns error for missing action" {
  let args : Json = { "format": "ISO8601" }
  let result = execute_datetime_tool(args)
  match result.status {
    ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

///|
test "execute_datetime_tool returns error for unknown action" {
  let args : Json = { "action": "invalid" }
  let result = execute_datetime_tool(args)
  match result.status {
    ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

// =============================================================================
// Shell Tool Tests
// =============================================================================

///|
test "shell_tool_definition has correct name" {
  let def = shell_tool_definition()
  inspect(def.name, content="shell")
}

///|
test "is_dangerous_command detects rm -rf" {
  inspect(is_dangerous_command("rm -rf /"), content="true")
  inspect(is_dangerous_command("rm -rf /home"), content="true")
  // rm -r / pattern is detected
  inspect(is_dangerous_command("rm -r /tmp/test"), content="true")
  // Safe rm commands without dangerous patterns
  inspect(is_dangerous_command("rm file.txt"), content="false")
}

///|
test "is_dangerous_command detects dd command" {
  inspect(is_dangerous_command("dd if=/dev/zero of=/dev/sda"), content="true")
  inspect(is_dangerous_command("echo hello"), content="false")
}

///|
test "is_dangerous_command detects mkfs command" {
  inspect(is_dangerous_command("mkfs.ext4 /dev/sda1"), content="true")
}

///|
test "is_dangerous_command detects chmod 777" {
  inspect(is_dangerous_command("chmod -R 777 /"), content="true")
  inspect(is_dangerous_command("chmod 755 file.txt"), content="false")
}

///|
test "is_dangerous_command detects fork bomb" {
  inspect(is_dangerous_command(":(){ :|:& };:"), content="true")
}

///|
test "is_dangerous_command allows safe commands" {
  inspect(is_dangerous_command("ls -la"), content="false")
  inspect(is_dangerous_command("cat file.txt"), content="false")
  inspect(is_dangerous_command("pwd"), content="false")
  inspect(is_dangerous_command("echo hello"), content="false")
  inspect(is_dangerous_command("grep pattern file"), content="false")
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
test "spawn_tool_definition has correct name" {
  let def = spawn_tool_definition()
  inspect(def.name, content="spawn")
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
    ToolResultStatus::Success => ()
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
    ToolResultStatus::Error => ()
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
    ToolResultStatus::Success => ()
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
    ToolResultStatus::Error => ()
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
    ToolResultStatus::Success => ()
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
    ToolResultStatus::Success => ()
    _ => fail("Expected success")
  }
}

///|
test "execute_spawn_tool returns error for missing action" {
  let manager = SubAgentManager::new()
  let args : Json = { "name": "test" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

///|
test "execute_spawn_tool returns error for unknown action" {
  let manager = SubAgentManager::new()
  let args : Json = { "action": "invalid" }
  let result = execute_spawn_tool(manager, args)
  match result.status {
    ToolResultStatus::Error => ()
    _ => fail("Expected error")
  }
}

// =============================================================================
// Filesystem Tool Tests
// =============================================================================

///|
test "filesystem_tool_definition has correct name" {
  let def = filesystem_tool_definition()
  inspect(def.name, content="filesystem")
}

// =============================================================================
// Helper function for assertions
// =============================================================================

///|
fn assert_true(condition : Bool) -> Unit raise {
  if not(condition) {
    fail("Assertion failed: expected true")
  }
}
