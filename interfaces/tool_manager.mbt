///|
/// Dynamic tool management interfaces

///|
/// Tool source type - distinguishes plugin-provided from user-defined tools
pub(all) enum ToolSource {
  /// Provided by a plugin (plugin_id as payload; "builtin" for built-in tools)
  Plugin(String)
  /// User-defined tool from {data_dir}/tools/
  UserDefined
  /// MCP server tool (server_id as payload)
  MCP(String)
}

///|
/// Check if tool source is from the builtin plugin
pub fn ToolSource::is_builtin(self : ToolSource) -> Bool {
  match self {
    Plugin("builtin") => true
    _ => false
  }
}

///|
/// Tool operational status
pub(all) enum ToolStatus {
  /// Tool is available for use
  Available
  /// Tool is disabled by user
  Disabled
  /// Tool failed to load or has runtime error
  Error(String)
  /// Tool's dependency (plugin/MCP server) is not running
  Unavailable
}

///|
/// Tool state for dynamic management
pub(all) struct ToolState {
  /// Tool ID (unique name)
  id : String
  /// Display name
  name : String
  /// Tool source type
  source : ToolSource
  /// Whether the tool is enabled (included in LLM tool list)
  enabled : Bool
  /// Current operational status
  status : ToolStatus
  /// Load timestamp (Unix seconds)
  loaded_at : Int64
  /// Human-readable description
  description : String
  /// JSON Schema for parameters (passed to LLM)
  parameters : Json
  /// Settings schema for UI configuration (optional)
  settings_schema : Json?
}

///|
/// Create builtin tool state (source: Plugin("builtin"))
pub fn ToolState::builtin(
  id~ : String,
  name~ : String,
  description~ : String,
  parameters~ : Json,
  settings_schema? : Json? = None,
) -> ToolState {
  {
    id,
    name,
    source: ToolSource::Plugin("builtin"),
    enabled: true,
    status: ToolStatus::Available,
    loaded_at: 0L,
    description,
    parameters,
    settings_schema,
  }
}

///|
/// Create user-defined tool state
pub fn ToolState::user_defined(
  id~ : String,
  name~ : String,
  description~ : String,
  parameters~ : Json,
  settings_schema? : Json? = None,
) -> ToolState {
  {
    id,
    name,
    source: ToolSource::UserDefined,
    enabled: true,
    status: ToolStatus::Available,
    loaded_at: 0L,
    description,
    parameters,
    settings_schema,
  }
}

///|
/// Create plugin-provided tool state
pub fn ToolState::from_plugin(
  plugin_id~ : String,
  capability~ : String,
  description~ : String,
  parameters~ : Json,
  settings_schema? : Json? = None,
) -> ToolState {
  let id = "\{plugin_id}.\{capability}"
  {
    id,
    name: capability,
    source: ToolSource::Plugin(plugin_id),
    enabled: true,
    status: ToolStatus::Available,
    loaded_at: 0L,
    description,
    parameters,
    settings_schema,
  }
}

///|
/// Create MCP server tool state
pub fn ToolState::from_mcp(
  server_id~ : String,
  tool_name~ : String,
  description~ : String,
  parameters~ : Json,
  settings_schema? : Json? = None,
) -> ToolState {
  let id = "\{server_id}.\{tool_name}"
  {
    id,
    name: tool_name,
    source: ToolSource::MCP(server_id),
    enabled: true,
    status: ToolStatus::Available,
    loaded_at: 0L,
    description,
    parameters,
    settings_schema,
  }
}

///|
/// Tool manager error types
pub(all) suberror ToolManagerError {
  /// Tool not found
  NotFound(String)
  /// Tool already exists
  AlreadyExists(String)
  /// Cannot modify builtin tool (delete)
  CannotModifyBuiltin(String)
  /// Invalid tool manifest
  ManifestInvalid(String)
  /// Tool load failed
  LoadFailed(String)
  /// Filesystem error
  FilesystemError(String)
}

///|
/// Dynamic tool manager trait
pub(open) trait DynamicToolManager {
  /// Scan tools directory for available user-defined tools
  scan_tools(Self) -> Array[String] raise ToolManagerError

  /// Load a tool from manifest path
  load_tool(Self, manifest_path~ : String) -> ToolState raise ToolManagerError

  /// Enable a tool (include in LLM tool list)
  enable_tool(Self, id~ : String) -> Unit raise ToolManagerError

  /// Disable a tool (exclude from LLM tool list)
  disable_tool(Self, id~ : String) -> Unit raise ToolManagerError

  /// Remove a user-defined tool
  remove_tool(Self, id~ : String) -> Unit raise ToolManagerError

  /// Reload a tool (re-read manifest)
  reload_tool(Self, id~ : String) -> Unit raise ToolManagerError

  /// Get tool state by ID
  get_tool_state(Self, id~ : String) -> ToolState?

  /// List all tool states
  list_tool_states(Self) -> Array[ToolState]

  /// List only enabled tools as ToolDefinition (for LLM)
  list_enabled_definitions(Self) -> Array[@types.ToolDefinition]

  /// Check if a tool exists
  has_tool(Self, id~ : String) -> Bool
}
