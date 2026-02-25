///|
/// Plugin registry
/// Manages plugin instances and their lifecycle
pub struct PluginRegistry {
  /// Registered plugins by ID
  plugins : Map[String, @interfaces.PluginInstance]
  /// Plugin directory path
  plugin_dir : String
}

///|
/// Create a new plugin registry
pub fn PluginRegistry::new(plugin_dir~ : String) -> PluginRegistry {
  { plugins: {}, plugin_dir }
}

///|
/// Register a plugin
pub fn PluginRegistry::register(
  self : PluginRegistry,
  manifest : @interfaces.PluginManifest,
) -> Unit {
  let instance : @interfaces.PluginInstance = {
    manifest,
    status: @interfaces.PluginStatus::Stopped,
    pid: None,
  }
  self.plugins[manifest.id] = instance
}

///|
/// Unregister a plugin by ID
pub fn PluginRegistry::unregister(
  self : PluginRegistry,
  id : String,
) -> Unit {
  self.plugins.remove(id)
}

///|
/// Get a plugin instance by ID
pub fn PluginRegistry::get(
  self : PluginRegistry,
  id : String,
) -> @interfaces.PluginInstance? {
  self.plugins.get(id)
}

///|
/// List all registered plugins
pub fn PluginRegistry::list(
  self : PluginRegistry,
) -> Array[@interfaces.PluginManifest] {
  let manifests : Array[@interfaces.PluginManifest] = []
  for plugin in self.plugins.values() {
    manifests.push(plugin.manifest)
  }
  manifests
}

///|
/// Get plugin status
pub fn PluginRegistry::get_status(
  self : PluginRegistry,
  id : String,
) -> @interfaces.PluginStatus raise {
  match self.plugins.get(id) {
    Some(instance) => instance.status
    None => raise @interfaces.PluginError::NotFound(id)
  }
}

///|
/// Update plugin status
pub fn PluginRegistry::set_status(
  self : PluginRegistry,
  id : String,
  status : @interfaces.PluginStatus,
) -> Unit raise {
  match self.plugins.get(id) {
    Some(instance) => instance.status = status
    None => raise @interfaces.PluginError::NotFound(id)
  }
}

///|
/// Parse plugin manifest from JSON
pub fn parse_manifest(json : Json) -> @interfaces.PluginManifest? {
  match json {
    { "id": String(id), "name": String(name), .. } => {
      let version = match json {
        { "version": String(v), .. } => v
        _ => "1.0.0"
      }
      let plugin_type = match json {
        { "type": String(t), .. } =>
          match t {
            "channel" => @interfaces.PluginType::Channel
            "tool" => @interfaces.PluginType::Tool
            "storage" => @interfaces.PluginType::Storage
            _ => @interfaces.PluginType::Custom(t)
          }
        _ => @interfaces.PluginType::Channel
      }
      let transport = match json {
        { "transport": String(t), .. } =>
          match t {
            "http" => @interfaces.PluginTransport::Http
            "stdio" => @interfaces.PluginTransport::Stdio
            "websocket" => @interfaces.PluginTransport::WebSocket
            _ => @interfaces.PluginTransport::Http
          }
        _ => @interfaces.PluginTransport::Http
      }
      let http = match json {
        { "http": http_json, .. } => parse_http_config(http_json)
        _ => None
      }
      let entry = match json {
        { "entry": String(e), .. } => Some(e)
        _ => None
      }
      let capabilities = match json {
        { "capabilities": Array(caps), .. } => {
          let result : Array[String] = []
          for cap in caps {
            match cap {
              String(s) => result.push(s)
              _ => ()
            }
          }
          result
        }
        _ => []
      }
      let config = match json {
        { "config": c, .. } => Some(c)
        _ => None
      }
      Some({
        id,
        name,
        version,
        plugin_type,
        transport,
        http,
        entry,
        capabilities,
        config,
      })
    }
    _ => None
  }
}

///|
/// Parse HTTP config from JSON
fn parse_http_config(json : Json) -> @interfaces.PluginHttpConfig? {
  match json {
    { "port": Number(port, ..), .. } => {
      let base_url = match json {
        { "base_url": String(u), .. } => Some(u)
        _ => None
      }
      let endpoints : Map[String, @interfaces.PluginHttpEndpoint] = {}
      match json {
        { "endpoints": Object(eps), .. } =>
          for name, ep in eps {
            match ep {
              String(spec) => {
                // Parse "POST /send" format
                let parts = spec.split(" ").collect()
                if parts.length() == 2 {
                  endpoints[name] = {
                    http_method: parts[0].to_string(),
                    path: parts[1].to_string(),
                  }
                }
              }
              _ => ()
            }
          }
        _ => ()
      }
      Some({ port: port.to_int(), base_url, endpoints })
    }
    _ => None
  }
}

///|
/// Convert manifest to JSON
pub fn manifest_to_json(manifest : @interfaces.PluginManifest) -> Json {
  let plugin_type_str = match manifest.plugin_type {
    @interfaces.PluginType::Channel => "channel"
    @interfaces.PluginType::Tool => "tool"
    @interfaces.PluginType::Storage => "storage"
    @interfaces.PluginType::Custom(t) => t
  }
  let transport_str = match manifest.transport {
    @interfaces.PluginTransport::Http => "http"
    @interfaces.PluginTransport::Stdio => "stdio"
    @interfaces.PluginTransport::WebSocket => "websocket"
  }
  let obj : Map[String, Json] = {
    "id": manifest.id,
    "name": manifest.name,
    "version": manifest.version,
    "type": plugin_type_str,
    "transport": transport_str,
  }
  match manifest.entry {
    Some(e) => obj["entry"] = Json::string(e)
    None => ()
  }
  let caps : Array[Json] = []
  for cap in manifest.capabilities {
    caps.push(Json::string(cap))
  }
  obj["capabilities"] = Json::array(caps)
  match manifest.config {
    Some(c) => obj["config"] = c
    None => ()
  }
  Json::object(obj)
}
