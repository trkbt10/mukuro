///|
/// Tool API Handlers
/// HTTP handlers for /api/v1/tools/* endpoints

///|
/// Create tool handlers with state
pub fn create_tool_handlers(state : ToolManagerState) -> @api.ToolApiHandlers {
  {
    list: @api.RouteHandler(fn(ctx) { handle_list(state, ctx) }),
    get: @api.RouteHandler(fn(ctx) { handle_get(state, ctx) }),
    enable: @api.RouteHandler(fn(ctx) { handle_enable(state, ctx) }),
    disable: @api.RouteHandler(fn(ctx) { handle_disable(state, ctx) }),
    remove: @api.RouteHandler(fn(ctx) { handle_remove(state, ctx) }),
    list_actions: @api.RouteHandler(fn(ctx) { handle_list_actions(state, ctx) }),
    invoke_action: @api.RouteHandler(fn(ctx) { handle_invoke_action(state, ctx) }),
  }
}

///|
/// GET /tools - List all tools
fn handle_list(
  state : ToolManagerState,
  _ctx : @api.ApiRequestContext,
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
  ctx : @api.ApiRequestContext,
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
  ctx : @api.ApiRequestContext,
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
  ctx : @api.ApiRequestContext,
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
  ctx : @api.ApiRequestContext,
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

// =============================================================================
// Tool Actions API
// =============================================================================

///|
/// GET /tools/{id}/actions - List available actions for a tool
pub fn handle_list_actions(
  state : ToolManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let segments = ctx.segments
  if segments.length() < 2 {
    return @api.error_response(400, "bad_request", "Tool ID required")
  }
  let id = segments[1].to_string()
  match state.get_tool(id) {
    Some(_) => {
      let actions = state.list_actions(id)
      let actions_json : Array[Json] = actions.map(fn(a) { Json::string(a) })
      @api.json_response(200, {
        "data": { "tool_id": id, "actions": Json::array(actions_json) },
      })
    }
    None => @api.error_response(404, "not_found", "Tool '\{id}' not found")
  }
}

///|
/// POST /tools/{id}/actions/{action} - Invoke a tool action
pub fn handle_invoke_action(
  state : ToolManagerState,
  ctx : @api.ApiRequestContext,
) -> @api.ApiResponse {
  let segments = ctx.segments
  // Expected: ["tools", "{id}", "actions", "{action}"]
  if segments.length() < 4 {
    return @api.error_response(400, "bad_request", "Tool ID and action required")
  }
  let id = segments[1].to_string()
  let action = segments[3].to_string()
  match state.get_tool(id) {
    Some(tool_state) =>
      if not(tool_state.enabled) {
        @api.error_response(
          400,
          "tool_disabled",
          "Tool '\{id}' is disabled",
        )
      } else {
        let params = try {
          @json.parse(ctx.body)
        } catch {
          _ => Json::object({})
        }
        match state.invoke_action(id, action, params) {
          Some(resp) => resp
          None =>
            @api.error_response(
              404,
              "action_not_found",
              "Action '\{action}' not found for tool '\{id}'",
            )
        }
      }
    None => @api.error_response(404, "not_found", "Tool '\{id}' not found")
  }
}
