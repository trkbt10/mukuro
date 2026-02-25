///|
/// Plugin host implementation
/// Manages plugin lifecycle and communication
pub struct PluginHostImpl {
  /// Plugin registry
  registry : PluginRegistry
  /// Transport handlers (plugin_id -> handler)
  transport_handlers : Map[String, &@interfaces.PluginTransportHandler]
  /// HTTP transport handlers (plugin_id -> handler) - legacy, kept for compatibility
  http_handlers : Map[String, HttpPluginHandler]
  /// Transport factory
  transport_factory : @transport.TransportFactory
  /// Incoming message queue from plugins
  incoming_messages : Array[@types.InboundEnvelope]
  /// Request ID counter
  mut request_id : Int
  /// Plugin loader configuration
  mut loader_config : PluginLoaderConfig?
  /// Extended manifests
  extended_manifests : Map[String, ExtendedManifest]
}

///|
/// HTTP plugin handler
pub struct HttpPluginHandler {
  /// Plugin ID
  plugin_id : String
  /// Base URL for plugin HTTP server
  base_url : String
  /// HTTP config
  config : @interfaces.PluginHttpConfig
}

///|
/// Create a new plugin host
pub fn PluginHostImpl::new(plugin_dir~ : String) -> PluginHostImpl {
  {
    registry: PluginRegistry::new(plugin_dir~),
    transport_handlers: {},
    http_handlers: {},
    transport_factory: @transport.TransportFactory::new(),
    incoming_messages: [],
    request_id: 0,
    loader_config: Some(PluginLoaderConfig::default(plugin_dir~)),
    extended_manifests: {},
  }
}

///|
/// Create plugin host with custom configuration
pub fn PluginHostImpl::with_config(
  plugin_dir~ : String,
  loader_config~ : PluginLoaderConfig,
) -> PluginHostImpl {
  {
    registry: PluginRegistry::new(plugin_dir~),
    transport_handlers: {},
    http_handlers: {},
    transport_factory: @transport.TransportFactory::new(),
    incoming_messages: [],
    request_id: 0,
    loader_config: Some(loader_config),
    extended_manifests: {},
  }
}

///|
/// Get the plugin directory
pub fn PluginHostImpl::get_plugin_dir(self : PluginHostImpl) -> String {
  self.registry.plugin_dir
}

///|
/// Generate next request ID
fn PluginHostImpl::next_request_id(self : PluginHostImpl) -> Int {
  self.request_id = self.request_id + 1
  self.request_id
}

///|
/// Register a plugin from manifest
pub fn PluginHostImpl::register_plugin(
  self : PluginHostImpl,
  manifest : @interfaces.PluginManifest,
) -> Unit {
  self.registry.register(manifest)
  // Set up HTTP handler if using HTTP transport
  match manifest.transport {
    @interfaces.PluginTransport::Http =>
      match manifest.http {
        Some(http_config) => {
          let base_url = match http_config.base_url {
            Some(url) => url
            None => "http://localhost:\{http_config.port}"
          }
          self.http_handlers[manifest.id] = {
            plugin_id: manifest.id,
            base_url,
            config: http_config,
          }
        }
        None => ()
      }
    _ => ()
  }
}

///|
/// Get all registered plugins
pub fn PluginHostImpl::list_plugins(
  self : PluginHostImpl,
) -> Array[@interfaces.PluginManifest] {
  self.registry.list()
}

///|
/// Get plugin status
pub fn PluginHostImpl::get_plugin_status(
  self : PluginHostImpl,
  plugin_id : String,
) -> @interfaces.PluginStatus raise {
  self.registry.get_status(plugin_id)
}

///|
/// Handle incoming webhook message from a plugin
pub fn PluginHostImpl::handle_webhook(
  self : PluginHostImpl,
  plugin_id : String,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "message_received" =>
      match request.params {
        Some(params) =>
          match parse_inbound_message(plugin_id, params) {
            Some(envelope) => {
              self.incoming_messages.push(envelope)
              @interfaces.JsonRpcResponse::success(
                result=Json::object({ "status": "ok" }),
                id=request.id,
              )
            }
            None =>
              @interfaces.JsonRpcResponse::error(
                code=@interfaces.jsonrpc_error_invalid_params(),
                message="Invalid message format",
                id=request.id,
              )
          }
        None =>
          @interfaces.JsonRpcResponse::error(
            code=@interfaces.jsonrpc_error_invalid_params(),
            message="Missing params",
            id=request.id,
          )
      }
    "status" =>
      @interfaces.JsonRpcResponse::success(
        result=Json::object({ "status": "running" }),
        id=request.id,
      )
    _ =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_method_not_found(),
        message="Method not found: \{request.rpc_method}",
        id=request.id,
      )
  }
}

///|
/// Pop an incoming message from the queue
pub fn PluginHostImpl::pop_message(
  self : PluginHostImpl,
) -> @types.InboundEnvelope? {
  if self.incoming_messages.length() > 0 {
    Some(self.incoming_messages.remove(0))
  } else {
    None
  }
}

///|
/// Create a JSON-RPC request to send a message
pub fn PluginHostImpl::create_send_request(
  self : PluginHostImpl,
  _plugin_id : String,
  message : @types.OutboundMessage,
) -> @interfaces.JsonRpcRequest {
  let params : Map[String, Json] = {
    "channel": message.channel,
    "chat_id": message.chat_id,
    "content": message.content,
  }
  @interfaces.JsonRpcRequest::new(
    rpc_method="send",
    params=Some(Json::object(params)),
    id=Some(self.next_request_id()),
  )
}

///|
/// Create a JSON-RPC request to connect
pub fn PluginHostImpl::create_connect_request(
  self : PluginHostImpl,
  _plugin_id : String,
  config : Json,
) -> @interfaces.JsonRpcRequest {
  let params : Map[String, Json] = { "config": config }
  @interfaces.JsonRpcRequest::new(
    rpc_method="connect",
    params=Some(Json::object(params)),
    id=Some(self.next_request_id()),
  )
}

///|
/// Create a JSON-RPC request to disconnect
pub fn PluginHostImpl::create_disconnect_request(
  self : PluginHostImpl,
  _plugin_id : String,
) -> @interfaces.JsonRpcRequest {
  @interfaces.JsonRpcRequest::new(
    rpc_method="disconnect",
    params=None,
    id=Some(self.next_request_id()),
  )
}

///|
/// Parse inbound message from JSON params
fn parse_inbound_message(
  plugin_id : String,
  params : Json,
) -> @types.InboundEnvelope? {
  match params {
    { "content": String(content), .. } => {
      let channel = match params {
        { "channel": String(c), .. } => c
        _ => plugin_id
      }
      let chat_id = match params {
        { "chat_id": String(id), .. } => id
        _ => "default"
      }
      let sender_id = match params {
        { "sender_id": String(id), .. } => id
        _ => "unknown"
      }
      let sender_name = match params {
        { "sender_name": String(name), .. } => name
        _ => sender_id
      }
      let timestamp = match params {
        { "timestamp": Number(ts, ..), .. } => ts.to_int64()
        _ => 0L
      }
      Some({
        channel,
        chat_id,
        sender_id,
        sender_name,
        content,
        message_type: @types.MessageType::Text,
        metadata: {},
        timestamp,
      })
    }
    _ => None
  }
}

///|
/// Get HTTP handler for a plugin
pub fn PluginHostImpl::get_http_handler(
  self : PluginHostImpl,
  plugin_id : String,
) -> HttpPluginHandler? {
  self.http_handlers.get(plugin_id)
}

///|
/// Get transport handler for a plugin
pub fn PluginHostImpl::get_transport_handler(
  self : PluginHostImpl,
  plugin_id : String,
) -> &@interfaces.PluginTransportHandler? {
  self.transport_handlers.get(plugin_id)
}

///|
/// Register a plugin with transport handler
pub fn PluginHostImpl::register_plugin_with_transport(
  self : PluginHostImpl,
  manifest : @interfaces.PluginManifest,
) -> Unit raise {
  // Register in registry first
  self.registry.register(manifest)
  // Create and store transport handler
  let handler = self.transport_factory.create_handler(manifest)
  self.transport_handlers[manifest.id] = handler
  // Also set up legacy HTTP handler for compatibility
  match manifest.transport {
    @interfaces.PluginTransport::Http =>
      match manifest.http {
        Some(http_config) => {
          let base_url = match http_config.base_url {
            Some(url) => url
            None => "http://localhost:\{http_config.port}"
          }
          self.http_handlers[manifest.id] = {
            plugin_id: manifest.id,
            base_url,
            config: http_config,
          }
        }
        None => ()
      }
    _ => ()
  }
}

///|
/// Implementation of PluginHost trait
pub impl @interfaces.PluginHost for PluginHostImpl with load_plugins(
  self,
  path~,
) {
  // This will be fully implemented when filesystem adapter is integrated
  // For now, set the loader config
  self.loader_config = Some(PluginLoaderConfig::default(plugin_dir=path))
}

///|
pub impl @interfaces.PluginHost for PluginHostImpl with start_plugin(self, id~) {
  // Get the plugin instance
  match self.registry.get(id) {
    Some(instance) =>
      match instance.status {
        @interfaces.PluginStatus::Running => () // Already running
        _ => {
          // Set status to starting
          self.registry.set_status(id, @interfaces.PluginStatus::Starting)
          // Get or create transport handler
          match self.transport_handlers.get(id) {
            Some(handler) => {
              @interfaces.PluginTransportHandler::start(handler)
              self.registry.set_status(id, @interfaces.PluginStatus::Running)
            }
            None =>
              // Try to create handler from manifest
              match self.transport_factory.create_handler(instance.manifest) {
                handler => {
                  self.transport_handlers[id] = handler
                  @interfaces.PluginTransportHandler::start(handler)
                  self.registry.set_status(
                    id,
                    @interfaces.PluginStatus::Running,
                  )
                }
              }
          }
        }
      }
    None => raise @interfaces.PluginError::NotFound(id)
  }
}

///|
pub impl @interfaces.PluginHost for PluginHostImpl with stop_plugin(self, id~) {
  match self.registry.get(id) {
    Some(_) => {
      match self.transport_handlers.get(id) {
        Some(handler) => @interfaces.PluginTransportHandler::stop(handler)
        None => ()
      }
      self.registry.set_status(id, @interfaces.PluginStatus::Stopped)
    }
    None => raise @interfaces.PluginError::NotFound(id)
  }
}

///|
pub impl @interfaces.PluginHost for PluginHostImpl with get_status(self, id~) {
  self.registry.get_status(id)
}

///|
pub impl @interfaces.PluginHost for PluginHostImpl with list_plugins(self) {
  self.registry.list()
}

///|
pub impl @interfaces.PluginHost for PluginHostImpl with send_request(
  self,
  plugin_id~,
  request~,
) {
  match self.transport_handlers.get(plugin_id) {
    Some(handler) =>
      @interfaces.PluginTransportHandler::send_request(handler, request)
    None => raise @interfaces.PluginError::NotFound(plugin_id)
  }
}

///|
/// Load plugins from filesystem
/// This method uses callbacks for filesystem operations for testability
pub fn PluginHostImpl::load_plugins_with_fs(
  self : PluginHostImpl,
  list_dir : (String) -> Array[String] raise,
  read_file : (String) -> String raise,
) -> Unit raise {
  match self.loader_config {
    Some(config) => {
      let loaded = load_all_plugins(config, list_dir, read_file)
      for plugin in loaded {
        self.register_plugin(plugin.manifest)
        // Also try to parse extended manifest
        match parse_extended_manifest(plugin.raw_manifest) {
          Some(ext) => self.extended_manifests[plugin.manifest.id] = ext
          None => ()
        }
      }
    }
    None => ()
  }
}

///|
/// Get extended manifest for a plugin
pub fn PluginHostImpl::get_extended_manifest(
  self : PluginHostImpl,
  plugin_id : String,
) -> ExtendedManifest? {
  self.extended_manifests.get(plugin_id)
}

///|
/// Auto-start plugins that have autoStart enabled
pub fn PluginHostImpl::auto_start_plugins(self : PluginHostImpl) -> Unit raise {
  for id, ext in self.extended_manifests {
    if ext.auto_start && ext.enabled {
      @interfaces.PluginHost::start_plugin(self, id~) catch {
        _ => ()
      }
    }
  }
}

///|
/// Send notification to a plugin
pub fn PluginHostImpl::send_notification(
  self : PluginHostImpl,
  plugin_id : String,
  request : @interfaces.JsonRpcRequest,
) -> Unit raise {
  match self.transport_handlers.get(plugin_id) {
    Some(handler) =>
      @interfaces.PluginTransportHandler::send_notification(handler, request)
    None => raise @interfaces.PluginError::NotFound(plugin_id)
  }
}
