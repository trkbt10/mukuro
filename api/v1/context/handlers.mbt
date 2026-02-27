///|
/// Context Files API Handlers
/// HTTP handlers for /api/v1/context/* endpoints
/// Manages workspace context files (SOUL.md, AGENTS.md, etc.)

///|
/// Context file reader/writer interface
pub(all) struct ContextFileIO {
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
/// Context state holder
pub(all) struct ContextState {
  /// File I/O interface
  io : ContextFileIO
}

///|
/// Create new context state
pub fn ContextState::new(io : ContextFileIO) -> ContextState {
  { io, }
}

///|
/// Create context handlers
pub fn create_context_handlers(state : ContextState) -> @api.ContextApiHandlers {
  {
    list: @api.RouteHandler(fn(ctx) { handle_list(state, ctx) }),
    get: @api.RouteHandler(fn(ctx) { handle_get(state, ctx) }),
    update: @api.RouteHandler(fn(ctx) { handle_update(state, ctx) }),
    delete: @api.RouteHandler(fn(ctx) { handle_delete(state, ctx) }),
  }
}

///|
/// GET /context - List all context files
fn handle_list(
  state : ContextState,
  _ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let files : Array[ContextFileResponse] = []
  for file_type in all_context_file_types() {
    let path = build_file_path(state, file_type)
    let content = (state.io.read)(path)
    files.push(ContextFileResponse::from_type(file_type, content))
  }
  let response : ContextFilesListResponse = { files, }
  @api.json_response(200, { "data": response.to_json() })
}

///|
/// GET /context/{name} - Get specific context file
fn handle_get(
  state : ContextState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(
      400,
      "bad_request",
      "Context file name is required",
    )
  }
  let name = ctx.segments[1]
  match ContextFileType::from_string(name) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Unknown context file: '\{name}'. Valid names: soul, agents, tools, identity, user, bootstrap",
      )
    Some(file_type) => {
      let path = build_file_path(state, file_type)
      let content = (state.io.read)(path)
      let response = ContextFileResponse::from_type(file_type, content)
      @api.json_response(200, { "data": response.to_json() })
    }
  }
}

///|
/// PUT /context/{name} - Update context file
fn handle_update(
  state : ContextState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(
      400,
      "bad_request",
      "Context file name is required",
    )
  }
  let name = ctx.segments[1]
  match ContextFileType::from_string(name) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Unknown context file: '\{name}'. Valid names: soul, agents, tools, identity, user, bootstrap",
      )
    Some(file_type) =>
      match @api.require_json_object(ctx.body) {
        Err(resp) => resp
        Ok(obj) =>
          match obj.get("content") {
            Some(String(content)) => {
              let path = build_file_path(state, file_type)
              if (state.io.write)(path, content) {
                let response = ContextFileResponse::from_type(
                  file_type,
                  Some(content),
                )
                @api.json_response(
                  200,
                  { "ok": true, "data": response.to_json() },
                )
              } else {
                @api.error_response(
                  500,
                  "internal_error",
                  "Failed to write context file",
                )
              }
            }
            _ =>
              @api.error_response(
                400,
                "bad_request",
                "Field 'content' is required and must be a string",
              )
          }
      }
  }
}

///|
/// DELETE /context/{name} - Delete context file
fn handle_delete(
  state : ContextState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  if ctx.segments.length() < 2 {
    return @api.error_response(
      400,
      "bad_request",
      "Context file name is required",
    )
  }
  let name = ctx.segments[1]
  match ContextFileType::from_string(name) {
    None =>
      @api.error_response(
        404,
        "not_found",
        "Unknown context file: '\{name}'. Valid names: soul, agents, tools, identity, user, bootstrap",
      )
    Some(file_type) => {
      let path = build_file_path(state, file_type)
      if (state.io.delete)(path) {
        @api.json_response(200, { "ok": true })
      } else {
        @api.error_response(
          500,
          "internal_error",
          "Failed to delete context file",
        )
      }
    }
  }
}

///|
/// Build full file path for a context file type
fn build_file_path(state : ContextState, file_type : ContextFileType) -> String {
  let dir = (state.io.get_dir)()
  let filename = file_type.filename()
  let needs_slash = dir.length() > 0 && not(dir.has_suffix("/"))
  if needs_slash {
    dir + "/" + filename
  } else {
    dir + filename
  }
}
