///|
/// Plugin host implementation
/// Manages plugin lifecycle and communication
pub struct PluginHostImpl {
  /// Plugin registry
  registry : PluginRegistry
  /// HTTP transport handlers (plugin_id -> handler)
  http_handlers : Map[String, HttpPluginHandler]
  /// Incoming message queue from plugins
  incoming_messages : Array[@types.InboundEnvelope]
  /// Request ID counter
  mut request_id : Int
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
    http_handlers: {},
    incoming_messages: [],
    request_id: 0,
  }
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
