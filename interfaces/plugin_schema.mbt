///|
/// Plugin capability schema types
/// Used for automatic ToolDefinition generation from plugin manifests

///|
/// Capability schema definition
pub(all) struct CapabilitySchema {
  /// Human-readable description
  description : String
  /// JSON Schema for parameters
  parameters : Json
  /// JSON Schema for return value (optional)
  returns : Json?
  /// Example invocations
  examples : Array[Json]
}

///|
/// Default capability schema
pub fn CapabilitySchema::default(description~ : String) -> CapabilitySchema {
  { description, parameters: Json::object({}), returns: None, examples: [] }
}

///|
/// Create capability schema with parameters
pub fn CapabilitySchema::with_params(
  description~ : String,
  parameters~ : Json,
) -> CapabilitySchema {
  { description, parameters, returns: None, examples: [] }
}

///|
/// Create full capability schema
pub fn CapabilitySchema::full(
  description~ : String,
  parameters~ : Json,
  returns~ : Json,
  examples~ : Array[Json],
) -> CapabilitySchema {
  { description, parameters, returns: Some(returns), examples }
}

///|
/// JSON Schema property definition
pub(all) struct JsonSchemaProperty {
  /// Property type (string, number, boolean, object, array)
  schema_type : String
  /// Property description
  description : String
  /// Whether the property is required
  required : Bool
  /// Default value
  default_value : Json?
  /// Enum values (for restricted types)
  enum_values : Array[Json]?
}

///|
/// Default schema property
pub fn JsonSchemaProperty::string(description~ : String) -> JsonSchemaProperty {
  {
    schema_type: "string",
    description,
    required: true,
    default_value: None,
    enum_values: None,
  }
}

///|
/// Create optional string property
pub fn JsonSchemaProperty::optional_string(
  description~ : String,
  default~ : String?,
) -> JsonSchemaProperty {
  {
    schema_type: "string",
    description,
    required: false,
    default_value: match default {
      Some(d) => Some(Json::string(d))
      None => None
    },
    enum_values: None,
  }
}

///|
/// Create number property
pub fn JsonSchemaProperty::number(description~ : String) -> JsonSchemaProperty {
  {
    schema_type: "number",
    description,
    required: true,
    default_value: None,
    enum_values: None,
  }
}

///|
/// Create boolean property
pub fn JsonSchemaProperty::boolean(
  description~ : String,
  default~ : Bool?,
) -> JsonSchemaProperty {
  {
    schema_type: "boolean",
    description,
    required: match default {
      Some(_) => false
      None => true
    },
    default_value: match default {
      Some(d) => Some(Json::boolean(d))
      None => None
    },
    enum_values: None,
  }
}

///|
/// Convert property to JSON Schema
pub fn JsonSchemaProperty::to_json(self : JsonSchemaProperty) -> Json {
  let obj : Map[String, Json] = {
    "type": Json::string(self.schema_type),
    "description": Json::string(self.description),
  }
  match self.default_value {
    Some(d) => obj["default"] = d
    None => ()
  }
  match self.enum_values {
    Some(values) => obj["enum"] = Json::array(values)
    None => ()
  }
  Json::object(obj)
}

///|
/// JSON Schema builder
pub struct JsonSchemaBuilder {
  /// Properties
  properties : Map[String, JsonSchemaProperty]
  /// Required property names
  required : Array[String]
  /// Schema description
  description : String?
}

///|
/// Create a new schema builder
pub fn JsonSchemaBuilder::new() -> JsonSchemaBuilder {
  { properties: {}, required: [], description: None }
}

///|
/// Add a property
pub fn JsonSchemaBuilder::add_property(
  self : JsonSchemaBuilder,
  name : String,
  prop : JsonSchemaProperty,
) -> JsonSchemaBuilder {
  self.properties[name] = prop
  if prop.required {
    self.required.push(name)
  }
  self
}

///|
/// Set description
pub fn JsonSchemaBuilder::with_description(
  self : JsonSchemaBuilder,
  description : String,
) -> JsonSchemaBuilder {
  {
    properties: self.properties,
    required: self.required,
    description: Some(description),
  }
}

///|
/// Build the JSON Schema
pub fn JsonSchemaBuilder::build(self : JsonSchemaBuilder) -> Json {
  let props : Map[String, Json] = {}
  for name, prop in self.properties {
    props[name] = prop.to_json()
  }
  let required_json : Array[Json] = []
  for name in self.required {
    required_json.push(Json::string(name))
  }
  let obj : Map[String, Json] = {
    "type": Json::string("object"),
    "properties": Json::object(props),
    "required": Json::array(required_json),
  }
  match self.description {
    Some(d) => obj["description"] = Json::string(d)
    None => ()
  }
  Json::object(obj)
}

///|
/// Parse capability schema from JSON
pub fn parse_capability_schema(json : Json) -> CapabilitySchema? {
  match json {
    Object(obj) => {
      let description = match obj.get("description") {
        Some(String(d)) => d
        _ => ""
      }
      let parameters = match obj.get("parameters") {
        Some(p) => p
        _ => Json::object({})
      }
      let returns = obj.get("returns")
      let examples = match obj.get("examples") {
        Some(Array(arr)) => arr
        _ => []
      }
      Some({ description, parameters, returns, examples })
    }
    _ => None
  }
}

///|
/// Capability schema to JSON
pub fn CapabilitySchema::to_json(self : CapabilitySchema) -> Json {
  let obj : Map[String, Json] = {
    "description": Json::string(self.description),
    "parameters": self.parameters,
  }
  match self.returns {
    Some(r) => obj["returns"] = r
    None => ()
  }
  if self.examples.length() > 0 {
    obj["examples"] = Json::array(self.examples)
  }
  Json::object(obj)
}

///|
/// Tool parameter extracted from schema
pub(all) struct ToolParameter {
  /// Parameter name
  name : String
  /// Parameter type
  param_type : String
  /// Parameter description
  description : String
  /// Whether required
  required : Bool
}

///|
/// Extract parameters from JSON Schema
pub fn extract_parameters(schema : Json) -> Array[ToolParameter] {
  let params : Array[ToolParameter] = []
  match schema {
    { "properties": Object(props), .. } => {
      let required_set : Map[String, Bool] = {}
      match schema {
        { "required": Array(req), .. } =>
          for item in req {
            match item {
              String(name) => required_set[name] = true
              _ => ()
            }
          }
        _ => ()
      }
      for name, prop in props {
        let param_type = match prop {
          { "type": String(t), .. } => t
          _ => "string"
        }
        let description = match prop {
          { "description": String(d), .. } => d
          _ => ""
        }
        let required = required_set.contains(name)
        params.push({ name, param_type, description, required })
      }
    }
    _ => ()
  }
  params
}
