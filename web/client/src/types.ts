/**
 * Mukuro API Client Types
 * TypeScript type definitions for the mukuro REST API
 */

// ============================================================================
// Common Types
// ============================================================================

export type ApiRole = 'admin' | 'operator' | 'viewer';

export interface ApiError {
  error: string;
  message: string;
  details?: Record<string, unknown>;
}

export interface ApiResponse<T> {
  data?: T;
  error?: string;
  message?: string;
  details?: Record<string, unknown>;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    total: number;
    page: number;
    per_page: number;
    total_pages: number;
  };
}

// ============================================================================
// Plugin Types
// ============================================================================

export interface PluginListItem {
  id: string;
  name: string;
  version: string;
  description: string;
  enabled: boolean;
  status: string;
  loaded_at: number;
  is_builtin: boolean;
}

export interface PluginDetail {
  id: string;
  name: string;
  version: string;
  description: string;
  author: string | null;
  enabled: boolean;
  status: string;
  loaded_at: number;
  modified_at: number;
  permissions: string[];
  settings_schema: Record<string, unknown> | null;
  is_builtin: boolean;
}

export interface PluginAddRequest {
  manifest_path: string;
  enabled?: boolean;
  auto_start?: boolean;
}

export interface PluginSettings {
  plugin_id: string;
  settings: Record<string, unknown>;
}

export type PluginPermissionType =
  | 'network'
  | 'file_read'
  | 'file_write'
  | 'process_spawn'
  | 'env';

// ============================================================================
// Context File Types
// ============================================================================

export type ContextFileName = 'soul' | 'identity' | 'bootstrap' | 'agents' | 'tools' | 'user';

export interface ContextFileResponse {
  name: ContextFileName;
  filename: string;
  description: string;
  content: string;
  exists: boolean;
  is_default: boolean;
}

export interface ContextFilesListResponse {
  files: ContextFileResponse[];
}

// ============================================================================
// Settings Types
// ============================================================================

export interface RetrySettings {
  max_retries: number;
  initial_backoff_ms: number;
  max_backoff_ms: number;
  backoff_multiplier: number;
  retry_status_codes: number[];
}

export interface AgentSettings {
  max_iterations: number;
  timeout_ms: number;
  bootstrap: string;
}

export interface ModelSettings {
  model_name: string;
  temperature: number | null;
  max_tokens: number | null;
  stop_sequences: string[] | null;
}

export interface ProviderSettings {
  name: string;
  base_url: string | null;
  default_model: string;
  timeout_ms: number;
  max_retries: number;
  has_api_key: boolean;
}

export type ThinkingLevel =
  | 'off'
  | 'minimal'
  | 'low'
  | 'medium'
  | 'high'
  | 'xhigh';

export interface ThinkingSettings {
  enabled: boolean;
  level: ThinkingLevel;
  budget_tokens: number | null;
}

export interface AllSettings {
  retry: RetrySettings;
  agent: AgentSettings;
  model: ModelSettings;
  thinking: ThinkingSettings;
  providers: ProviderSettings[];
}

// ============================================================================
// Request/Update Types
// ============================================================================

export interface UpdateRetrySettings {
  max_retries?: number;
  initial_backoff_ms?: number;
  max_backoff_ms?: number;
  backoff_multiplier?: number;
  retry_status_codes?: number[];
}

export interface UpdateAgentSettings {
  max_iterations?: number;
  timeout_ms?: number;
  bootstrap?: string;
}

export interface UpdateModelSettings {
  model_name?: string;
  temperature?: number | null;
  max_tokens?: number | null;
  stop_sequences?: string[] | null;
}

export interface UpdateThinkingSettings {
  enabled?: boolean;
  level?: ThinkingLevel;
  budget_tokens?: number | null;
}

export interface UpdateProviderSettings {
  base_url?: string | null;
  default_model?: string;
  timeout_ms?: number;
  max_retries?: number;
  api_key?: string;
}

// ============================================================================
// Message Provider Types
// ============================================================================

export type MessageProviderType =
  | 'slack'
  | 'discord'
  | 'telegram'
  | 'webhook'
  | 'http_poll'
  | 'websocket'
  | string;

export type ProviderConnectionStatus =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | string;

export interface ProviderCapabilities {
  can_send: boolean;
  can_receive: boolean;
  supports_rich_text: boolean;
  supports_attachments: boolean;
  supports_reactions: boolean;
  supports_threads: boolean;
  supports_edit: boolean;
  supports_delete: boolean;
}

export interface MessageProviderListItem {
  id: string;
  name: string;
  provider_type: MessageProviderType;
  enabled: boolean;
  status: ProviderConnectionStatus;
  messages_sent: number;
  messages_received: number;
}

export interface MessageProviderDetail {
  id: string;
  name: string;
  provider_type: MessageProviderType;
  enabled: boolean;
  auto_connect: boolean;
  status: ProviderConnectionStatus;
  last_connected_at: number;
  last_error: string | null;
  messages_sent: number;
  messages_received: number;
  settings: Record<string, unknown>;
  capabilities: ProviderCapabilities;
}

export interface MessageProviderAddRequest {
  id: string;
  name: string;
  provider_type: MessageProviderType;
  enabled?: boolean;
  auto_connect?: boolean;
  settings?: Record<string, unknown>;
}

export interface MessageProviderUpdateRequest {
  name?: string;
  enabled?: boolean;
  auto_connect?: boolean;
  settings?: Record<string, unknown>;
}

export interface ProviderTypeInfo {
  id: string;
  name: string;
  description: string;
}

export type ProviderFieldType =
  | 'text'
  | 'textarea'
  | 'secret'
  | 'url'
  | 'number'
  | 'toggle'
  | 'select';

export interface ProviderSettingField {
  key: string;
  label: string;
  field_type: ProviderFieldType;
  required: boolean;
  description: string;
  default_value: unknown | null;
  is_secret: boolean;
  options?: string[];
}

export interface ProviderSettingsSchema {
  provider_type: string;
  fields: ProviderSettingField[];
}

export interface ProviderTestResult {
  ok: boolean;
  error?: string;
  message?: string;
  missing_fields?: string;
}

// ============================================================================
// Gateway Types
// ============================================================================

export type GatewayState =
  | 'starting'
  | 'running'
  | 'stopping'
  | 'stopped'
  | string;

export interface GatewayStatus {
  state: GatewayState;
  version: string;
  active_sessions: number;
  connected_channels: string[];
  started_at: number | null;
}

export interface HealthSummary {
  status: string;
}

export interface HealthLive {
  status: string;
  live: boolean;
}

export interface HealthReady {
  status: string;
  ready: boolean;
}

// ============================================================================
// Chat Types
// ============================================================================

export interface ChatMessage {
  role: 'user' | 'assistant' | 'system' | 'tool';
  content: string;
  name?: string;
  tool_call_id?: string;
  timestamp?: number;
}

export interface ChatSession {
  chat_id: string;
  message_count: number;
  created_at: number;
  last_active_at: number;
}

export interface ChatSessionHistory {
  chat_id: string;
  messages: ChatMessage[];
}
