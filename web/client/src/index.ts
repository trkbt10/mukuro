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
  UpdateModelSettings,
  ModelInferenceSettings,
  UpdateModelInferenceSettings,
  UpdateThinkingSettings,
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
} from './types.js';
