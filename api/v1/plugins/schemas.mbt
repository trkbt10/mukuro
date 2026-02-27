///|
/// Plugin API Schemas
/// Request/Response schemas for plugin endpoints

///|
/// Plugin list item response
pub(all) struct PluginListItem {
  id : String
  name : String
  version : String
  description : String
  enabled : Bool
  status : String
  loaded_at : Int64
  is_builtin : Bool
}

///|
/// Convert to JSON
pub fn PluginListItem::to_json(self : PluginListItem) -> Json {
  {
    "id": self.id,
    "name": self.name,
    "version": self.version,
    "description": self.description,
    "enabled": Json::boolean(self.enabled),
    "status": self.status,
    "loaded_at": self.loaded_at.to_double(),
    "is_builtin": Json::boolean(self.is_builtin),
  }
}

///|
/// Plugin detail response
pub(all) struct PluginDetailResponse {
  id : String
  name : String
  version : String
  description : String
  author : String?
  enabled : Bool
  status : String
  loaded_at : Int64
  modified_at : Int64
  permissions : Array[String]
  settings_schema : Json?
  is_builtin : Bool
}

///|
/// Convert to JSON
pub fn PluginDetailResponse::to_json(self : PluginDetailResponse) -> Json {
  let obj : Map[String, Json] = {}
  obj["id"] = Json::string(self.id)
  obj["name"] = Json::string(self.name)
  obj["version"] = Json::string(self.version)
  obj["description"] = Json::string(self.description)
  match self.author {
    Some(a) => obj["author"] = Json::string(a)
    None => obj["author"] = Json::null()
  }
  obj["enabled"] = Json::boolean(self.enabled)
  obj["status"] = Json::string(self.status)
  obj["loaded_at"] = Json::number(self.loaded_at.to_double())
  obj["modified_at"] = Json::number(self.modified_at.to_double())
  let perms : Array[Json] = []
  for p in self.permissions {
    perms.push(Json::string(p))
  }
  obj["permissions"] = Json::array(perms)
  match self.settings_schema {
    Some(s) => obj["settings_schema"] = s
    None => obj["settings_schema"] = Json::null()
  }
  obj["is_builtin"] = Json::boolean(self.is_builtin)
  Json::object(obj)
}

///|
/// Plugin add request
pub(all) struct PluginAddRequest {
  manifest_path : String
  enabled : Bool?
  auto_start : Bool?
}

///|
/// Parse from JSON
pub fn PluginAddRequest::from_json(obj : Map[String, Json]) -> PluginAddRequest? {
  let manifest_path = match obj.get("manifest_path") {
    Some(String(s)) => s
    _ => return None
  }
  let enabled = match obj.get("enabled") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  let auto_start = match obj.get("auto_start") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  Some({ manifest_path, enabled, auto_start })
}

///|
/// Plugin settings response
pub(all) struct PluginSettingsResponse {
  plugin_id : String
  settings : Map[String, Json]
}

///|
/// Convert to JSON
pub fn PluginSettingsResponse::to_json(self : PluginSettingsResponse) -> Json {
  { "plugin_id": self.plugin_id, "settings": Json::object(self.settings) }
}

///|
/// Plugin permission types
pub(all) enum PluginPermission {
  /// Network access to specific hosts
  NetworkAccess(Array[String])
  /// File read access to paths
  FileRead(Array[String])
  /// File write access to paths
  FileWrite(Array[String])
  /// Process spawn permission
  ProcessSpawn
  /// Environment variable access
  EnvAccess(Array[String])
}

///|
/// Convert permission to string
pub fn PluginPermission::to_string(self : PluginPermission) -> String {
  match self {
    PluginPermission::NetworkAccess(hosts) => "network:\{hosts.length()} hosts"
    PluginPermission::FileRead(paths) => "file_read:\{paths.length()} paths"
    PluginPermission::FileWrite(paths) => "file_write:\{paths.length()} paths"
    PluginPermission::ProcessSpawn => "process_spawn"
    PluginPermission::EnvAccess(keys) => "env:\{keys.length()} keys"
  }
}
