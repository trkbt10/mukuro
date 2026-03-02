///|
/// Tool Loader Tests

///|
test "ToolManifest::from_json parses valid manifest" {
  let json : Json = {
    "id": "my-tool",
    "name": "My Tool",
    "description": "A test tool",
    "parameters": { "type": "object" },
  }
  match ToolManifest::from_json(json) {
    Some(manifest) => {
      assert_eq(manifest.id, "my-tool")
      assert_eq(manifest.name, "My Tool")
      assert_eq(manifest.description, "A test tool")
    }
    None => fail("Expected Some(manifest)")
  }
}

///|
test "ToolManifest::from_json uses id as name fallback" {
  let json : Json = { "id": "my-tool", "description": "A test tool" }
  match ToolManifest::from_json(json) {
    Some(manifest) => {
      assert_eq(manifest.id, "my-tool")
      assert_eq(manifest.name, "my-tool") // fallback to id
    }
    None => fail("Expected Some(manifest)")
  }
}

///|
test "ToolManifest::from_json returns None for missing id" {
  let json : Json = { "name": "My Tool", "description": "A test tool" }
  match ToolManifest::from_json(json) {
    Some(_) => fail("Expected None for missing id")
    None => ()
  }
}

///|
test "ToolManifest::from_json returns None for non-object" {
  let json : Json = "not an object"
  match ToolManifest::from_json(json) {
    Some(_) => fail("Expected None for non-object")
    None => ()
  }
}

///|
test "ToolManifest::to_tool_state creates user-defined tool" {
  let manifest = ToolManifest::{
    id: "my-tool",
    name: "My Tool",
    description: "A test tool",
    parameters: { "type": "object" },
  }
  let state = manifest.to_tool_state()
  assert_eq(state.id, "my-tool")
  assert_eq(state.name, "My Tool")
  assert_eq(state.description, "A test tool")
  // Check source is UserDefined
  match state.source {
    @interfaces.ToolSource::UserDefined => ()
    _ => fail("Expected UserDefined source")
  }
}

///|
test "load_user_defined_tools with no directories returns empty" {
  let io : ToolLoaderIO = {
    list_tool_dirs: fn() { [] },
    read_manifest: fn(_) { None },
  }
  let tools = load_user_defined_tools(io)
  assert_eq(tools.length(), 0)
}

///|
test "load_user_defined_tools loads valid manifests" {
  let tool1_json =
    #|{"id": "tool1", "name": "Tool 1", "description": "First tool"}
  let tool2_json =
    #|{"id": "tool2", "name": "Tool 2", "description": "Second tool"}
  let io : ToolLoaderIO = {
    list_tool_dirs: fn() { ["tool1", "tool2"] },
    read_manifest: fn(dir) {
      if dir == "tool1" {
        Some(tool1_json)
      } else if dir == "tool2" {
        Some(tool2_json)
      } else {
        None
      }
    },
  }
  let tools = load_user_defined_tools(io)
  assert_eq(tools.length(), 2)
  assert_eq(tools[0].id, "tool1")
  assert_eq(tools[1].id, "tool2")
}

///|
test "load_user_defined_tools skips invalid manifests" {
  let valid_json =
    #|{"id": "valid-tool", "name": "Valid Tool", "description": "Works"}
  let io : ToolLoaderIO = {
    list_tool_dirs: fn() { ["valid", "invalid"] },
    read_manifest: fn(dir) {
      if dir == "valid" {
        Some(valid_json)
      } else {
        Some("not valid json {")
      }
    },
  }
  let tools = load_user_defined_tools(io)
  assert_eq(tools.length(), 1)
  assert_eq(tools[0].id, "valid-tool")
}

///|
test "load_tool_from_manifest parses valid content" {
  let content =
    #|{"id": "test-tool", "name": "Test Tool", "description": "A test"}
  let state = load_tool_from_manifest(content) catch {
    _ => fail("Expected success")
  }
  assert_eq(state.id, "test-tool")
  assert_eq(state.name, "Test Tool")
}

///|
test "load_tool_from_manifest raises on invalid JSON" {
  let got_error = try {
    let _ = load_tool_from_manifest("not json {")
    false
  } catch {
    @interfaces.ToolManagerError::ManifestInvalid(_) => true
    _ => false
  }
  assert_true(got_error)
}

///|
test "load_tool_from_manifest raises on missing required fields" {
  let no_id_json =
    #|{"name": "No ID"}
  let got_error = try {
    let _ = load_tool_from_manifest(no_id_json)
    false
  } catch {
    @interfaces.ToolManagerError::ManifestInvalid(_) => true
    _ => false
  }
  assert_true(got_error)
}
