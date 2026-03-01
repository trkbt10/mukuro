///|
/// Context Files API Handlers
/// HTTP handlers for /api/v1/context/* endpoints
/// Manages workspace context files (SOUL.md, AGENTS.md, etc.)

///|
/// Context data file reader/writer interface
pub(all) struct ContextDataIO {
  /// Read file content (returns None if file doesn't exist or is empty)
  read : (String) -> String?
  /// Write file content (creates file if doesn't exist)
  write : (String, String) -> Bool
  /// Delete file (or set to empty)
  delete : (String) -> Bool
  /// Get workspace context directory
  get_dir : () -> String
}

///|
/// Template resolver interface
pub(all) struct TemplateResolver {
  /// Read template from install directory (returns None if not found)
  read_installed : (String) -> String?
  /// Get embedded fallback template
  get_embedded : (ContextFileType) -> String
}

///|
/// Context state holder
pub(all) struct ContextState {
  /// Data file I/O interface
  data_io : ContextDataIO
  /// Template resolver
  templates : TemplateResolver
}

///|
/// Create new context state
pub fn ContextState::new(
  data_io : ContextDataIO,
  templates : TemplateResolver,
) -> ContextState {
  { data_io, templates }
}

///|
/// Create context handlers
pub fn create_context_handlers(state : ContextState) -> @api.ContextApiHandlers {
  {
    data_list: @api.RouteHandler(fn(ctx) { handle_data_list(state, ctx) }),
    data_get: @api.RouteHandler(fn(ctx) { handle_data_get(state, ctx) }),
    data_update: @api.RouteHandler(fn(ctx) { handle_data_update(state, ctx) }),
    data_delete: @api.RouteHandler(fn(ctx) { handle_data_delete(state, ctx) }),
    templates_list: @api.RouteHandler(fn(ctx) { handle_templates_list(state, ctx) }),
    templates_get: @api.RouteHandler(fn(ctx) { handle_templates_get(state, ctx) }),
  }
}

// ============================================================
// Data Handlers (/context/data/*)
// ============================================================

///|
/// GET /context/data - List all context data files
fn handle_data_list(
  state : ContextState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let files : Array[ContextFileResponse] = []
  for file_type in all_context_file_types() {
    let path = build_data_file_path(state, file_type)
    let content = (state.data_io.read)(path)
    files.push(ContextFileResponse::from_data(file_type, content))
  }
  let response : ContextFilesListResponse = { files, }
  @api.json_response(200, { "data": response.to_json() })
}

///|
/// GET /context/data/{name} - Get specific context data file
fn handle_data_get(
  state : ContextState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // segments: ["context", "data", "{name}"]
  if ctx.segments.length() < 3 {
    return @api.error_response(
      400, "bad_request", "Context file name is required",
    )
  }
  let name = ctx.segments[2]
  match ContextFileType::from_string(name) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Unknown context file: '\{name}'. Valid names: soul, agents, tools, identity, user, bootstrap, heartbeat",
      )
    Some(file_type) => {
      let path = build_data_file_path(state, file_type)
      let content = (state.data_io.read)(path)
      let response = ContextFileResponse::from_data(file_type, content)
      @api.json_response(200, { "data": response.to_json() })
    }
  }
}

///|
/// PUT /context/data/{name} - Update context data file
fn handle_data_update(
  state : ContextState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // segments: ["context", "data", "{name}"]
  if ctx.segments.length() < 3 {
    return @api.error_response(
      400, "bad_request", "Context file name is required",
    )
  }
  let name = ctx.segments[2]
  match ContextFileType::from_string(name) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Unknown context file: '\{name}'. Valid names: soul, agents, tools, identity, user, bootstrap, heartbeat",
      )
    Some(file_type) =>
      match @api.require_json_object(ctx.body) {
        Err(resp) => resp
        Ok(obj) =>
          match obj.get("content") {
            Some(String(content)) => {
              let path = build_data_file_path(state, file_type)
              if (state.data_io.write)(path, content) {
                let response = ContextFileResponse::from_data(
                  file_type,
                  Some(content),
                )
                @api.json_response(200, {
                  "ok": true,
                  "data": response.to_json(),
                })
              } else {
                @api.error_response(
                  500, "internal_error", "Failed to write context file",
                )
              }
            }
            _ =>
              @api.error_response(
                400, "bad_request", "Field 'content' is required and must be a string",
              )
          }
      }
  }
}

///|
/// DELETE /context/data/{name} - Delete context data file
fn handle_data_delete(
  state : ContextState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // segments: ["context", "data", "{name}"]
  if ctx.segments.length() < 3 {
    return @api.error_response(
      400, "bad_request", "Context file name is required",
    )
  }
  let name = ctx.segments[2]
  match ContextFileType::from_string(name) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Unknown context file: '\{name}'. Valid names: soul, agents, tools, identity, user, bootstrap, heartbeat",
      )
    Some(file_type) => {
      let path = build_data_file_path(state, file_type)
      if (state.data_io.delete)(path) {
        @api.json_response(200, { "ok": true })
      } else {
        @api.error_response(
          500, "internal_error", "Failed to delete context file",
        )
      }
    }
  }
}

// ============================================================
// Template Handlers (/context/templates/*)
// ============================================================

///|
/// GET /context/templates - List all templates
fn handle_templates_list(
  state : ContextState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let files : Array[ContextFileResponse] = []
  for file_type in all_context_file_types() {
    let content = resolve_template(state, file_type)
    files.push(ContextFileResponse::from_template(file_type, content))
  }
  let response : ContextFilesListResponse = { files, }
  @api.json_response(200, { "data": response.to_json() })
}

///|
/// GET /context/templates/{name} - Get specific template
fn handle_templates_get(
  state : ContextState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  // segments: ["context", "templates", "{name}"]
  if ctx.segments.length() < 3 {
    return @api.error_response(
      400, "bad_request", "Template name is required",
    )
  }
  let name = ctx.segments[2]
  match ContextFileType::from_string(name) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Unknown template: '\{name}'. Valid names: soul, agents, tools, identity, user, bootstrap, heartbeat",
      )
    Some(file_type) => {
      let content = resolve_template(state, file_type)
      let response = ContextFileResponse::from_template(file_type, content)
      @api.json_response(200, { "data": response.to_json() })
    }
  }
}

// ============================================================
// Helper Functions
// ============================================================

///|
/// Build full file path for a context data file
fn build_data_file_path(state : ContextState, file_type : ContextFileType) -> String {
  let dir = (state.data_io.get_dir)()
  let filename = file_type.filename()
  let needs_slash = dir.length() > 0 && not(dir.has_suffix("/"))
  if needs_slash {
    dir + "/" + filename
  } else {
    dir + filename
  }
}

///|
/// Resolve template: try installed file first, fall back to embedded
fn resolve_template(state : ContextState, file_type : ContextFileType) -> String {
  let filename = file_type.filename()
  match (state.templates.read_installed)(filename) {
    Some(content) => content
    None => (state.templates.get_embedded)(file_type)
  }
}
