///|
/// Native Tools Tests

// =============================================================================
// Registry Tests
// =============================================================================

///|
test "get_all_tool_definitions returns 7 tools on native" {
  let defs = get_all_tool_definitions()
  inspect(defs.length(), content="7")
}

///|
test "get_all_tool_definitions contains all expected tools" {
  let defs = get_all_tool_definitions()
  let names = defs.map(fn(d) { d.name })
  assert_true(names.contains("datetime"))
  assert_true(names.contains("memory"))
  assert_true(names.contains("message"))
  assert_true(names.contains("spawn"))
  assert_true(names.contains("web"))
  assert_true(names.contains("shell"))
  assert_true(names.contains("filesystem"))
}

///|
test "has_tool returns true for all 7 tools" {
  assert_true(has_tool("datetime"))
  assert_true(has_tool("memory"))
  assert_true(has_tool("message"))
  assert_true(has_tool("spawn"))
  assert_true(has_tool("web"))
  assert_true(has_tool("shell"))
  assert_true(has_tool("filesystem"))
  assert_true(not(has_tool("nonexistent")))
}

///|
test "is_sync_tool returns true for all 7 tools" {
  assert_true(is_sync_tool("datetime"))
  assert_true(is_sync_tool("memory"))
  assert_true(is_sync_tool("web"))
  assert_true(is_sync_tool("shell"))
  assert_true(is_sync_tool("filesystem"))
  assert_true(not(is_sync_tool("nonexistent")))
}

// =============================================================================
// Shell Native Tests
// =============================================================================

///|
test "execute_shell_tool_native runs echo command" {
  let result = execute_shell_tool_native({ "command": "echo hello" })
  match result.status {
    ToolResultStatus::Success => {
      match result.data {
        { "stdout": String(out), .. } =>
          assert_true(out.contains("hello"))
        _ => fail("Expected stdout in result")
      }
    }
    _ => fail("Expected success")
  }
}

///|
test "execute_shell_tool_native detects dangerous command" {
  let result = execute_shell_tool_native({ "command": "rm -rf /" })
  match result.status {
    ToolResultStatus::RequiresConfirmation => ()
    _ => fail("Expected RequiresConfirmation for dangerous command")
  }
}

///|
test "execute_shell_tool_native missing command returns error" {
  let result = execute_shell_tool_native({ "action": "run" })
  match result.status {
    ToolResultStatus::Error => ()
    _ => fail("Expected error for missing command")
  }
}

// =============================================================================
// Filesystem Native Tests
// =============================================================================

///|
test "execute_filesystem_tool_native exists action" {
  let result = execute_filesystem_tool_native({
    "action": "exists",
    "path": "/tmp",
  })
  match result.status {
    ToolResultStatus::Success =>
      match result.data {
        { "exists": True, .. } => ()
        _ => fail("Expected exists=true for /tmp")
      }
    _ => fail("Expected success")
  }
}

///|
test "execute_filesystem_tool_native write and read" {
  let test_path = "/tmp/mukuro_test_native_fs_\{42}.txt"
  let content = "hello from native filesystem tool"
  // Write
  let write_result = execute_filesystem_tool_native({
    "action": "write",
    "path": test_path,
    "content": content,
  })
  match write_result.status {
    ToolResultStatus::Success => ()
    _ => fail("Expected write success")
  }
  // Read
  let read_result = execute_filesystem_tool_native({
    "action": "read",
    "path": test_path,
  })
  match read_result.status {
    ToolResultStatus::Success =>
      match read_result.data {
        { "content": String(c), .. } => assert_eq(c, content)
        _ => fail("Expected content in read result")
      }
    _ => fail("Expected read success")
  }
  // Delete
  let del_result = execute_filesystem_tool_native({
    "action": "delete",
    "path": test_path,
  })
  match del_result.status {
    ToolResultStatus::Success => ()
    _ => fail("Expected delete success")
  }
}

///|
test "execute_filesystem_tool_native path traversal blocked" {
  let result = execute_filesystem_tool_native({
    "action": "read",
    "path": "/tmp/../etc/passwd",
  })
  match result.status {
    ToolResultStatus::Error => ()
    _ => fail("Expected error for path traversal")
  }
}

///|
test "execute_filesystem_tool_native mkdir and list" {
  let test_dir = "/tmp/mukuro_test_native_dir_\{42}"
  // mkdir
  let mkdir_result = execute_filesystem_tool_native({
    "action": "mkdir",
    "path": test_dir,
  })
  match mkdir_result.status {
    ToolResultStatus::Success => ()
    _ => fail("Expected mkdir success")
  }
  // Write a file in dir
  let _ = execute_filesystem_tool_native({
    "action": "write",
    "path": test_dir + "/test.txt",
    "content": "test",
  })
  // list
  let list_result = execute_filesystem_tool_native({
    "action": "list",
    "path": test_dir,
  })
  match list_result.status {
    ToolResultStatus::Success =>
      match list_result.data {
        { "count": Number(_), .. } => ()
        _ => fail("Expected count in list result")
      }
    _ => fail("Expected list success")
  }
  // Cleanup
  let _ = execute_filesystem_tool_native({
    "action": "delete",
    "path": test_dir,
    "recursive": true,
  })
}

// =============================================================================
// is_dangerous_command Tests (cross-platform)
// =============================================================================

///|
test "is_dangerous_command detects rm -rf" {
  assert_true(is_dangerous_command("rm -rf /"))
  assert_true(is_dangerous_command("sudo rm -rf /home"))
  assert_true(not(is_dangerous_command("rm file.txt")))
  assert_true(not(is_dangerous_command("echo hello")))
}

///|
test "is_dangerous_command detects fork bomb" {
  assert_true(is_dangerous_command(":(){ :|:& };:"))
}

///|
test "is_dangerous_command detects dd" {
  assert_true(is_dangerous_command("dd if=/dev/zero of=/dev/sda"))
}
