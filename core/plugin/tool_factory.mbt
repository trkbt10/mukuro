///|
/// Tool factory for creating ToolDefinitions from capability schemas

///|
/// Convert a capability schema to a ToolDefinition
pub fn capability_to_tool_definition(
  plugin_id : String,
  capability : String,
  schema : @interfaces.CapabilitySchema,
) -> @types.ToolDefinition {
  // Generate unique tool name
  let tool_name = "\{plugin_id}.\{capability}"
  {
    name: tool_name,
    description: schema.description,
    parameters: schema.parameters,
    schema: Some(schema.parameters),
    metadata: { "plugin_id": plugin_id, "capability": capability },
  }
}

///|
/// Build tool parameters from JSON Schema (utility function)
pub fn build_tool_parameters(schema : Json) -> Array[@types.ToolParameter] {
  let params : Array[@types.ToolParameter] = []
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
          { "type": String(t), .. } => parse_param_type(t)
          _ => @types.ParameterType::String
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

///|
/// Parse parameter type from JSON Schema type string
fn parse_param_type(type_str : String) -> @types.ParameterType {
  match type_str {
    "string" => @types.ParameterType::String
    "number" | "integer" => @types.ParameterType::Number
    "boolean" => @types.ParameterType::Boolean
    "object" => @types.ParameterType::Object
    "array" => @types.ParameterType::Array
    _ => @types.ParameterType::String
  }
}

///|
/// Generate tool definitions for all capabilities in a manifest
pub fn generate_tools_from_manifest(
  plugin_id : String,
  capability_schemas : Map[String, @interfaces.CapabilitySchema],
) -> Array[@types.ToolDefinition] {
  let tools : Array[@types.ToolDefinition] = []
  for capability, schema in capability_schemas {
    tools.push(capability_to_tool_definition(plugin_id, capability, schema))
  }
  tools
}

///|
/// Generate tool definitions from extended manifest
pub fn generate_tools_from_extended_manifest(
  ext_manifest : ExtendedManifest,
) -> Array[@types.ToolDefinition] {
  let tools : Array[@types.ToolDefinition] = []
  for capability, schema_parsed in ext_manifest.capability_schemas {
    // Convert parsed schema to CapabilitySchema
    let schema : @interfaces.CapabilitySchema = {
      description: schema_parsed.description,
      parameters: schema_parsed.parameters,
      returns: schema_parsed.returns,
      examples: schema_parsed.examples,
    }
    tools.push(
      capability_to_tool_definition(ext_manifest.base.id, capability, schema),
    )
  }
  tools
}

///|
/// Tool registration helper
pub struct PluginToolRegistry {
  /// Tool definitions by plugin
  tools_by_plugin : Map[String, Array[@types.ToolDefinition]]
  /// All tool definitions
  all_tools : Array[@types.ToolDefinition]
}

///|
/// Create a new plugin tool registry
pub fn PluginToolRegistry::new() -> PluginToolRegistry {
  { tools_by_plugin: {}, all_tools: [] }
}

///|
/// Register tools for a plugin
pub fn PluginToolRegistry::register_plugin_tools(
  self : PluginToolRegistry,
  plugin_id : String,
  tools : Array[@types.ToolDefinition],
) -> Unit {
  self.tools_by_plugin[plugin_id] = tools
  for tool in tools {
    self.all_tools.push(tool)
  }
}

///|
/// Unregister tools for a plugin
pub fn PluginToolRegistry::unregister_plugin_tools(
  self : PluginToolRegistry,
  plugin_id : String,
) -> Unit {
  self.tools_by_plugin.remove(plugin_id)
  // Rebuild all_tools array
  self.all_tools.clear()
  for tools in self.tools_by_plugin.values() {
    for tool in tools {
      self.all_tools.push(tool)
    }
  }
}

///|
/// Get tools for a plugin
pub fn PluginToolRegistry::get_plugin_tools(
  self : PluginToolRegistry,
  plugin_id : String,
) -> Array[@types.ToolDefinition] {
  match self.tools_by_plugin.get(plugin_id) {
    Some(tools) => tools
    None => []
  }
}

///|
/// Get all registered tools
pub fn PluginToolRegistry::get_all_tools(
  self : PluginToolRegistry,
) -> Array[@types.ToolDefinition] {
  self.all_tools
}

///|
/// Find tool by name
pub fn PluginToolRegistry::find_tool(
  self : PluginToolRegistry,
  tool_name : String,
) -> @types.ToolDefinition? {
  for tool in self.all_tools {
    if tool.name == tool_name {
      return Some(tool)
    }
  }
  None
}

///|
/// Parse tool name to extract plugin_id and capability
pub fn parse_plugin_tool_name(tool_name : String) -> (String, String)? {
  let parts = tool_name.split(".").collect()
  if parts.length() >= 2 {
    let plugin_id = parts[0].to_string()
    // Join remaining parts as capability (in case capability has dots)
    let capability = StringBuilder::new()
    for i = 1; i < parts.length(); i = i + 1 {
      if i > 1 {
        capability.write_string(".")
      }
      capability.write_string(parts[i].to_string())
    }
    Some((plugin_id, capability.to_string()))
  } else {
    None
  }
}
