///|
/// Tool API Schemas
/// Request/Response types for /api/v1/tools endpoints

///|
/// Tool source type as string for JSON
fn source_to_string(source : @interfaces.ToolSource) -> String {
  match source {
    @interfaces.ToolSource::Builtin => "builtin"
    @interfaces.ToolSource::Plugin(_) => "plugin"
    @interfaces.ToolSource::UserDefined => "user_defined"
    @interfaces.ToolSource::MCP(_) => "mcp"
  }
}

///|
/// Extract source ID (plugin_id or mcp_server_id) if applicable
fn source_id(source : @interfaces.ToolSource) -> String? {
  match source {
    @interfaces.ToolSource::Plugin(id) => Some(id)
    @interfaces.ToolSource::MCP(id) => Some(id)
    _ => None
  }
}

///|
/// Tool status to string
fn status_to_string(status : @interfaces.ToolStatus) -> String {
  match status {
    @interfaces.ToolStatus::Available => "available"
    @interfaces.ToolStatus::Disabled => "disabled"
    @interfaces.ToolStatus::Error(_) => "error"
    @interfaces.ToolStatus::Unavailable => "unavailable"
  }
}

///|
/// Tool list item for GET /tools response
pub(all) struct ToolListItem {
  id : String
  name : String
  description : String
  source : String
  source_id : String?
  enabled : Bool
  status : String
}

///|
/// Convert ToolState to ToolListItem
pub fn ToolListItem::from_state(state : @interfaces.ToolState) -> ToolListItem {
  {
    id: state.id,
    name: state.name,
    description: state.description,
    source: source_to_string(state.source),
    source_id: source_id(state.source),
    enabled: state.enabled,
    status: status_to_string(state.status),
  }
}

///|
/// Convert to JSON
pub fn ToolListItem::to_json(self : ToolListItem) -> Json {
  let obj : Map[String, Json] = {}
  obj["id"] = Json::string(self.id)
  obj["name"] = Json::string(self.name)
  obj["description"] = Json::string(self.description)
  obj["source"] = Json::string(self.source)
  match self.source_id {
    Some(id) => obj["source_id"] = Json::string(id)
    None => ()
  }
  obj["enabled"] = Json::boolean(self.enabled)
  obj["status"] = Json::string(self.status)
  Json::object(obj)
}

///|
/// Tool detail response for GET /tools/{id}
pub(all) struct ToolDetailResponse {
  id : String
  name : String
  description : String
  source : String
  source_id : String?
  enabled : Bool
  status : String
  status_message : String?
  loaded_at : Int64
  parameters : Json
}

///|
/// Convert ToolState to ToolDetailResponse
pub fn ToolDetailResponse::from_state(
  state : @interfaces.ToolState
) -> ToolDetailResponse {
  let status_message = match state.status {
    @interfaces.ToolStatus::Error(msg) => Some(msg)
    _ => None
  }
  {
    id: state.id,
    name: state.name,
    description: state.description,
    source: source_to_string(state.source),
    source_id: source_id(state.source),
    enabled: state.enabled,
    status: status_to_string(state.status),
    status_message,
    loaded_at: state.loaded_at,
    parameters: state.parameters,
  }
}

///|
/// Convert to JSON
pub fn ToolDetailResponse::to_json(self : ToolDetailResponse) -> Json {
  let obj : Map[String, Json] = {}
  obj["id"] = Json::string(self.id)
  obj["name"] = Json::string(self.name)
  obj["description"] = Json::string(self.description)
  obj["source"] = Json::string(self.source)
  match self.source_id {
    Some(id) => obj["source_id"] = Json::string(id)
    None => ()
  }
  obj["enabled"] = Json::boolean(self.enabled)
  obj["status"] = Json::string(self.status)
  match self.status_message {
    Some(msg) => obj["status_message"] = Json::string(msg)
    None => ()
  }
  obj["loaded_at"] = Json::number(self.loaded_at.to_double())
  obj["parameters"] = self.parameters
  Json::object(obj)
}

///|
/// Tool stats for list response
pub(all) struct ToolStats {
  total : Int
  enabled : Int
  builtin : Int
  plugin : Int
  user_defined : Int
  mcp : Int
}

///|
/// Convert to JSON
pub fn ToolStats::to_json(self : ToolStats) -> Json {
  {
    "total": self.total,
    "enabled": self.enabled,
    "builtin": self.builtin,
    "plugin": self.plugin,
    "user_defined": self.user_defined,
    "mcp": self.mcp,
  }
}

///|
/// Calculate stats from ToolManagerState
pub fn calculate_stats(state : ToolManagerState) -> ToolStats {
  let counts = state.count_by_source()
  {
    total: state.tools.length(),
    enabled: state.count_enabled(),
    builtin: counts.get("builtin").unwrap_or(0),
    plugin: counts.get("plugin").unwrap_or(0),
    user_defined: counts.get("user_defined").unwrap_or(0),
    mcp: counts.get("mcp").unwrap_or(0),
  }
}
