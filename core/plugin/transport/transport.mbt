///|
/// Transport factory
/// Creates appropriate transport handlers based on plugin configuration

///|
/// Transport factory for creating transport handlers
pub struct TransportFactory {
  /// Default HTTP auth token
  default_auth_token : String?
  /// Default token header
  default_token_header : String
}

///|
/// Create a new transport factory
pub fn TransportFactory::new() -> TransportFactory {
  { default_auth_token: None, default_token_header: "X-Plugin-Token" }
}

///|
/// Helper to create HTTP handler
fn create_http_handler(
  plugin_id : String,
  http_config : @interfaces.PluginHttpConfig,
  auth_token : String?,
  token_header : String,
) -> &@interfaces.PluginTransportHandler {
  HttpTransportHandler::new(
    plugin_id~,
    config=http_config,
    auth_token~,
    token_header~,
  )
}

///|
/// Helper to create HTTP handler with TLS
fn create_http_handler_with_tls(
  plugin_id : String,
  http_config : @interfaces.PluginHttpConfig,
  auth_token : String?,
  token_header : String,
  tls_config : @interfaces.PluginTlsConfig?,
) -> &@interfaces.PluginTransportHandler {
  HttpTransportHandler::with_tls(
    plugin_id~,
    config=http_config,
    auth_token~,
    token_header~,
    tls_config~,
  )
}

///|
/// Helper to create Stdio handler
fn create_stdio_handler(
  plugin_id : String,
  stdio_config : @interfaces.PluginStdioConfig,
) -> &@interfaces.PluginTransportHandler {
  StdioTransportHandler::new(plugin_id~, config=stdio_config)
}

///|
/// Helper to create WebSocket handler
fn create_websocket_handler(
  plugin_id : String,
  ws_config : @interfaces.PluginWebSocketConfig,
) -> &@interfaces.PluginTransportHandler {
  WebSocketTransportHandler::new(plugin_id~, config=ws_config)
}

///|
/// Create transport handler for a plugin based on its manifest
pub fn TransportFactory::create_handler(
  self : TransportFactory,
  manifest : @interfaces.PluginManifest,
) -> &@interfaces.PluginTransportHandler raise {
  ignore(self)
  match manifest.transport {
    @interfaces.PluginTransport::Http =>
      match manifest.http {
        Some(http_config) =>
          create_http_handler(manifest.id, http_config, None, "X-Plugin-Token")
        None =>
          raise @interfaces.PluginError::InvalidManifest(
            "HTTP transport requires http configuration",
          )
      }
    @interfaces.PluginTransport::Stdio => {
      let stdio_config = @interfaces.PluginStdioConfig::default(
        command=match manifest.entry {
          Some(entry) => entry
          None =>
            raise @interfaces.PluginError::InvalidManifest(
              "Stdio transport requires entry command",
            )
        },
      )
      create_stdio_handler(manifest.id, stdio_config)
    }
    @interfaces.PluginTransport::WebSocket => {
      let ws_config = @interfaces.PluginWebSocketConfig::default(
        url=match manifest.http {
          Some(http) =>
            match http.base_url {
              Some(url) => url
              None => "ws://localhost:\{http.port}"
            }
          None =>
            raise @interfaces.PluginError::InvalidManifest(
              "WebSocket transport requires url configuration",
            )
        },
      )
      create_websocket_handler(manifest.id, ws_config)
    }
  }
}

///|
/// Create handler with custom auth settings
pub fn TransportFactory::create_handler_with_auth(
  self : TransportFactory,
  manifest : @interfaces.PluginManifest,
  auth_token : String?,
  token_header : String,
) -> &@interfaces.PluginTransportHandler raise {
  ignore(self)
  match manifest.transport {
    @interfaces.PluginTransport::Http =>
      match manifest.http {
        Some(http_config) =>
          create_http_handler(
            manifest.id,
            http_config,
            auth_token,
            token_header,
          )
        None =>
          raise @interfaces.PluginError::InvalidManifest(
            "HTTP transport requires http configuration",
          )
      }
    @interfaces.PluginTransport::Stdio => {
      let stdio_config = @interfaces.PluginStdioConfig::default(
        command=match manifest.entry {
          Some(entry) => entry
          None =>
            raise @interfaces.PluginError::InvalidManifest(
              "Stdio transport requires entry command",
            )
        },
      )
      create_stdio_handler(manifest.id, stdio_config)
    }
    @interfaces.PluginTransport::WebSocket => {
      let ws_config = @interfaces.PluginWebSocketConfig::default(
        url=match manifest.http {
          Some(http) =>
            match http.base_url {
              Some(url) => url
              None => "ws://localhost:\{http.port}"
            }
          None =>
            raise @interfaces.PluginError::InvalidManifest(
              "WebSocket transport requires url configuration",
            )
        },
      )
      create_websocket_handler(manifest.id, ws_config)
    }
  }
}

///|
/// Create handler with TLS configuration
pub fn TransportFactory::create_handler_with_tls(
  self : TransportFactory,
  manifest : @interfaces.PluginManifest,
  auth_token : String?,
  token_header : String,
  tls_config : @interfaces.PluginTlsConfig?,
) -> &@interfaces.PluginTransportHandler raise {
  ignore(self)
  match manifest.transport {
    @interfaces.PluginTransport::Http =>
      match manifest.http {
        Some(http_config) =>
          create_http_handler_with_tls(
            manifest.id,
            http_config,
            auth_token,
            token_header,
            tls_config,
          )
        None =>
          raise @interfaces.PluginError::InvalidManifest(
            "HTTP transport requires http configuration",
          )
      }
    @interfaces.PluginTransport::Stdio => {
      let stdio_config = @interfaces.PluginStdioConfig::default(
        command=match manifest.entry {
          Some(entry) => entry
          None =>
            raise @interfaces.PluginError::InvalidManifest(
              "Stdio transport requires entry command",
            )
        },
      )
      create_stdio_handler(manifest.id, stdio_config)
    }
    @interfaces.PluginTransport::WebSocket => {
      let ws_config = @interfaces.PluginWebSocketConfig::default(
        url=match manifest.http {
          Some(http) =>
            match http.base_url {
              Some(url) => url
              None => {
                // Use wss:// if TLS is enabled
                let protocol = match tls_config {
                  Some(tls) if tls.enabled => "wss"
                  _ => "ws"
                }
                "\{protocol}://localhost:\{http.port}"
              }
            }
          None =>
            raise @interfaces.PluginError::InvalidManifest(
              "WebSocket transport requires url configuration",
            )
        },
      )
      create_websocket_handler(manifest.id, ws_config)
    }
  }
}

///|
/// Supported transport types
pub fn TransportFactory::supported_transports(
  self : TransportFactory,
) -> Array[@interfaces.PluginTransport] {
  ignore(self)
  [
    @interfaces.PluginTransport::Http,
    @interfaces.PluginTransport::Stdio,
    @interfaces.PluginTransport::WebSocket,
  ]
}

///|
/// Check if a transport type is supported
pub fn TransportFactory::is_supported(
  _self : TransportFactory,
  transport : @interfaces.PluginTransport,
) -> Bool {
  match transport {
    @interfaces.PluginTransport::Http => true
    @interfaces.PluginTransport::Stdio => true
    @interfaces.PluginTransport::WebSocket => true
  }
}
