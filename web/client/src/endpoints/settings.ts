/**
 * Settings API Endpoints
 */

import type {
  ApiResponse,
  AllSettings,
  RetrySettings,
  AgentSettings,
  ModelSettings,
  ThinkingSettings,
  ProviderSettings,
  UpdateRetrySettings,
  UpdateAgentSettings,
  UpdateModelSettings,
  UpdateThinkingSettings,
  UpdateProviderSettings,
} from '../types.js';
import type { HttpClient } from '../client.js';

export class SettingsApi {
  constructor(private readonly http: HttpClient) {}

  /**
   * Get all settings
   */
  async getAll(): Promise<AllSettings> {
    const res = await this.http.get<ApiResponse<AllSettings>>('/settings');
    if (!res.data) {
      throw new Error('Failed to get settings');
    }
    return res.data;
  }

  /**
   * Get retry settings
   */
  async getRetry(): Promise<RetrySettings> {
    const res =
      await this.http.get<ApiResponse<RetrySettings>>('/settings/retry');
    if (!res.data) {
      throw new Error('Failed to get retry settings');
    }
    return res.data;
  }

  /**
   * Update retry settings
   */
  async updateRetry(update: UpdateRetrySettings): Promise<RetrySettings> {
    const res = await this.http.put<ApiResponse<RetrySettings>>(
      '/settings/retry',
      update
    );
    if (!res.data) {
      throw new Error('Failed to update retry settings');
    }
    return res.data;
  }

  /**
   * Get agent settings
   */
  async getAgent(): Promise<AgentSettings> {
    const res =
      await this.http.get<ApiResponse<AgentSettings>>('/settings/agent');
    if (!res.data) {
      throw new Error('Failed to get agent settings');
    }
    return res.data;
  }

  /**
   * Update agent settings
   */
  async updateAgent(update: UpdateAgentSettings): Promise<AgentSettings> {
    const res = await this.http.put<ApiResponse<AgentSettings>>(
      '/settings/agent',
      update
    );
    if (!res.data) {
      throw new Error('Failed to update agent settings');
    }
    return res.data;
  }

  /**
   * Get model settings
   */
  async getModel(): Promise<ModelSettings> {
    const res =
      await this.http.get<ApiResponse<ModelSettings>>('/settings/model');
    if (!res.data) {
      throw new Error('Failed to get model settings');
    }
    return res.data;
  }

  /**
   * Update model settings
   */
  async updateModel(update: UpdateModelSettings): Promise<ModelSettings> {
    const res = await this.http.put<ApiResponse<ModelSettings>>(
      '/settings/model',
      update
    );
    if (!res.data) {
      throw new Error('Failed to update model settings');
    }
    return res.data;
  }

  /**
   * Get thinking settings
   */
  async getThinking(): Promise<ThinkingSettings> {
    const res =
      await this.http.get<ApiResponse<ThinkingSettings>>('/settings/thinking');
    if (!res.data) {
      throw new Error('Failed to get thinking settings');
    }
    return res.data;
  }

  /**
   * Update thinking settings
   */
  async updateThinking(
    update: UpdateThinkingSettings
  ): Promise<ThinkingSettings> {
    const res = await this.http.put<ApiResponse<ThinkingSettings>>(
      '/settings/thinking',
      update
    );
    if (!res.data) {
      throw new Error('Failed to update thinking settings');
    }
    return res.data;
  }

  /**
   * List all providers
   */
  async listProviders(): Promise<ProviderSettings[]> {
    const res = await this.http.get<ApiResponse<ProviderSettings[]>>(
      '/settings/providers'
    );
    return res.data ?? [];
  }

  /**
   * Get provider settings by name
   */
  async getProvider(name: string): Promise<ProviderSettings> {
    const res = await this.http.get<ApiResponse<ProviderSettings>>(
      `/settings/providers/${encodeURIComponent(name)}`
    );
    if (!res.data) {
      throw new Error(`Provider not found: ${name}`);
    }
    return res.data;
  }

  /**
   * Update provider settings
   */
  async updateProvider(
    name: string,
    update: UpdateProviderSettings
  ): Promise<ProviderSettings> {
    const res = await this.http.put<ApiResponse<ProviderSettings>>(
      `/settings/providers/${encodeURIComponent(name)}`,
      update
    );
    if (!res.data) {
      throw new Error('Failed to update provider settings');
    }
    return res.data;
  }
}
