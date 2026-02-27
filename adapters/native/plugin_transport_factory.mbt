///|
/// Native transport factory for plugins
/// Creates transport handlers with actual implementations

///|
/// Native transport factory
pub struct NativeTransportFactory {
  /// Default HTTP auth token
  default_auth_token : String?
  /// Default token header
  default_token_header : String
  /// HTTP client for HTTP transport
  http_client : NativeHttpClient
}

///|
/// Create a new native transport factory
pub fn NativeTransportFactory::new() -> NativeTransportFactory {
  {
    default_auth_token: None,
    default_token_header: "X-Plugin-Token",
    http_client: NativeHttpClient::default(),
  }
}

///|
/// Create transport handler for a plugin based on its manifest
pub fn NativeTransportFactory::create_handler(
  self : NativeTransportFactory,
  manifest : @interfaces.PluginManifest,
) -> &@interfaces.PluginTransportHandler raise @interfaces.PluginError {
  match manifest.transport {
    @interfaces.PluginTransport::Http =>
      match manifest.http {
        Some(http_config) => {
          let handler : &@interfaces.PluginTransportHandler = @plugin_transport.HttpTransportHandler::with_client(
            plugin_id=manifest.id,
            config=http_config,
            auth_token=self.default_auth_token,
            token_header=self.default_token_header,
            http_client=self.http_client,
          )
          handler
        }
        None =>
          raise @interfaces.PluginError::InvalidManifest(
            "HTTP transport requires http configuration",
          )
      }
    @interfaces.PluginTransport::Stdio => {
      let config = match manifest.entry {
        Some(entry) => @interfaces.PluginStdioConfig::default(command=entry)
        None =>
          raise @interfaces.PluginError::InvalidManifest(
            "Stdio transport requires entry command",
          )
      }
      let adapter : &@interfaces.PluginTransportHandler = StdioTransportAdapter::new(
        plugin_id=manifest.id,
        config~,
      )
      adapter
    }
    @interfaces.PluginTransport::WebSocket =>
      // Use NativeWebSocketTransportHandler with async trait methods
      match manifest.http {
        Some(http) => {
          let url = match http.base_url {
            Some(url) => url
            None => "ws://localhost:\{http.port}"
          }
          let ws_config = @interfaces.PluginWebSocketConfig::default(url~)
          let handler : &@interfaces.PluginTransportHandler = NativeWebSocketTransportHandler::new(
            plugin_id=manifest.id,
            config=ws_config,
          )
          handler
        }
        None =>
          raise @interfaces.PluginError::InvalidManifest(
            "WebSocket transport requires url configuration",
          )
      }
  }
}

///|
/// Create handler with auth
pub fn NativeTransportFactory::create_handler_with_auth(
  self : NativeTransportFactory,
  manifest : @interfaces.PluginManifest,
  auth_token : String?,
  token_header : String,
) -> &@interfaces.PluginTransportHandler raise @interfaces.PluginError {
  match manifest.transport {
    @interfaces.PluginTransport::Http =>
      match manifest.http {
        Some(http_config) => {
          let handler : &@interfaces.PluginTransportHandler = @plugin_transport.HttpTransportHandler::with_client(
            plugin_id=manifest.id,
            config=http_config,
            auth_token~,
            token_header~,
            http_client=self.http_client,
          )
          handler
        }
        None =>
          raise @interfaces.PluginError::InvalidManifest(
            "HTTP transport requires http configuration",
          )
      }
    @interfaces.PluginTransport::Stdio => {
      let config = match manifest.entry {
        Some(entry) => @interfaces.PluginStdioConfig::default(command=entry)
        None =>
          raise @interfaces.PluginError::InvalidManifest(
            "Stdio transport requires entry command",
          )
      }
      let adapter : &@interfaces.PluginTransportHandler = StdioTransportAdapter::new(
        plugin_id=manifest.id,
        config~,
      )
      adapter
    }
    @interfaces.PluginTransport::WebSocket =>
      match manifest.http {
        Some(http) => {
          let url = match http.base_url {
            Some(url) => url
            None => "ws://localhost:\{http.port}"
          }
          let ws_config = @interfaces.PluginWebSocketConfig::default(url~)
          let handler : &@interfaces.PluginTransportHandler = NativeWebSocketTransportHandler::new(
            plugin_id=manifest.id,
            config=ws_config,
          )
          handler
        }
        None =>
          raise @interfaces.PluginError::InvalidManifest(
            "WebSocket transport requires url configuration",
          )
      }
  }
}

///|
/// Global native transport factory
let global_native_transport_factory : Ref[NativeTransportFactory?] = {
  val: None,
}

///|
/// Get or create the global native transport factory
pub fn get_native_transport_factory() -> NativeTransportFactory {
  match global_native_transport_factory.val {
    Some(factory) => factory
    None => {
      let factory = NativeTransportFactory::new()
      global_native_transport_factory.val = Some(factory)
      factory
    }
  }
}

///|
/// Create transport handler using the global factory
pub fn create_native_transport_handler(
  manifest : @interfaces.PluginManifest,
) -> &@interfaces.PluginTransportHandler raise @interfaces.PluginError {
  get_native_transport_factory().create_handler(manifest)
}
