///|
/// Devtools Tests (Native)

// =============================================================================
// Shell Native Tests
// =============================================================================

///|
test "execute_shell_tool_native runs echo command" {
  let result = execute_shell_tool_native({ "command": "echo hello" })
  match result.status {
    @defs.ToolResultStatus::Success => {
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
    @defs.ToolResultStatus::RequiresConfirmation => ()
    _ => fail("Expected RequiresConfirmation for dangerous command")
  }
}

///|
test "execute_shell_tool_native missing command returns error" {
  let result = execute_shell_tool_native({ "action": "run" })
  match result.status {
    @defs.ToolResultStatus::Error => ()
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
    @defs.ToolResultStatus::Success =>
      match result.data {
        { "exists": True, .. } => ()
        _ => fail("Expected exists=true for /tmp")
      }
    _ => fail("Expected success")
  }
}

///|
test "execute_filesystem_tool_native write and read" {
  let test_path = "/tmp/mukuro_test_devtools_fs_\{42}.txt"
  let content = "hello from devtools filesystem tool"
  // Write
  let write_result = execute_filesystem_tool_native({
    "action": "write",
    "path": test_path,
    "content": content,
  })
  match write_result.status {
    @defs.ToolResultStatus::Success => ()
    _ => fail("Expected write success")
  }
  // Read
  let read_result = execute_filesystem_tool_native({
    "action": "read",
    "path": test_path,
  })
  match read_result.status {
    @defs.ToolResultStatus::Success =>
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
    @defs.ToolResultStatus::Success => ()
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
    @defs.ToolResultStatus::Error => ()
    _ => fail("Expected error for path traversal")
  }
}

///|
test "execute_filesystem_tool_native mkdir and list" {
  let test_dir = "/tmp/mukuro_test_devtools_dir_\{42}"
  // mkdir
  let mkdir_result = execute_filesystem_tool_native({
    "action": "mkdir",
    "path": test_dir,
  })
  match mkdir_result.status {
    @defs.ToolResultStatus::Success => ()
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
    @defs.ToolResultStatus::Success =>
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
// is_dangerous_command Tests
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

// =============================================================================
// Dispatch Tests
// =============================================================================

///|
test "has_devtool returns true for devtools" {
  assert_true(has_devtool("web"))
  assert_true(has_devtool("shell"))
  assert_true(has_devtool("filesystem"))
  assert_true(not(has_devtool("datetime")))
  assert_true(not(has_devtool("nonexistent")))
}

///|
test "is_sync_devtool returns true for all devtools" {
  assert_true(is_sync_devtool("web"))
  assert_true(is_sync_devtool("shell"))
  assert_true(is_sync_devtool("filesystem"))
  assert_true(not(is_sync_devtool("nonexistent")))
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
