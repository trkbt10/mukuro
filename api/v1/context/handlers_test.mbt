///|
/// Context API Handler Tests

///|
/// Mock file storage for testing
struct MockFileStorage {
  files : Map[String, String]
  dir : String
}

///|
fn MockFileStorage::new(dir : String) -> MockFileStorage {
  { files: {}, dir }
}

///|
fn create_mock_io(storage : MockFileStorage) -> ContextFileIO {
  {
    read: fn(path) {
      match storage.files.get(path) {
        Some(content) =>
          if content.trim(chars=" \t\n\r").length() > 0 {
            Some(content)
          } else {
            None
          }
        None => None
      }
    },
    write: fn(path, content) {
      storage.files[path] = content
      true
    },
    delete: fn(path) {
      storage.files.remove(path)
      true
    },
    get_dir: fn() { storage.dir },
  }
}

///|
fn make_test_ctx(
  meth : String,
  path : String,
  body : String,
) -> @api.ApiRequestContext {
  @api.ApiRequestContext::new(
    meth~,
    path~,
    headers={},
    body~,
    role=@api.ApiRole::Admin,
  )
}

// =============================================================================
// List Tests
// =============================================================================

///|
test "handle_list returns all context file types" {
  let storage = MockFileStorage::new(".mukuro")
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context", "")
  let resp = (handlers.list.0)(ctx)
  assert_eq(resp.status, 200)
  // Should contain all 6 file types
  assert_true(resp.body.contains("soul"))
  assert_true(resp.body.contains("agents"))
  assert_true(resp.body.contains("tools"))
  assert_true(resp.body.contains("identity"))
  assert_true(resp.body.contains("user"))
  assert_true(resp.body.contains("bootstrap"))
}

///|
test "handle_list shows existing files" {
  let storage = MockFileStorage::new(".mukuro")
  storage.files[".mukuro/SOUL.md"] = "Be kind"
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context", "")
  let resp = (handlers.list.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("Be kind"))
  assert_true(resp.body.contains("\"exists\":true"))
}

// =============================================================================
// Get Tests
// =============================================================================

///|
test "handle_get returns file content" {
  let storage = MockFileStorage::new(".mukuro")
  storage.files[".mukuro/SOUL.md"] = "Soul content here"
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/soul", "")
  let resp = (handlers.get.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("Soul content here"))
  assert_true(resp.body.contains("\"exists\":true"))
}

///|
test "handle_get returns empty for non-existent file" {
  let storage = MockFileStorage::new(".mukuro")
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/soul", "")
  let resp = (handlers.get.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("\"exists\":false"))
}

///|
test "handle_get returns 404 for invalid file type" {
  let storage = MockFileStorage::new(".mukuro")
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/invalid", "")
  let resp = (handlers.get.0)(ctx)
  assert_eq(resp.status, 404)
  assert_true(resp.body.contains("Unknown context file"))
}

///|
test "handle_get returns 400 when name is missing" {
  let storage = MockFileStorage::new(".mukuro")
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context", "")
  // Manually set segments to simulate missing name
  let ctx2 : @api.ApiRequestContext = { ..ctx, segments: ["context"] }
  let resp = (handlers.get.0)(ctx2)
  assert_eq(resp.status, 400)
}

// =============================================================================
// Update Tests
// =============================================================================

///|
test "handle_update writes file content" {
  let storage = MockFileStorage::new(".mukuro")
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx(
    "PUT", "/api/v1/context/soul", "{\"content\":\"New soul content\"}",
  )
  let resp = (handlers.update.0)(ctx)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("ok"))
  // Verify file was written
  assert_eq(storage.files.get(".mukuro/SOUL.md"), Some("New soul content"))
}

///|
test "handle_update returns 400 for missing content" {
  let storage = MockFileStorage::new(".mukuro")
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("PUT", "/api/v1/context/soul", "{}")
  let resp = (handlers.update.0)(ctx)
  assert_eq(resp.status, 400)
  assert_true(resp.body.contains("content"))
}

///|
test "handle_update returns 404 for invalid file type" {
  let storage = MockFileStorage::new(".mukuro")
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx(
    "PUT", "/api/v1/context/invalid", "{\"content\":\"test\"}",
  )
  let resp = (handlers.update.0)(ctx)
  assert_eq(resp.status, 404)
}

// =============================================================================
// Delete Tests
// =============================================================================

///|
test "handle_delete removes file" {
  let storage = MockFileStorage::new(".mukuro")
  storage.files[".mukuro/SOUL.md"] = "Soul content"
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("DELETE", "/api/v1/context/soul", "")
  let resp = (handlers.delete.0)(ctx)
  assert_eq(resp.status, 200)
  // File should be removed
  assert_eq(storage.files.get(".mukuro/SOUL.md"), None)
}

///|
test "handle_delete returns 404 for invalid file type" {
  let storage = MockFileStorage::new(".mukuro")
  let state = ContextState::new(create_mock_io(storage))
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("DELETE", "/api/v1/context/invalid", "")
  let resp = (handlers.delete.0)(ctx)
  assert_eq(resp.status, 404)
}

// =============================================================================
// Schema Tests
// =============================================================================

///|
test "ContextFileType::from_string parses valid types" {
  assert_eq(ContextFileType::from_string("soul"), Some(ContextFileType::Soul))
  assert_eq(
    ContextFileType::from_string("agents"),
    Some(ContextFileType::Agents),
  )
  assert_eq(ContextFileType::from_string("tools"), Some(ContextFileType::Tools))
  assert_eq(
    ContextFileType::from_string("identity"),
    Some(ContextFileType::Identity),
  )
  assert_eq(ContextFileType::from_string("user"), Some(ContextFileType::User))
  assert_eq(
    ContextFileType::from_string("bootstrap"),
    Some(ContextFileType::Bootstrap),
  )
  assert_eq(ContextFileType::from_string("SOUL"), Some(ContextFileType::Soul))
}

///|
test "ContextFileType::from_string returns None for invalid types" {
  assert_eq(ContextFileType::from_string("invalid"), None)
  assert_eq(ContextFileType::from_string(""), None)
}

///|
test "ContextFileType::filename returns correct filenames" {
  assert_eq(ContextFileType::Soul.filename(), "SOUL.md")
  assert_eq(ContextFileType::Agents.filename(), "AGENTS.md")
  assert_eq(ContextFileType::Tools.filename(), "TOOLS.md")
  assert_eq(ContextFileType::Identity.filename(), "IDENTITY.md")
  assert_eq(ContextFileType::User.filename(), "USER.md")
  assert_eq(ContextFileType::Bootstrap.filename(), "bootstrap.md")
}

///|
test "all_context_file_types returns all 6 types" {
  let types = all_context_file_types()
  assert_eq(types.length(), 6)
}

///|
test "ContextFileResponse::to_json produces valid JSON" {
  let resp = ContextFileResponse::from_type(
    ContextFileType::Soul,
    Some("Be kind"),
  )
  let json = resp.to_json()
  let json_str = json.stringify()
  assert_true(json_str.contains("\"name\":\"soul\""))
  assert_true(json_str.contains("\"filename\":\"SOUL.md\""))
  assert_true(json_str.contains("\"content\":\"Be kind\""))
  assert_true(json_str.contains("\"exists\":true"))
}
