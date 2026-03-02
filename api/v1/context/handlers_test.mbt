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
fn create_mock_data_io(storage : MockFileStorage) -> ContextDataIO {
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
/// Mock template storage
struct MockTemplateStorage {
  templates : Map[String, String]
}

///|
fn MockTemplateStorage::new() -> MockTemplateStorage {
  { templates: {} }
}

///|
fn create_mock_template_resolver(
  storage : MockTemplateStorage,
) -> TemplateResolver {
  {
    read_installed: fn(filename) { storage.templates.get(filename) },
    get_embedded: fn(file_type) { file_type.default_template() },
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
// Data List Tests
// =============================================================================

///|
test "handle_data_list returns all context file types" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/data", "")
  let ctx2 : @api.ApiRequestContext = { ..ctx, segments: ["context", "data"] }
  let resp = (handlers.data_list.0)(ctx2)
  assert_eq(resp.status, 200)
  // Should contain all 7 file types
  assert_true(resp.body.contains("soul"))
  assert_true(resp.body.contains("agents"))
  assert_true(resp.body.contains("tools"))
  assert_true(resp.body.contains("identity"))
  assert_true(resp.body.contains("user"))
  assert_true(resp.body.contains("bootstrap"))
  assert_true(resp.body.contains("heartbeat"))
}

///|
test "handle_data_list shows existing files" {
  let storage = MockFileStorage::new(".mukuro")
  storage.files[".mukuro/SOUL.md"] = "Be kind"
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/data", "")
  let ctx2 : @api.ApiRequestContext = { ..ctx, segments: ["context", "data"] }
  let resp = (handlers.data_list.0)(ctx2)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("Be kind"))
  assert_true(resp.body.contains("\"exists\":true"))
}

// =============================================================================
// Data Get Tests
// =============================================================================

///|
test "handle_data_get returns file content" {
  let storage = MockFileStorage::new(".mukuro")
  storage.files[".mukuro/SOUL.md"] = "Soul content here"
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/data/soul", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "data", "soul"],
  }
  let resp = (handlers.data_get.0)(ctx2)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("Soul content here"))
  assert_true(resp.body.contains("\"exists\":true"))
}

///|
test "handle_data_get returns empty for non-existent file" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/data/soul", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "data", "soul"],
  }
  let resp = (handlers.data_get.0)(ctx2)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("\"exists\":false"))
  // Should NOT contain template content
  assert_true(resp.body.contains("\"content\":\"\""))
}

///|
test "handle_data_get returns 404 for invalid file type" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/data/invalid", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "data", "invalid"],
  }
  let resp = (handlers.data_get.0)(ctx2)
  assert_eq(resp.status, 404)
  assert_true(resp.body.contains("Unknown context file"))
}

///|
test "handle_data_get returns 400 when name is missing" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/data", "")
  let ctx2 : @api.ApiRequestContext = { ..ctx, segments: ["context", "data"] }
  let resp = (handlers.data_get.0)(ctx2)
  assert_eq(resp.status, 400)
}

// =============================================================================
// Data Update Tests
// =============================================================================

///|
test "handle_data_update writes file content" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx(
    "PUT", "/api/v1/context/data/soul", "{\"content\":\"New soul content\"}",
  )
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "data", "soul"],
  }
  let resp = (handlers.data_update.0)(ctx2)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("ok"))
  // Verify file was written
  assert_eq(storage.files.get(".mukuro/SOUL.md"), Some("New soul content"))
}

///|
test "handle_data_update returns 400 for missing content" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("PUT", "/api/v1/context/data/soul", "{}")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "data", "soul"],
  }
  let resp = (handlers.data_update.0)(ctx2)
  assert_eq(resp.status, 400)
  assert_true(resp.body.contains("content"))
}

///|
test "handle_data_update returns 404 for invalid file type" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx(
    "PUT", "/api/v1/context/data/invalid", "{\"content\":\"test\"}",
  )
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "data", "invalid"],
  }
  let resp = (handlers.data_update.0)(ctx2)
  assert_eq(resp.status, 404)
}

// =============================================================================
// Data Delete Tests
// =============================================================================

///|
test "handle_data_delete removes file" {
  let storage = MockFileStorage::new(".mukuro")
  storage.files[".mukuro/SOUL.md"] = "Soul content"
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("DELETE", "/api/v1/context/data/soul", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "data", "soul"],
  }
  let resp = (handlers.data_delete.0)(ctx2)
  assert_eq(resp.status, 200)
  // File should be removed
  assert_eq(storage.files.get(".mukuro/SOUL.md"), None)
}

///|
test "handle_data_delete returns 404 for invalid file type" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("DELETE", "/api/v1/context/data/invalid", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "data", "invalid"],
  }
  let resp = (handlers.data_delete.0)(ctx2)
  assert_eq(resp.status, 404)
}

// =============================================================================
// Template List Tests
// =============================================================================

///|
test "handle_templates_list returns all templates" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/templates", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "templates"],
  }
  let resp = (handlers.templates_list.0)(ctx2)
  assert_eq(resp.status, 200)
  // Should contain all file types with template content
  assert_true(resp.body.contains("soul"))
  assert_true(resp.body.contains("\"exists\":true"))
  assert_true(resp.body.contains("\"is_default\":true"))
}

///|
test "handle_templates_list uses installed templates when available" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  templates.templates["SOUL.md"] = "Custom installed template"
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/templates", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "templates"],
  }
  let resp = (handlers.templates_list.0)(ctx2)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("Custom installed template"))
}

// =============================================================================
// Template Get Tests
// =============================================================================

///|
test "handle_templates_get returns embedded template" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/templates/soul", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "templates", "soul"],
  }
  let resp = (handlers.templates_get.0)(ctx2)
  assert_eq(resp.status, 200)
  // Should contain embedded template content
  assert_true(resp.body.contains("Who You Are"))
  assert_true(resp.body.contains("\"exists\":true"))
  assert_true(resp.body.contains("\"is_default\":true"))
}

///|
test "handle_templates_get prefers installed template" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  templates.templates["SOUL.md"] = "Custom installed soul template"
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/templates/soul", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "templates", "soul"],
  }
  let resp = (handlers.templates_get.0)(ctx2)
  assert_eq(resp.status, 200)
  assert_true(resp.body.contains("Custom installed soul template"))
}

///|
test "handle_templates_get returns 404 for invalid template" {
  let storage = MockFileStorage::new(".mukuro")
  let templates = MockTemplateStorage::new()
  let state = ContextState::new(
    create_mock_data_io(storage),
    create_mock_template_resolver(templates),
  )
  let handlers = create_context_handlers(state)
  let ctx = make_test_ctx("GET", "/api/v1/context/templates/invalid", "")
  let ctx2 : @api.ApiRequestContext = {
    ..ctx,
    segments: ["context", "templates", "invalid"],
  }
  let resp = (handlers.templates_get.0)(ctx2)
  assert_eq(resp.status, 404)
  assert_true(resp.body.contains("Unknown template"))
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
  assert_eq(
    ContextFileType::from_string("heartbeat"),
    Some(ContextFileType::Heartbeat),
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
  assert_eq(ContextFileType::Heartbeat.filename(), "HEARTBEAT.md")
}

///|
test "all_context_file_types returns all 7 types" {
  let types = all_context_file_types()
  assert_eq(types.length(), 7)
}

///|
test "ContextFileResponse::from_data produces correct response" {
  let resp = ContextFileResponse::from_data(
    ContextFileType::Soul,
    Some("Be kind"),
  )
  let json = resp.to_json()
  let json_str = json.stringify()
  assert_true(json_str.contains("\"name\":\"soul\""))
  assert_true(json_str.contains("\"filename\":\"SOUL.md\""))
  assert_true(json_str.contains("\"content\":\"Be kind\""))
  assert_true(json_str.contains("\"exists\":true"))
  assert_true(json_str.contains("\"is_default\":false"))
}

///|
test "ContextFileResponse::from_data returns empty when no content" {
  let resp = ContextFileResponse::from_data(ContextFileType::Soul, None)
  let json = resp.to_json()
  let json_str = json.stringify()
  assert_true(json_str.contains("\"content\":\"\""))
  assert_true(json_str.contains("\"exists\":false"))
}

///|
test "ContextFileResponse::from_template produces correct response" {
  let resp = ContextFileResponse::from_template(
    ContextFileType::Soul,
    "Template content",
  )
  let json = resp.to_json()
  let json_str = json.stringify()
  assert_true(json_str.contains("\"content\":\"Template content\""))
  assert_true(json_str.contains("\"exists\":true"))
  assert_true(json_str.contains("\"is_default\":true"))
}
