/**
 * Settings API Endpoints
 */

import type {
  ApiResponse,
  AllSettings,
  RetrySettings,
  AgentSettings,
  ModelInferenceSettings,
  ProviderSettings,
  UpdateRetrySettings,
  UpdateAgentSettings,
  UpdateModelInferenceSettings,
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
   * Get merged model + thinking settings
   */
  async getModelInference(): Promise<ModelInferenceSettings> {
    const res = await this.http.get<ApiResponse<ModelInferenceSettings>>(
      '/settings/model-inference'
    );
    if (!res.data) {
      throw new Error('Failed to get model inference settings');
    }
    return res.data;
  }

  /**
   * Update merged model + thinking settings
   */
  async updateModelInference(
    update: UpdateModelInferenceSettings
  ): Promise<ModelInferenceSettings> {
    const res = await this.http.put<ApiResponse<ModelInferenceSettings>>(
      '/settings/model-inference',
      update
    );
    if (!res.data) {
      throw new Error('Failed to update model inference settings');
    }
    return res.data;
  }

  /**
   * List known models for a provider
   */
  async listProviderModels(name: string): Promise<string[]> {
    const res = await this.http.get<ApiResponse<string[]>>(
      `/settings/providers/${encodeURIComponent(name)}/models`
    );
    return res.data ?? [];
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
