///|
/// Context Files API Schemas
/// Request/Response schemas for context file endpoints

///|
/// Context file types
pub(all) enum ContextFileType {
  Soul
  Agents
  Tools
  Identity
  User
  Bootstrap
} derive(Eq, Show)

///|
/// Convert string to ContextFileType
pub fn ContextFileType::from_string(s : String) -> ContextFileType? {
  match s.to_lower() {
    "soul" => Some(ContextFileType::Soul)
    "agents" => Some(ContextFileType::Agents)
    "tools" => Some(ContextFileType::Tools)
    "identity" => Some(ContextFileType::Identity)
    "user" => Some(ContextFileType::User)
    "bootstrap" => Some(ContextFileType::Bootstrap)
    _ => None
  }
}

///|
/// Convert ContextFileType to string
pub fn ContextFileType::to_string(self : ContextFileType) -> String {
  match self {
    ContextFileType::Soul => "soul"
    ContextFileType::Agents => "agents"
    ContextFileType::Tools => "tools"
    ContextFileType::Identity => "identity"
    ContextFileType::User => "user"
    ContextFileType::Bootstrap => "bootstrap"
  }
}

///|
/// Get filename for context file type
pub fn ContextFileType::filename(self : ContextFileType) -> String {
  match self {
    ContextFileType::Soul => "SOUL.md"
    ContextFileType::Agents => "AGENTS.md"
    ContextFileType::Tools => "TOOLS.md"
    ContextFileType::Identity => "IDENTITY.md"
    ContextFileType::User => "USER.md"
    ContextFileType::Bootstrap => "bootstrap.md"
  }
}

///|
/// Get description for context file type
pub fn ContextFileType::description(self : ContextFileType) -> String {
  match self {
    ContextFileType::Soul => "AI personality and core values"
    ContextFileType::Agents => "Workspace handbook and guidelines"
    ContextFileType::Tools => "Local tools and environment configuration"
    ContextFileType::Identity => "AI identity and name"
    ContextFileType::User => "User preferences and context"
    ContextFileType::Bootstrap => "Base system instructions"
  }
}

///|
/// All context file types
pub fn all_context_file_types() -> Array[ContextFileType] {
  [
    ContextFileType::Soul,
    ContextFileType::Identity,
    ContextFileType::Bootstrap,
    ContextFileType::Agents,
    ContextFileType::Tools,
    ContextFileType::User,
  ]
}

///|
/// Single context file response
pub(all) struct ContextFileResponse {
  name : String
  filename : String
  description : String
  content : String
  exists : Bool
}

///|
/// Convert to JSON
pub fn ContextFileResponse::to_json(self : ContextFileResponse) -> Json {
  {
    "name": self.name,
    "filename": self.filename,
    "description": self.description,
    "content": self.content,
    "exists": Json::boolean(self.exists),
  }
}

///|
/// Create from file type and content
pub fn ContextFileResponse::from_type(
  file_type : ContextFileType,
  content : String?,
) -> ContextFileResponse {
  let (actual_content, exists) = match content {
    Some(c) => (c, true)
    None => ("", false)
  }
  {
    name: file_type.to_string(),
    filename: file_type.filename(),
    description: file_type.description(),
    content: actual_content,
    exists,
  }
}

///|
/// All context files response
pub(all) struct ContextFilesListResponse {
  files : Array[ContextFileResponse]
}

///|
/// Convert to JSON
pub fn ContextFilesListResponse::to_json(self : ContextFilesListResponse) -> Json {
  let arr : Array[Json] = []
  for f in self.files {
    arr.push(f.to_json())
  }
  Json::object({ "files": Json::array(arr) })
}
