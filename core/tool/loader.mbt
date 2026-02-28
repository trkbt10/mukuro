///|
/// Tool Loader
/// Loads user-defined tools from {data_dir}/tools/ directory

///|
/// Tool manifest structure (parsed from tool.json)
pub(all) struct ToolManifest {
  /// Tool ID (unique identifier)
  id : String
  /// Display name
  name : String
  /// Human-readable description
  description : String
  /// JSON Schema for parameters
  parameters : Json
}

///|
/// Parse tool manifest from JSON
pub fn ToolManifest::from_json(json : Json) -> ToolManifest? {
  match json {
    Object(obj) => {
      let id = match obj.get("id") {
        Some(String(s)) => s
        _ => return None
      }
      let name = match obj.get("name") {
        Some(String(s)) => s
        _ => id // fallback to id
      }
      let description = match obj.get("description") {
        Some(String(s)) => s
        _ => ""
      }
      let parameters = match obj.get("parameters") {
        Some(p) => p
        _ => Json::object({}) // empty parameters
      }
      Some({ id, name, description, parameters })
    }
    _ => None
  }
}

///|
/// Convert manifest to ToolState
pub fn ToolManifest::to_tool_state(self : ToolManifest) -> @interfaces.ToolState {
  @interfaces.ToolState::user_defined(
    id=self.id,
    name=self.name,
    description=self.description,
    parameters=self.parameters,
  )
}

///|
/// Tool loader file operations interface
pub(all) struct ToolLoaderIO {
  /// List subdirectories in tools directory
  list_tool_dirs : () -> Array[String]
  /// Read tool.json from a tool directory
  read_manifest : (String) -> String?
}

///|
/// Load all user-defined tools from tools directory
pub fn load_user_defined_tools(io : ToolLoaderIO) -> Array[@interfaces.ToolState] {
  let tools : Array[@interfaces.ToolState] = []
  let dirs = (io.list_tool_dirs)()
  for dir in dirs {
    match (io.read_manifest)(dir) {
      Some(content) => {
        let json = @json.parse(content) catch { _ => continue }
        match ToolManifest::from_json(json) {
          Some(manifest) => tools.push(manifest.to_tool_state())
          None => () // Skip invalid manifests
        }
      }
      None => () // Skip directories without tool.json
    }
  }
  tools
}

///|
/// Load a single tool from manifest content
pub fn load_tool_from_manifest(
  content : String
) -> @interfaces.ToolState raise @interfaces.ToolManagerError {
  let json = @json.parse(content) catch { e =>
    raise @interfaces.ToolManagerError::ManifestInvalid("JSON parse error: \{e}")
  }
  match ToolManifest::from_json(json) {
    Some(manifest) => manifest.to_tool_state()
    None =>
      raise @interfaces.ToolManagerError::ManifestInvalid(
        "Missing required fields (id, name, description)",
      )
  }
}
