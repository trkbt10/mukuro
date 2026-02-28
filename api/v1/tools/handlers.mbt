///|
/// Tool API Handlers
/// HTTP handlers for /api/v1/tools/* endpoints

///|
/// Create tool handlers with state
pub fn create_tool_handlers(
  state : ToolManagerState
) -> @api.ToolApiHandlers {
  {
    list: @api.RouteHandler(fn(ctx) { handle_list(state, ctx) }),
    get: @api.RouteHandler(fn(ctx) { handle_get(state, ctx) }),
    enable: @api.RouteHandler(fn(ctx) { handle_enable(state, ctx) }),
    disable: @api.RouteHandler(fn(ctx) { handle_disable(state, ctx) }),
    remove: @api.RouteHandler(fn(ctx) { handle_remove(state, ctx) }),
  }
}

///|
/// GET /tools - List all tools
fn handle_list(
  state : ToolManagerState,
  _ctx : @api.ApiRequestContext
) -> @api.ApiResponse {
  let items : Array[Json] = []
  for _, tool_state in state.tools {
    let item = ToolListItem::from_state(tool_state)
    items.push(item.to_json())
  }
  let stats = calculate_stats(state)
  @api.json_response(200, {
    "data": Json::array(items),
    "stats": stats.to_json(),
  })
}

///|
/// GET /tools/{id} - Get tool details
fn handle_get(
  state : ToolManagerState,
  ctx : @api.ApiRequestContext
) -> @api.ApiResponse {
  let segments = ctx.segments
  if segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Tool ID required")
  }
  let id = segments[1].to_string()
  match state.get_tool(id) {
    Some(tool_state) => {
      let detail = ToolDetailResponse::from_state(tool_state)
      @api.json_response(200, { "data": detail.to_json() })
    }
    None => @api.error_response(404, "not_found", "Tool '\{id}' not found")
  }
}

///|
/// PUT /tools/{id}/enable - Enable a tool
fn handle_enable(
  state : ToolManagerState,
  ctx : @api.ApiRequestContext
) -> @api.ApiResponse {
  let segments = ctx.segments
  if segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Tool ID required")
  }
  let id = segments[1].to_string()
  match state.get_tool(id) {
    Some(_) => {
      ignore(state.set_tool_enabled(id, true))
      ignore(state.set_tool_status(id, @interfaces.ToolStatus::Available))
      @api.json_response(200, { "ok": true, "id": id, "enabled": true })
    }
    None => @api.error_response(404, "not_found", "Tool '\{id}' not found")
  }
}

///|
/// PUT /tools/{id}/disable - Disable a tool
fn handle_disable(
  state : ToolManagerState,
  ctx : @api.ApiRequestContext
) -> @api.ApiResponse {
  let segments = ctx.segments
  if segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Tool ID required")
  }
  let id = segments[1].to_string()
  match state.get_tool(id) {
    Some(_) => {
      ignore(state.set_tool_enabled(id, false))
      ignore(state.set_tool_status(id, @interfaces.ToolStatus::Disabled))
      @api.json_response(200, { "ok": true, "id": id, "enabled": false })
    }
    None => @api.error_response(404, "not_found", "Tool '\{id}' not found")
  }
}

///|
/// DELETE /tools/{id} - Remove a tool (user-defined only)
fn handle_remove(
  state : ToolManagerState,
  ctx : @api.ApiRequestContext
) -> @api.ApiResponse {
  let segments = ctx.segments
  if segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Tool ID required")
  }
  let id = segments[1].to_string()
  match state.get_tool(id) {
    Some(tool_state) =>
      // Check if builtin (Plugin("builtin"))
      if tool_state.source.is_builtin() {
        @api.error_response(
          403,
          "forbidden",
          "Cannot remove builtin tool '\{id}'",
        )
      } else {
        state.remove_tool_state(id)
        @api.json_response(200, { "ok": true, "id": id, "removed": true })
      }
    None => @api.error_response(404, "not_found", "Tool '\{id}' not found")
  }
}
