/**
 * Message Providers API Endpoints
 */

import type {
  ApiResponse,
  MessageProviderListItem,
  MessageProviderDetail,
  MessageProviderAddRequest,
  MessageProviderUpdateRequest,
  ProviderTypeInfo,
  ProviderSettingsSchema,
  ProviderTestResult,
} from '../types.js';
import type { HttpClient } from '../client.js';

export class ProvidersApi {
  constructor(private readonly http: HttpClient) {}

  /**
   * List all message providers
   */
  async list(): Promise<MessageProviderListItem[]> {
    const res = await this.http.get<ApiResponse<MessageProviderListItem[]>>(
      '/providers'
    );
    return res.data ?? [];
  }

  /**
   * Get provider details by ID
   */
  async get(id: string): Promise<MessageProviderDetail> {
    const res = await this.http.get<ApiResponse<MessageProviderDetail>>(
      `/providers/${encodeURIComponent(id)}`
    );
    if (!res.data) {
      throw new Error(`Provider not found: ${id}`);
    }
    return res.data;
  }

  /**
   * Add a new message provider
   */
  async add(request: MessageProviderAddRequest): Promise<{ ok: boolean; id: string }> {
    const res = await this.http.post<{ ok: boolean; id: string }>(
      '/providers',
      request
    );
    return res;
  }

  /**
   * Update a provider
   */
  async update(id: string, request: MessageProviderUpdateRequest): Promise<void> {
    await this.http.put(`/providers/${encodeURIComponent(id)}`, request);
  }

  /**
   * Delete a provider
   */
  async delete(id: string): Promise<void> {
    await this.http.delete(`/providers/${encodeURIComponent(id)}`);
  }

  /**
   * Enable a provider
   */
  async enable(id: string): Promise<void> {
    await this.http.put(`/providers/${encodeURIComponent(id)}/enable`, {});
  }

  /**
   * Disable a provider
   */
  async disable(id: string): Promise<void> {
    await this.http.put(`/providers/${encodeURIComponent(id)}/disable`, {});
  }

  /**
   * Connect a provider
   */
  async connect(id: string): Promise<{ ok: boolean; status: string }> {
    const res = await this.http.post<{ ok: boolean; status: string }>(
      `/providers/${encodeURIComponent(id)}/connect`,
      {}
    );
    return res;
  }

  /**
   * Disconnect a provider
   */
  async disconnect(id: string): Promise<void> {
    await this.http.post(`/providers/${encodeURIComponent(id)}/disconnect`, {});
  }

  /**
   * Test provider connection/configuration
   */
  async test(id: string): Promise<ProviderTestResult> {
    const res = await this.http.post<ProviderTestResult>(
      `/providers/${encodeURIComponent(id)}/test`,
      {}
    );
    return res;
  }

  /**
   * Get available provider types
   */
  async getTypes(): Promise<ProviderTypeInfo[]> {
    const res = await this.http.get<ApiResponse<ProviderTypeInfo[]>>(
      '/providers/types'
    );
    return res.data ?? [];
  }

  /**
   * Get settings schema for a provider type
   */
  async getSchema(providerType: string): Promise<ProviderSettingsSchema> {
    const res = await this.http.get<ApiResponse<ProviderSettingsSchema>>(
      `/providers/schema/${encodeURIComponent(providerType)}`
    );
    if (!res.data) {
      throw new Error(`Schema not found for provider type: ${providerType}`);
    }
    return res.data;
  }
}
