///|
/// Plugin authentication and TLS configuration types

///|
/// Plugin authentication mode
pub(all) enum PluginAuthMode {
  /// No authentication required
  None
  /// Host authenticates to plugin only
  HostOnly
  /// Plugin authenticates to host only
  PluginOnly
  /// Mutual authentication (both directions)
  Mutual
}

///|
/// Parse auth mode from string
pub fn PluginAuthMode::from_string(s : String) -> PluginAuthMode {
  match s.to_lower() {
    "none" => PluginAuthMode::None
    "host_only" | "hostonly" => PluginAuthMode::HostOnly
    "plugin_only" | "pluginonly" => PluginAuthMode::PluginOnly
    "mutual" => PluginAuthMode::Mutual
    _ => PluginAuthMode::None
  }
}

///|
/// Convert auth mode to string
pub fn PluginAuthMode::to_string(self : PluginAuthMode) -> String {
  match self {
    PluginAuthMode::None => "none"
    PluginAuthMode::HostOnly => "host_only"
    PluginAuthMode::PluginOnly => "plugin_only"
    PluginAuthMode::Mutual => "mutual"
  }
}

///|
/// Plugin authentication configuration
pub(all) struct PluginAuthConfig {
  /// Authentication mode
  mode : PluginAuthMode
  /// Token that host sends to plugin (for HostOnly or Mutual)
  host_token : String?
  /// Token that plugin sends to host (for PluginOnly or Mutual)
  plugin_token : String?
  /// Header name for token (default: X-Plugin-Token)
  token_header : String
}

///|
/// Default auth config (no authentication)
pub fn PluginAuthConfig::default() -> PluginAuthConfig {
  {
    mode: PluginAuthMode::None,
    host_token: None,
    plugin_token: None,
    token_header: "X-Plugin-Token",
  }
}

///|
/// Create auth config with mutual authentication
pub fn PluginAuthConfig::mutual(
  host_token~ : String,
  plugin_token~ : String,
  token_header~ : String,
) -> PluginAuthConfig {
  {
    mode: PluginAuthMode::Mutual,
    host_token: Some(host_token),
    plugin_token: Some(plugin_token),
    token_header,
  }
}

///|
/// Create auth config for host-only authentication
pub fn PluginAuthConfig::host_only(
  host_token~ : String,
  token_header~ : String,
) -> PluginAuthConfig {
  {
    mode: PluginAuthMode::HostOnly,
    host_token: Some(host_token),
    plugin_token: None,
    token_header,
  }
}

///|
/// Create auth config for plugin-only authentication
pub fn PluginAuthConfig::plugin_only(
  plugin_token~ : String,
  token_header~ : String,
) -> PluginAuthConfig {
  {
    mode: PluginAuthMode::PluginOnly,
    host_token: None,
    plugin_token: Some(plugin_token),
    token_header,
  }
}

///|
/// Check if host authentication is required
pub fn PluginAuthConfig::requires_host_token(self : PluginAuthConfig) -> Bool {
  match self.mode {
    PluginAuthMode::HostOnly | PluginAuthMode::Mutual => true
    _ => false
  }
}

///|
/// Check if plugin authentication is required
pub fn PluginAuthConfig::requires_plugin_token(self : PluginAuthConfig) -> Bool {
  match self.mode {
    PluginAuthMode::PluginOnly | PluginAuthMode::Mutual => true
    _ => false
  }
}

///|
/// TLS configuration for plugin communication
pub(all) struct PluginTlsConfig {
  /// Whether TLS is enabled
  enabled : Bool
  /// Whether to verify the server's certificate
  verify_host : Bool
  /// Path to CA certificate for verification
  ca_cert_path : String?
  /// Path to client certificate (for mutual TLS)
  client_cert_path : String?
  /// Path to client key (for mutual TLS)
  client_key_path : String?
}

///|
/// Default TLS config (disabled)
pub fn PluginTlsConfig::default() -> PluginTlsConfig {
  {
    enabled: false,
    verify_host: true,
    ca_cert_path: None,
    client_cert_path: None,
    client_key_path: None,
  }
}

///|
/// Create TLS config with verification
pub fn PluginTlsConfig::with_verification(
  ca_cert_path~ : String,
) -> PluginTlsConfig {
  {
    enabled: true,
    verify_host: true,
    ca_cert_path: Some(ca_cert_path),
    client_cert_path: None,
    client_key_path: None,
  }
}

///|
/// Create TLS config for mutual TLS
pub fn PluginTlsConfig::mutual_tls(
  ca_cert_path~ : String,
  client_cert_path~ : String,
  client_key_path~ : String,
) -> PluginTlsConfig {
  {
    enabled: true,
    verify_host: true,
    ca_cert_path: Some(ca_cert_path),
    client_cert_path: Some(client_cert_path),
    client_key_path: Some(client_key_path),
  }
}

///|
/// Check if mutual TLS is configured
pub fn PluginTlsConfig::is_mutual_tls(self : PluginTlsConfig) -> Bool {
  self.enabled &&
  self.client_cert_path is Some(_) &&
  self.client_key_path is Some(_)
}

///|
/// Plugin authenticator trait
pub(open) trait PluginAuthenticator {
  /// Validate incoming request token from plugin
  validate_plugin_token(Self, plugin_id~ : String, token~ : String) -> Bool

  /// Get token to send to plugin
  get_host_token(Self, plugin_id~ : String) -> String?

  /// Check if plugin requires authentication
  requires_auth(Self, plugin_id~ : String) -> Bool
}

///|
/// Authentication error
pub(all) suberror PluginAuthError {
  /// Missing authentication token
  MissingToken(String)
  /// Invalid authentication token
  InvalidToken(String)
  /// Token expired
  TokenExpired(String)
  /// Authentication not configured
  AuthNotConfigured(String)
}

///|
/// Plugin authentication result
pub(all) enum PluginAuthResult {
  /// Authentication successful
  Authenticated
  /// Authentication not required
  NotRequired
  /// Authentication failed with reason
  Failed(String)
}

///|
/// Simple token authenticator implementation
pub struct SimpleTokenAuthenticator {
  /// Plugin tokens (plugin_id -> expected token)
  plugin_tokens : Map[String, String]
  /// Host tokens (plugin_id -> token to send)
  host_tokens : Map[String, String]
}

///|
/// Create a new simple token authenticator
pub fn SimpleTokenAuthenticator::new() -> SimpleTokenAuthenticator {
  { plugin_tokens: {}, host_tokens: {} }
}

///|
/// Register a plugin token
pub fn SimpleTokenAuthenticator::register_plugin_token(
  self : SimpleTokenAuthenticator,
  plugin_id : String,
  token : String,
) -> Unit {
  self.plugin_tokens[plugin_id] = token
}

///|
/// Register a host token
pub fn SimpleTokenAuthenticator::register_host_token(
  self : SimpleTokenAuthenticator,
  plugin_id : String,
  token : String,
) -> Unit {
  self.host_tokens[plugin_id] = token
}

///|
/// Validate a plugin token
pub fn SimpleTokenAuthenticator::validate(
  self : SimpleTokenAuthenticator,
  plugin_id : String,
  token : String,
) -> PluginAuthResult {
  match self.plugin_tokens.get(plugin_id) {
    Some(expected) =>
      if constant_time_compare(token, expected) {
        PluginAuthResult::Authenticated
      } else {
        PluginAuthResult::Failed("Invalid token")
      }
    None => PluginAuthResult::NotRequired
  }
}

///|
/// Implementation of PluginAuthenticator trait
pub impl PluginAuthenticator for SimpleTokenAuthenticator with validate_plugin_token(
  self,
  plugin_id~,
  token~,
) {
  match self.validate(plugin_id, token) {
    PluginAuthResult::Authenticated => true
    PluginAuthResult::NotRequired => true
    PluginAuthResult::Failed(_) => false
  }
}

///|
pub impl PluginAuthenticator for SimpleTokenAuthenticator with get_host_token(
  self,
  plugin_id~,
) {
  self.host_tokens.get(plugin_id)
}

///|
pub impl PluginAuthenticator for SimpleTokenAuthenticator with requires_auth(
  self,
  plugin_id~,
) {
  self.plugin_tokens.contains(plugin_id)
}

///|
/// Extract token from Authorization header
pub fn extract_bearer_token(header_value : String) -> String? {
  let trimmed = header_value.trim().to_string()
  if trimmed.length() == 0 {
    None
  } else if trimmed.to_lower() == "bearer" {
    None
  } else if trimmed.to_lower().has_prefix("bearer ") {
    let token = trimmed.view(start_offset=7).to_string()
    if token.length() == 0 {
      None
    } else {
      Some(token)
    }
  } else {
    Some(trimmed)
  }
}

///|
/// Format token as Authorization header value
pub fn format_bearer_token(token : String) -> String {
  "Bearer \{token}"
}
