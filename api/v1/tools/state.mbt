///|
/// Tool API State Management
/// Holds tool states for the API layer

///|
/// Tool action handler type
pub(all) struct ToolActionHandler((Json) -> @api.ApiResponse)

///|
/// Tool manager state holder
pub(all) struct ToolManagerState {
  /// Tool states by ID
  tools : Map[String, @interfaces.ToolState]
  /// Tool actions: tool_id -> action_name -> handler
  actions : Map[String, Map[String, ToolActionHandler]]
}

///|
/// Create empty tool manager state
pub fn ToolManagerState::new() -> ToolManagerState {
  { tools: {}, actions: {} }
}

///|
/// Set tool state
pub fn ToolManagerState::set_tool(
  self : ToolManagerState,
  id : String,
  state : @interfaces.ToolState,
) -> Unit {
  self.tools[id] = state
}

///|
/// Get tool state
pub fn ToolManagerState::get_tool(
  self : ToolManagerState,
  id : String,
) -> @interfaces.ToolState? {
  self.tools.get(id)
}

///|
/// Remove tool state
pub fn ToolManagerState::remove_tool_state(
  self : ToolManagerState,
  id : String,
) -> Unit {
  self.tools.remove(id)
}

///|
/// List all tool states
pub fn ToolManagerState::list_tools(
  self : ToolManagerState,
) -> Array[@interfaces.ToolState] {
  self.tools.values().collect()
}

///|
/// Update tool enabled status
pub fn ToolManagerState::set_tool_enabled(
  self : ToolManagerState,
  id : String,
  enabled : Bool,
) -> Bool {
  match self.tools.get(id) {
    Some(state) => {
      self.tools[id] = { ..state, enabled, }
      true
    }
    None => false
  }
}

///|
/// Update tool status
pub fn ToolManagerState::set_tool_status(
  self : ToolManagerState,
  id : String,
  status : @interfaces.ToolStatus,
) -> Bool {
  match self.tools.get(id) {
    Some(state) => {
      self.tools[id] = { ..state, status, }
      true
    }
    None => false
  }
}

///|
/// Check if tool is builtin (source is Plugin("builtin"))
pub fn ToolManagerState::is_builtin(
  self : ToolManagerState,
  id : String,
) -> Bool {
  match self.tools.get(id) {
    Some(state) => state.source.is_builtin()
    None => false
  }
}

///|
/// Count tools by source type
pub fn ToolManagerState::count_by_source(
  self : ToolManagerState,
) -> Map[String, Int] {
  let counts : Map[String, Int] = {}
  for _, state in self.tools {
    let key = match state.source {
      @interfaces.ToolSource::Plugin(_) => "plugin"
      @interfaces.ToolSource::UserDefined => "user_defined"
      @interfaces.ToolSource::MCP(_) => "mcp"
    }
    counts[key] = counts.get(key).unwrap_or(0) + 1
  }
  counts
}

///|
/// Count enabled tools
pub fn ToolManagerState::count_enabled(self : ToolManagerState) -> Int {
  let mut count = 0
  for _, state in self.tools {
    if state.enabled {
      count += 1
    }
  }
  count
}

// =============================================================================
// Tool Actions
// =============================================================================

///|
/// Register an action for a tool
pub fn ToolManagerState::register_action(
  self : ToolManagerState,
  tool_id : String,
  action_name : String,
  handler : ToolActionHandler,
) -> Unit {
  match self.actions.get(tool_id) {
    Some(tool_actions) => tool_actions[action_name] = handler
    None => {
      let tool_actions : Map[String, ToolActionHandler] = {}
      tool_actions[action_name] = handler
      self.actions[tool_id] = tool_actions
    }
  }
}

///|
/// List actions for a tool
pub fn ToolManagerState::list_actions(
  self : ToolManagerState,
  tool_id : String,
) -> Array[String] {
  match self.actions.get(tool_id) {
    Some(tool_actions) => tool_actions.keys().collect()
    None => []
  }
}

///|
/// Invoke an action for a tool
pub fn ToolManagerState::invoke_action(
  self : ToolManagerState,
  tool_id : String,
  action_name : String,
  params : Json,
) -> @api.ApiResponse? {
  match self.actions.get(tool_id) {
    Some(tool_actions) =>
      match tool_actions.get(action_name) {
        Some(ToolActionHandler(handler)) => Some(handler(params))
        None => None
      }
    None => None
  }
}

///|
/// Check if a tool has actions
pub fn ToolManagerState::has_actions(
  self : ToolManagerState,
  tool_id : String,
) -> Bool {
  match self.actions.get(tool_id) {
    Some(tool_actions) => tool_actions.length() > 0
    None => false
  }
}
