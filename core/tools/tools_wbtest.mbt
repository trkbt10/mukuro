///|
/// ツールパッケージのテスト

// =============================================================================
// Registry Tests
// =============================================================================

test "all_tool_definitions returns all tools" {
  let defs = all_tool_definitions()
  assert_true(defs.length() >= 7)
  let names = defs.map(fn(d) { d.name })
  assert_true(names.contains("datetime"))
  assert_true(names.contains("memory"))
  assert_true(names.contains("message"))
  assert_true(names.contains("spawn"))
  assert_true(names.contains("shell"))
  assert_true(names.contains("filesystem"))
  assert_true(names.contains("web"))
}

///|
test "get_tool_definition returns correct definition" {
  let def = get_tool_definition("datetime")
  match def {
    Some(d) => assert_eq(d.name, "datetime")
    None => fail("Expected Some")
  }
}

///|
test "get_tool_definition returns None for unknown tool" {
  let def = get_tool_definition("nonexistent")
  match def {
    None => ()
    _ => fail("Expected None")
  }
}

///|
test "has_tool returns true for existing tools" {
  assert_true(has_tool("datetime"))
  assert_true(has_tool("shell"))
  assert_true(has_tool("filesystem"))
}

///|
test "has_tool returns false for unknown tools" {
  assert_true(not(has_tool("nonexistent")))
}

// =============================================================================
// Datetime Tool Tests
// =============================================================================

///|
test "datetime_tool definition is valid" {
  let def = datetime_tool()
  assert_eq(def.name, "datetime")
  assert_true(def.description.length() > 0)
}

///|
test "execute_datetime with now action" {
  let args : Json = { "action": "now" }
  let result = execute_datetime(args)
  assert_true(result.status == ToolResultStatus::Success)
  match result.data {
    { "timestamp_ms": Number(_, ..), .. } => ()
    _ => fail("Expected timestamp_ms in response")
  }
}

///|
test "execute_datetime with format action" {
  let args : Json = { "action": "format", "timestamp": 1609459200000 }
  let result = execute_datetime(args)
  assert_true(result.status == ToolResultStatus::Success)
  match result.data {
    { "formatted": String(s), .. } => assert_true(s.length() > 0)
    _ => fail("Expected formatted in response")
  }
}

///|
test "execute_datetime with missing action" {
  let args : Json = {}
  let result = execute_datetime(args)
  assert_true(result.status == ToolResultStatus::Error)
}

// =============================================================================
// Memory Tool Tests
// =============================================================================

///|
test "memory_tool definition is valid" {
  let def = memory_tool()
  assert_eq(def.name, "memory")
  assert_true(def.description.length() > 0)
}

///|
test "execute_memory set and get" {
  let store = MemoryStore::new()
  let set_args : Json = {
    "action": "set",
    "key": "test_key",
    "value": "test_value",
  }
  let set_result = execute_memory(store, set_args)
  assert_true(set_result.status == ToolResultStatus::Success)
  let get_args : Json = { "action": "get", "key": "test_key" }
  let get_result = execute_memory(store, get_args)
  assert_true(get_result.status == ToolResultStatus::Success)
  match get_result.data {
    { "value": String("test_value"), .. } => ()
    _ => fail("Expected value in response")
  }
}

///|
test "execute_memory delete" {
  let store = MemoryStore::new()
  store.set("to_delete", Json::string("value"))
  let args : Json = { "action": "delete", "key": "to_delete" }
  let result = execute_memory(store, args)
  assert_true(result.status == ToolResultStatus::Success)
  match result.data {
    { "deleted": True, .. } => ()
    _ => fail("Expected deleted: true")
  }
  match store.get("to_delete") {
    None => ()
    _ => fail("Expected None after delete")
  }
}

///|
test "execute_memory list" {
  let store = MemoryStore::new()
  store.set("key1", Json::string("val1"))
  store.set("key2", Json::string("val2"))
  let args : Json = { "action": "list" }
  let result = execute_memory(store, args)
  assert_true(result.status == ToolResultStatus::Success)
  match result.data {
    { "count": Number(n, ..), .. } => assert_true(n >= 2.0)
    _ => fail("Expected count in response")
  }
}

// =============================================================================
// Shell Tool Tests
// =============================================================================

///|
test "shell_tool definition is valid" {
  let def = shell_tool()
  assert_eq(def.name, "shell")
  assert_true(def.description.length() > 0)
}

///|
test "is_dangerous_command detects rm -rf" {
  assert_true(is_dangerous_command("rm -rf /"))
  assert_true(is_dangerous_command("sudo rm -rf /home"))
}

///|
test "is_dangerous_command allows safe commands" {
  assert_true(not(is_dangerous_command("ls -la")))
  assert_true(not(is_dangerous_command("echo hello")))
  assert_true(not(is_dangerous_command("cat file.txt")))
}

///|
async test "execute_shell with safe command" {
  let args : Json = { "command": "echo hello" }
  let result = execute_shell(args)
  assert_true(result.status == ToolResultStatus::Success)
  match result.data {
    { "stdout": String(s), "exit_code": Number(n, ..), .. } => {
      assert_true(s.contains("hello"))
      assert_true(n == 0.0)
    }
    _ => fail("Expected stdout and exit_code")
  }
}

///|
async test "execute_shell with dangerous command requires confirmation" {
  let args : Json = { "command": "rm -rf /" }
  let result = execute_shell(args)
  assert_true(result.status == ToolResultStatus::RequiresConfirmation)
}

///|
async test "execute_shell with cwd" {
  let args : Json = { "command": "pwd", "cwd": "/tmp" }
  let result = execute_shell(args)
  assert_true(result.status == ToolResultStatus::Success)
  match result.data {
    { "stdout": String(s), .. } =>
      assert_true(s.contains("/tmp") || s.contains("/private/tmp"))
    _ => fail("Expected stdout")
  }
}

// =============================================================================
// Filesystem Tool Tests
// =============================================================================

///|
test "filesystem_tool definition is valid" {
  let def = filesystem_tool()
  assert_eq(def.name, "filesystem")
  assert_true(def.description.length() > 0)
}

///|
test "execute_filesystem exists" {
  let args : Json = { "action": "exists", "path": "/tmp" }
  let result = execute_filesystem(args)
  assert_true(result.status == ToolResultStatus::Success)
  match result.data {
    { "exists": True, .. } => ()
    _ => fail("Expected exists: true for /tmp")
  }
}

///|
test "execute_filesystem list" {
  let args : Json = { "action": "list", "path": "/tmp" }
  let result = execute_filesystem(args)
  assert_true(result.status == ToolResultStatus::Success)
  match result.data {
    { "files": Array(_), .. } => ()
    _ => fail("Expected files array")
  }
}

///|
test "execute_filesystem rejects path traversal" {
  let args : Json = { "action": "read", "path": "/etc/../etc/passwd" }
  let result = execute_filesystem(args)
  assert_true(result.status == ToolResultStatus::Error)
  match result.error_message {
    Some(msg) => assert_true(msg.contains("traversal"))
    None => fail("Expected error message")
  }
}

// =============================================================================
// Web Tool Tests
// =============================================================================

///|
test "web_tool definition is valid" {
  let def = web_tool()
  assert_eq(def.name, "web")
  assert_true(def.description.length() > 0)
}

///|
test "execute_web with search action returns error" {
  let args : Json = { "action": "search", "query": "test" }
  let result = execute_web(args)
  assert_true(result.status == ToolResultStatus::Error)
  match result.error_message {
    Some(msg) => assert_true(msg.contains("external API"))
    None => fail("Expected error message")
  }
}

///|
test "execute_web with missing url" {
  let args : Json = { "action": "fetch" }
  let result = execute_web(args)
  assert_true(result.status == ToolResultStatus::Error)
  match result.error_message {
    Some(msg) => assert_true(msg.contains("url"))
    None => fail("Expected error message")
  }
}

// =============================================================================
// Dispatch Tests
// =============================================================================

///|
async test "execute_simple_tool datetime" {
  let args : Json = { "action": "now" }
  let result = execute_simple_tool("datetime", args)
  assert_true(result.status == ToolResultStatus::Success)
}

///|
async test "execute_simple_tool unknown" {
  let args : Json = {}
  let result = execute_simple_tool("unknown", args)
  assert_true(result.status == ToolResultStatus::Error)
}

///|
test "is_sync_tool returns true for all builtin tools" {
  assert_true(is_sync_tool("datetime"))
  assert_true(is_sync_tool("memory"))
  assert_true(is_sync_tool("shell"))
  assert_true(is_sync_tool("filesystem"))
  assert_true(is_sync_tool("web"))
}

///|
test "is_sync_tool returns false for unknown tools" {
  assert_true(not(is_sync_tool("unknown")))
}

// =============================================================================
// Utility Tests
// =============================================================================

///|
test "ToolExecutionResult::success creates success result" {
  let result = ToolExecutionResult::success({ "key": "value" })
  assert_true(result.status == ToolResultStatus::Success)
  match result.data {
    { "key": String("value"), .. } => ()
    _ => fail("Expected key: value")
  }
}

///|
test "ToolExecutionResult::error creates error result" {
  let result : ToolExecutionResult = ToolExecutionResult::error("test error")
  assert_true(result.status == ToolResultStatus::Error)
  assert_eq(result.error_message, Some("test error"))
}

///|
test "get_string_arg extracts string" {
  let json : Json = { "name": "test" }
  let result = get_string_arg(json, "name")
  assert_eq(result, Some("test"))
}

///|
test "get_string_arg returns None for missing key" {
  let json : Json = { "other": "value" }
  let result = get_string_arg(json, "name")
  assert_eq(result, None)
}

///|
test "get_int_arg extracts integer" {
  let json : Json = { "count": 42 }
  let result = get_int_arg(json, "count")
  assert_eq(result, Some(42))
}

///|
test "get_bool_arg extracts boolean" {
  let json : Json = { "enabled": true }
  let result = get_bool_arg(json, "enabled")
  assert_eq(result, Some(true))
}
