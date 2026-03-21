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

export type ContextFileName = 'soul' | 'identity' | 'bootstrap' | 'agents' | 'tools' | 'user' | 'heartbeat';

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
  use_responses_api: boolean;
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

export interface UpdateProviderSettings {
  base_url?: string | null;
  default_model?: string;
  timeout_ms?: number;
  max_retries?: number;
  api_key?: string;
  use_responses_api?: boolean;
}

export interface ModelInferenceSettings {
  model_name: string;
  temperature: number | null;
  max_tokens: number | null;
  stop_sequences: string[] | null;
  thinking_enabled: boolean;
  thinking_level: ThinkingLevel;
  thinking_budget_tokens: number | null;
}

export interface UpdateModelInferenceSettings {
  model_name?: string;
  temperature?: number | null;
  max_tokens?: number | null;
  stop_sequences?: string[] | null;
  thinking_enabled?: boolean;
  thinking_level?: ThinkingLevel;
  thinking_budget_tokens?: number | null;
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

// ============================================================================
// History Types
// ============================================================================

export interface HistoryDateEntry {
  year: number;
  month: number;
  day: number;
  session_count: number;
}

export interface HistorySessionSummary {
  session_id: string;
  channel: string;
  chat_id: string;
  filename: string;
  started_at: number;
  record_count: number;
}

export interface HistoryRecord {
  timestamp: number;
  record_type: string;
  payload: Record<string, unknown>;
}

export interface HistorySessionDetail {
  session_id: string;
  records: HistoryRecord[];
}

export interface ResumeSessionResponse {
  chat_id: string;
}

// ============================================================================
// Plugin Action Types
// ============================================================================

export interface PluginActionList {
  plugin_id: string;
  actions: string[];
}

export interface MemoryEntry {
  key: string;
  value: unknown;
}

export interface MemoryListResponse {
  entries: MemoryEntry[];
  count: number;
}

// ============================================================================
// Tool Types
// ============================================================================

export type ToolSource = 'plugin' | 'user_defined' | 'mcp';

export type ToolStatus = 'available' | 'disabled' | 'error' | 'unavailable';

export interface ToolListItem {
  id: string;
  name: string;
  description: string;
  source: ToolSource;
  source_id?: string;
  enabled: boolean;
  status: ToolStatus;
}

export interface ToolStats {
  total: number;
  enabled: number;
  plugin: number;
  user_defined: number;
  mcp: number;
}

export interface ToolListResponse {
  data: ToolListItem[];
  stats: ToolStats;
}

export interface ToolDetail extends ToolListItem {
  status_message?: string;
  loaded_at: number;
  parameters: Record<string, unknown>;
  settings_schema?: ToolSettingsSchema;
}

export interface ToolSettingsField {
  key: string;
  label: string;
  type: 'text' | 'number' | 'toggle' | 'select' | 'secret' | 'textarea';
  description?: string;
  defaultValue?: unknown;
  placeholder?: string;
  options?: Array<{ value: string; label: string }>;
  min?: number;
  max?: number;
}

export interface ToolSettingsSchema {
  title: string;
  description?: string;
  fields: ToolSettingsField[];
}

// ============================================================================
// Onboard Types
// ============================================================================

/** Onboarding status - Source of Truth is data_dir/onboard-state.json */
export type OnboardStatusValue = 'not_started' | 'in_progress' | 'completed';

export interface OnboardStatusResponse {
  status: OnboardStatusValue;
  has_provider: boolean;
  started_at?: string;
  completed_at?: string;
}

export interface OnboardGenerateRequest {
  user_name?: string;
  work?: string;
  personality?: string;
  notes?: string;
}

export type OnboardGenerateResponse = Partial<
  Record<ContextFileName, string>
>;
