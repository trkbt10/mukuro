///|
/// Message Provider Types
/// Configuration and management for messaging platforms (Slack, Discord, etc.)

///|
/// Message provider type
pub(all) enum MessageProviderType {
  /// Slack App (Bot Token + Socket Mode or Events API)
  Slack
  /// Discord Bot
  Discord
  /// Telegram Bot
  Telegram
  /// Generic Webhook (outgoing only)
  Webhook
  /// HTTP Polling endpoint
  HttpPoll
  /// WebSocket endpoint
  WebSocket
  /// Custom provider
  Custom(String)
}

///|
/// Convert to string
pub fn MessageProviderType::to_string(self : MessageProviderType) -> String {
  match self {
    Slack => "slack"
    Discord => "discord"
    Telegram => "telegram"
    Webhook => "webhook"
    HttpPoll => "http_poll"
    WebSocket => "websocket"
    Custom(name) => name
  }
}

///|
/// Parse from string
pub fn MessageProviderType::from_string(s : String) -> MessageProviderType {
  match s {
    "slack" => Slack
    "discord" => Discord
    "telegram" => Telegram
    "webhook" => Webhook
    "http_poll" => HttpPoll
    "websocket" => WebSocket
    _ => Custom(s)
  }
}

///|
/// Provider authentication method
pub(all) enum ProviderAuthMethod {
  /// API Token (Bearer token)
  Token
  /// Bot Token (platform-specific)
  BotToken
  /// OAuth2
  OAuth2
  /// Webhook Secret (for signature verification)
  WebhookSecret
  /// No authentication
  None
}

///|
/// Provider connection status
pub(all) enum ProviderConnectionStatus {
  /// Not connected
  Disconnected
  /// Connecting
  Connecting
  /// Connected and ready
  Connected
  /// Connection error
  Error(String)
}

///|
/// Convert to string
pub fn ProviderConnectionStatus::to_string(
  self : ProviderConnectionStatus,
) -> String {
  match self {
    Disconnected => "disconnected"
    Connecting => "connecting"
    Connected => "connected"
    Error(msg) => "error: \{msg}"
  }
}

///|
/// Provider capability flags
pub(all) struct ProviderCapabilities {
  /// Can send messages
  can_send : Bool
  /// Can receive messages
  can_receive : Bool
  /// Supports rich text/markdown
  supports_rich_text : Bool
  /// Supports attachments
  supports_attachments : Bool
  /// Supports reactions
  supports_reactions : Bool
  /// Supports threads
  supports_threads : Bool
  /// Supports editing messages
  supports_edit : Bool
  /// Supports deleting messages
  supports_delete : Bool
}

///|
/// Default capabilities
pub fn ProviderCapabilities::default() -> ProviderCapabilities {
  {
    can_send: true,
    can_receive: true,
    supports_rich_text: false,
    supports_attachments: false,
    supports_reactions: false,
    supports_threads: false,
    supports_edit: false,
    supports_delete: false,
  }
}

///|
/// Slack-specific capabilities
pub fn ProviderCapabilities::slack() -> ProviderCapabilities {
  {
    can_send: true,
    can_receive: true,
    supports_rich_text: true,
    supports_attachments: true,
    supports_reactions: true,
    supports_threads: true,
    supports_edit: true,
    supports_delete: true,
  }
}

///|
/// Discord-specific capabilities
pub fn ProviderCapabilities::discord() -> ProviderCapabilities {
  {
    can_send: true,
    can_receive: true,
    supports_rich_text: true,
    supports_attachments: true,
    supports_reactions: true,
    supports_threads: true,
    supports_edit: true,
    supports_delete: true,
  }
}

///|
/// Message provider configuration
pub(all) struct MessageProviderConfig {
  /// Unique provider ID
  id : String
  /// Display name
  name : String
  /// Provider type
  provider_type : MessageProviderType
  /// Whether enabled
  enabled : Bool
  /// Auto-connect on startup
  auto_connect : Bool
  /// Provider-specific settings (JSON)
  settings : Map[String, Json]
  /// Capabilities
  capabilities : ProviderCapabilities
}

///|
/// Create default config
pub fn MessageProviderConfig::new(
  id~ : String,
  name~ : String,
  provider_type~ : MessageProviderType,
) -> MessageProviderConfig {
  {
    id,
    name,
    provider_type,
    enabled: true,
    auto_connect: true,
    settings: {},
    capabilities: ProviderCapabilities::default(),
  }
}

///|
/// Message provider runtime state
pub(all) struct MessageProviderState {
  /// Provider configuration
  config : MessageProviderConfig
  /// Connection status
  status : ProviderConnectionStatus
  /// Last connected timestamp
  last_connected_at : Int64
  /// Last error message
  last_error : String?
  /// Messages sent count
  messages_sent : Int64
  /// Messages received count
  messages_received : Int64
}

///|
/// Create initial state from config
pub fn MessageProviderState::from_config(
  config : MessageProviderConfig,
) -> MessageProviderState {
  {
    config,
    status: ProviderConnectionStatus::Disconnected,
    last_connected_at: 0L,
    last_error: None,
    messages_sent: 0L,
    messages_received: 0L,
  }
}

///|
/// Provider settings schema field
pub(all) struct ProviderSettingField {
  /// Field key
  key : String
  /// Display label
  label : String
  /// Field type
  field_type : ProviderFieldType
  /// Is required
  required : Bool
  /// Description/help text
  description : String
  /// Default value
  default_value : Json?
  /// Is secret (should be masked in UI)
  is_secret : Bool
}

///|
/// Field types for provider settings
pub(all) enum ProviderFieldType {
  /// Single line text
  Text
  /// Multi-line text
  TextArea
  /// Password/secret (masked)
  Secret
  /// URL
  Url
  /// Number
  Number
  /// Boolean toggle
  Toggle
  /// Select from options
  Select(Array[String])
}

///|
/// Convert field type to string
pub fn ProviderFieldType::to_string(self : ProviderFieldType) -> String {
  match self {
    Text => "text"
    TextArea => "textarea"
    Secret => "secret"
    Url => "url"
    Number => "number"
    Toggle => "toggle"
    Select(_) => "select"
  }
}

///|
/// Provider settings schema
pub(all) struct ProviderSettingsSchema {
  /// Provider type
  provider_type : MessageProviderType
  /// Fields
  fields : Array[ProviderSettingField]
}

///|
/// Get Slack settings schema
pub fn ProviderSettingsSchema::slack() -> ProviderSettingsSchema {
  {
    provider_type: MessageProviderType::Slack,
    fields: [
      {
        key: "bot_token",
        label: "Bot Token",
        field_type: ProviderFieldType::Secret,
        required: true,
        description: "Slack Bot Token (starts with xoxb-)",
        default_value: None,
        is_secret: true,
      },
      {
        key: "app_token",
        label: "App Token",
        field_type: ProviderFieldType::Secret,
        required: false,
        description: "App-Level Token for Socket Mode (starts with xapp-)",
        default_value: None,
        is_secret: true,
      },
      {
        key: "signing_secret",
        label: "Signing Secret",
        field_type: ProviderFieldType::Secret,
        required: false,
        description: "Signing secret for webhook verification",
        default_value: None,
        is_secret: true,
      },
      {
        key: "default_channel",
        label: "Default Channel",
        field_type: ProviderFieldType::Text,
        required: false,
        description: "Default channel ID for sending messages",
        default_value: None,
        is_secret: false,
      },
    ],
  }
}

///|
/// Get Discord settings schema
pub fn ProviderSettingsSchema::discord() -> ProviderSettingsSchema {
  {
    provider_type: MessageProviderType::Discord,
    fields: [
      {
        key: "bot_token",
        label: "Bot Token",
        field_type: ProviderFieldType::Secret,
        required: true,
        description: "Discord Bot Token",
        default_value: None,
        is_secret: true,
      },
      {
        key: "application_id",
        label: "Application ID",
        field_type: ProviderFieldType::Text,
        required: true,
        description: "Discord Application ID",
        default_value: None,
        is_secret: false,
      },
      {
        key: "guild_id",
        label: "Guild ID",
        field_type: ProviderFieldType::Text,
        required: false,
        description: "Server (Guild) ID for slash commands",
        default_value: None,
        is_secret: false,
      },
      {
        key: "default_channel",
        label: "Default Channel",
        field_type: ProviderFieldType::Text,
        required: false,
        description: "Default channel ID for sending messages",
        default_value: None,
        is_secret: false,
      },
    ],
  }
}

///|
/// Get Telegram settings schema
pub fn ProviderSettingsSchema::telegram() -> ProviderSettingsSchema {
  {
    provider_type: MessageProviderType::Telegram,
    fields: [
      {
        key: "bot_token",
        label: "Bot Token",
        field_type: ProviderFieldType::Secret,
        required: true,
        description: "Telegram Bot Token (from @BotFather)",
        default_value: None,
        is_secret: true,
      },
      {
        key: "webhook_url",
        label: "Webhook URL",
        field_type: ProviderFieldType::Url,
        required: false,
        description: "Webhook URL for receiving updates (leave empty for polling)",
        default_value: None,
        is_secret: false,
      },
      {
        key: "allowed_updates",
        label: "Allowed Updates",
        field_type: ProviderFieldType::Text,
        required: false,
        description: "Comma-separated list of update types to receive",
        default_value: Some(Json::string("message,edited_message")),
        is_secret: false,
      },
    ],
  }
}

///|
/// Get Webhook settings schema
pub fn ProviderSettingsSchema::webhook() -> ProviderSettingsSchema {
  {
    provider_type: MessageProviderType::Webhook,
    fields: [
      {
        key: "url",
        label: "Webhook URL",
        field_type: ProviderFieldType::Url,
        required: true,
        description: "URL to send messages to",
        default_value: None,
        is_secret: false,
      },
      {
        key: "secret",
        label: "Webhook Secret",
        field_type: ProviderFieldType::Secret,
        required: false,
        description: "Secret for signing webhook payloads",
        default_value: None,
        is_secret: true,
      },
      {
        key: "headers",
        label: "Custom Headers",
        field_type: ProviderFieldType::TextArea,
        required: false,
        description: "Custom headers in JSON format",
        default_value: Some(Json::string("{}")),
        is_secret: false,
      },
    ],
  }
}

///|
/// Get schema for provider type
pub fn ProviderSettingsSchema::for_type(
  provider_type : MessageProviderType,
) -> ProviderSettingsSchema {
  match provider_type {
    Slack => ProviderSettingsSchema::slack()
    Discord => ProviderSettingsSchema::discord()
    Telegram => ProviderSettingsSchema::telegram()
    Webhook => ProviderSettingsSchema::webhook()
    _ => { provider_type, fields: [] }
  }
}

///|
/// Message provider manager trait
pub(open) trait MessageProviderManager {
  /// List all providers
  list_providers(Self) -> Array[MessageProviderState]

  /// Get provider by ID
  get_provider(Self, id~ : String) -> MessageProviderState?

  /// Add a new provider
  add_provider(Self, config~ : MessageProviderConfig) -> Unit raise

  /// Update provider config
  update_provider(Self, id~ : String, config~ : MessageProviderConfig) -> Unit raise

  /// Remove provider
  remove_provider(Self, id~ : String) -> Unit raise

  /// Enable provider
  enable_provider(Self, id~ : String) -> Unit raise

  /// Disable provider
  disable_provider(Self, id~ : String) -> Unit raise

  /// Connect provider
  async connect_provider(Self, id~ : String) -> Unit

  /// Disconnect provider
  async disconnect_provider(Self, id~ : String) -> Unit

  /// Test provider connection
  async test_connection(Self, id~ : String) -> Bool
}

///|
/// Provider manager error
pub(all) suberror MessageProviderError {
  /// Provider not found
  NotFound(String)
  /// Provider already exists
  AlreadyExists(String)
  /// Invalid configuration
  InvalidConfig(String)
  /// Connection failed
  ConnectionFailed(String)
  /// Authentication failed
  AuthFailed(String)
}
