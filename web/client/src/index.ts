/**
 * @mukuro/client
 * TypeScript API Client for mukuro
 */

export { MukuroClient, createClient } from './client.js';
export type { MukuroClientOptions, HttpClient } from './client.js';

export { PluginsApi } from './endpoints/plugins.js';
export { ContextApi } from './endpoints/context.js';
export { SettingsApi } from './endpoints/settings.js';
export { ProvidersApi } from './endpoints/providers.js';
export { GatewayApi } from './endpoints/gateway.js';
export { ChatApi } from './endpoints/chat.js';
export { HistoryApi } from './endpoints/history.js';

export {
  MukuroApiError,
  MukuroNetworkError,
  MukuroTimeoutError,
} from './errors.js';

export type {
  ApiRole,
  ApiError,
  ApiResponse,
  PaginatedResponse,
  PluginListItem,
  PluginDetail,
  PluginAddRequest,
  PluginSettings,
  PluginPermissionType,
  ContextFileName,
  ContextFileResponse,
  ContextFilesListResponse,
  RetrySettings,
  AgentSettings,
  ModelSettings,
  ProviderSettings,
  ThinkingLevel,
  ThinkingSettings,
  AllSettings,
  UpdateRetrySettings,
  UpdateAgentSettings,
  ModelInferenceSettings,
  UpdateModelInferenceSettings,
  UpdateProviderSettings,
  // Message Provider types
  MessageProviderType,
  ProviderConnectionStatus,
  ProviderCapabilities,
  MessageProviderListItem,
  MessageProviderDetail,
  MessageProviderAddRequest,
  MessageProviderUpdateRequest,
  ProviderTypeInfo,
  ProviderFieldType,
  ProviderSettingField,
  ProviderSettingsSchema,
  ProviderTestResult,
  // Gateway types
  GatewayState,
  GatewayStatus,
  HealthSummary,
  HealthLive,
  HealthReady,
  // Chat types
  ChatMessage,
  ChatSession,
  ChatSessionHistory,
  // History types
  HistoryDateEntry,
  HistorySessionSummary,
  HistoryRecord,
  HistorySessionDetail,
  ResumeSessionResponse,
  // Plugin Action types
  PluginActionList,
  MemoryEntry,
  MemoryListResponse,
} from './types.js';
