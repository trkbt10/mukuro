///|
/// Tools Definitions Tests

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
// Tool Definition Tests
// =============================================================================

///|
test "datetime_tool_definition has correct name" {
  let def = datetime_tool_definition()
  inspect(def.name, content="datetime")
}

///|
test "memory_tool_definition has correct name" {
  let def = memory_tool_definition()
  inspect(def.name, content="memory")
}

///|
test "message_tool_definition has correct name" {
  let def = message_tool_definition()
  inspect(def.name, content="message")
}

///|
test "spawn_tool_definition has correct name" {
  let def = spawn_tool_definition()
  inspect(def.name, content="spawn")
}

///|
test "shell_tool_definition has correct name" {
  let def = shell_tool_definition()
  inspect(def.name, content="shell")
}

///|
test "web_tool_definition has correct name" {
  let def = web_tool_definition()
  inspect(def.name, content="web")
}

///|
test "filesystem_tool_definition has correct name" {
  let def = filesystem_tool_definition()
  inspect(def.name, content="filesystem")
}

// =============================================================================
// Registry Tests
// =============================================================================

///|
test "get_all_tool_definitions returns 7 tools" {
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
test "get_tool_definition finds existing tool" {
  match get_tool_definition("datetime") {
    Some(def) => inspect(def.name, content="datetime")
    None => fail("Expected datetime definition")
  }
}

///|
test "get_tool_definition returns None for unknown tool" {
  assert_true(get_tool_definition("nonexistent") is None)
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
