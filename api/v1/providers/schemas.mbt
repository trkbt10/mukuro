///|
/// Message Provider API Schemas
/// Request/Response schemas for provider endpoints

///|
/// Provider list item response
pub(all) struct ProviderListItem {
  id : String
  name : String
  provider_type : String
  enabled : Bool
  status : String
  messages_sent : Int64
  messages_received : Int64
}

///|
/// Convert to JSON
pub fn ProviderListItem::to_json(self : ProviderListItem) -> Json {
  {
    "id": self.id,
    "name": self.name,
    "provider_type": self.provider_type,
    "enabled": Json::boolean(self.enabled),
    "status": self.status,
    "messages_sent": self.messages_sent.to_double(),
    "messages_received": self.messages_received.to_double(),
  }
}

///|
/// Provider detail response
pub(all) struct ProviderDetailResponse {
  id : String
  name : String
  provider_type : String
  enabled : Bool
  auto_connect : Bool
  status : String
  last_connected_at : Int64
  last_error : String?
  messages_sent : Int64
  messages_received : Int64
  settings : Map[String, Json]
  capabilities : CapabilitiesResponse
}

///|
/// Capabilities response
pub(all) struct CapabilitiesResponse {
  can_send : Bool
  can_receive : Bool
  supports_rich_text : Bool
  supports_attachments : Bool
  supports_reactions : Bool
  supports_threads : Bool
  supports_edit : Bool
  supports_delete : Bool
}

///|
/// Convert capabilities to JSON
pub fn CapabilitiesResponse::to_json(self : CapabilitiesResponse) -> Json {
  {
    "can_send": Json::boolean(self.can_send),
    "can_receive": Json::boolean(self.can_receive),
    "supports_rich_text": Json::boolean(self.supports_rich_text),
    "supports_attachments": Json::boolean(self.supports_attachments),
    "supports_reactions": Json::boolean(self.supports_reactions),
    "supports_threads": Json::boolean(self.supports_threads),
    "supports_edit": Json::boolean(self.supports_edit),
    "supports_delete": Json::boolean(self.supports_delete),
  }
}

///|
/// Convert detail to JSON
pub fn ProviderDetailResponse::to_json(self : ProviderDetailResponse) -> Json {
  let obj : Map[String, Json] = {
    "id": Json::string(self.id),
    "name": Json::string(self.name),
    "provider_type": Json::string(self.provider_type),
    "enabled": Json::boolean(self.enabled),
    "auto_connect": Json::boolean(self.auto_connect),
    "status": Json::string(self.status),
    "last_connected_at": Json::number(self.last_connected_at.to_double()),
    "messages_sent": Json::number(self.messages_sent.to_double()),
    "messages_received": Json::number(self.messages_received.to_double()),
    "settings": Json::object(mask_secrets(self.settings)),
    "capabilities": self.capabilities.to_json(),
  }
  match self.last_error {
    Some(err) => obj["last_error"] = Json::string(err)
    None => obj["last_error"] = Json::null()
  }
  Json::object(obj)
}

///|
/// Check if a key name indicates a secret value
pub fn is_secret_key(key : String) -> Bool {
  let k = key.to_lower()
  k.has_suffix("_token") ||
  k.has_suffix("_secret") ||
  k.has_suffix("_key") ||
  k.has_suffix("_password") ||
  k.has_suffix("_credential") ||
  k == "token" ||
  k == "secret" ||
  k == "password" ||
  k == "api_key" ||
  k == "apikey" ||
  k == "private_key" ||
  k == "access_key" ||
  k == "secret_key" ||
  k == "auth_token" ||
  k == "credentials"
}

///|
/// Mask secret fields in settings
fn mask_secrets(settings : Map[String, Json]) -> Map[String, Json] {
  let result : Map[String, Json] = {}
  for key, value in settings {
    if is_secret_key(key) {
      match value {
        String(s) =>
          if s.length() > 0 {
            result[key] = Json::string("••••••••")
          } else {
            result[key] = value
          }
        _ => result[key] = value
      }
    } else {
      result[key] = value
    }
  }
  result
}

///|
/// Provider add request
pub(all) struct ProviderAddRequest {
  id : String
  name : String
  provider_type : String
  enabled : Bool?
  auto_connect : Bool?
  settings : Map[String, Json]
}

///|
/// Parse from JSON
pub fn ProviderAddRequest::from_json(obj : Map[String, Json]) -> ProviderAddRequest? {
  let id = match obj.get("id") {
    Some(String(s)) => s
    _ => return None
  }
  let name = match obj.get("name") {
    Some(String(s)) => s
    _ => return None
  }
  let provider_type = match obj.get("provider_type") {
    Some(String(s)) => s
    _ => return None
  }
  let enabled = match obj.get("enabled") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  let auto_connect = match obj.get("auto_connect") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  let settings = match obj.get("settings") {
    Some(Object(s)) => s
    _ => {}
  }
  Some({ id, name, provider_type, enabled, auto_connect, settings })
}

///|
/// Provider update request
pub(all) struct ProviderUpdateRequest {
  name : String?
  enabled : Bool?
  auto_connect : Bool?
  settings : Map[String, Json]?
}

///|
/// Parse from JSON
pub fn ProviderUpdateRequest::from_json(
  obj : Map[String, Json],
) -> ProviderUpdateRequest {
  let name = match obj.get("name") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let enabled = match obj.get("enabled") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  let auto_connect = match obj.get("auto_connect") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  let settings = match obj.get("settings") {
    Some(Object(s)) => Some(s)
    _ => None
  }
  { name, enabled, auto_connect, settings }
}

///|
/// Settings schema field response
pub(all) struct SettingsFieldResponse {
  key : String
  label : String
  field_type : String
  required : Bool
  description : String
  default_value : Json?
  is_secret : Bool
  options : Array[String]?
}

///|
/// Convert to JSON
pub fn SettingsFieldResponse::to_json(self : SettingsFieldResponse) -> Json {
  let obj : Map[String, Json] = {
    "key": Json::string(self.key),
    "label": Json::string(self.label),
    "field_type": Json::string(self.field_type),
    "required": Json::boolean(self.required),
    "description": Json::string(self.description),
    "is_secret": Json::boolean(self.is_secret),
  }
  match self.default_value {
    Some(v) => obj["default_value"] = v
    None => obj["default_value"] = Json::null()
  }
  match self.options {
    Some(opts) => {
      let arr : Array[Json] = []
      for opt in opts {
        arr.push(Json::string(opt))
      }
      obj["options"] = Json::array(arr)
    }
    None => ()
  }
  Json::object(obj)
}

///|
/// Settings schema response
pub(all) struct SettingsSchemaResponse {
  provider_type : String
  fields : Array[SettingsFieldResponse]
}

///|
/// Convert to JSON
pub fn SettingsSchemaResponse::to_json(self : SettingsSchemaResponse) -> Json {
  let fields_arr : Array[Json] = []
  for field in self.fields {
    fields_arr.push(field.to_json())
  }
  { "provider_type": self.provider_type, "fields": Json::array(fields_arr) }
}

///|
/// Convert ProviderSettingsSchema to response
pub fn settings_schema_to_response(
  schema : @interfaces.ProviderSettingsSchema,
) -> SettingsSchemaResponse {
  let fields : Array[SettingsFieldResponse] = []
  for field in schema.fields {
    let (field_type, options) = match field.field_type {
      @interfaces.ProviderFieldType::Select(opts) => ("select", Some(opts))
      other => (other.to_string(), None)
    }
    fields.push(
      {
        key: field.key,
        label: field.label,
        field_type,
        required: field.required,
        description: field.description,
        default_value: field.default_value,
        is_secret: field.is_secret,
        options,
      },
    )
  }
  { provider_type: schema.provider_type.to_string(), fields }
}

///|
/// Provider types list response
pub(all) struct ProviderTypesResponse {
  types : Array[ProviderTypeInfo]
}

///|
/// Provider type info
pub(all) struct ProviderTypeInfo {
  id : String
  name : String
  description : String
}

///|
/// Convert to JSON
pub fn ProviderTypeInfo::to_json(self : ProviderTypeInfo) -> Json {
  { "id": self.id, "name": self.name, "description": self.description }
}

///|
/// Get all provider types
pub fn get_provider_types() -> Array[ProviderTypeInfo] {
  [
    {
      id: "slack",
      name: "Slack",
      description: "Connect to Slack workspaces using Bot Token and Socket Mode or Events API",
    },
    {
      id: "discord",
      name: "Discord",
      description: "Connect to Discord servers using a Bot Token",
    },
    {
      id: "telegram",
      name: "Telegram",
      description: "Connect to Telegram using Bot API with webhooks or polling",
    },
    {
      id: "webhook",
      name: "Webhook",
      description: "Send messages to a custom webhook endpoint",
    },
    {
      id: "websocket",
      name: "WebSocket",
      description: "Connect to a WebSocket endpoint for real-time messaging",
    },
  ]
}
