/**
 * Plugins API Endpoints
 */

import type {
  ApiResponse,
  PluginListItem,
  PluginDetail,
  PluginAddRequest,
  PluginSettings,
  PluginActionList,
} from '../types.js';
import type { HttpClient } from '../client.js';

export class PluginsApi {
  constructor(private readonly http: HttpClient) {}

  /**
   * List all plugins
   */
  async list(): Promise<PluginListItem[]> {
    const res = await this.http.get<ApiResponse<PluginListItem[]>>('/plugins');
    return res.data ?? [];
  }

  /**
   * Get plugin details by ID
   */
  async get(id: string): Promise<PluginDetail> {
    const res = await this.http.get<ApiResponse<PluginDetail>>(
      `/plugins/${encodeURIComponent(id)}`
    );
    if (!res.data) {
      throw new Error(`Plugin not found: ${id}`);
    }
    return res.data;
  }

  /**
   * Add a new plugin from manifest
   */
  async add(request: PluginAddRequest): Promise<PluginDetail> {
    const res = await this.http.post<ApiResponse<PluginDetail>>(
      '/plugins',
      request
    );
    if (!res.data) {
      throw new Error('Failed to add plugin');
    }
    return res.data;
  }

  /**
   * Delete a plugin
   */
  async delete(id: string): Promise<void> {
    await this.http.delete(`/plugins/${encodeURIComponent(id)}`);
  }

  /**
   * Enable a plugin
   */
  async enable(id: string): Promise<void> {
    await this.http.put(`/plugins/${encodeURIComponent(id)}/enable`, {});
  }

  /**
   * Disable a plugin
   */
  async disable(id: string): Promise<void> {
    await this.http.put(`/plugins/${encodeURIComponent(id)}/disable`, {});
  }

  /**
   * Reload a plugin
   */
  async reload(id: string): Promise<void> {
    await this.http.post(`/plugins/${encodeURIComponent(id)}/reload`, {});
  }

  /**
   * Upload a plugin ZIP file
   */
  async upload(file: File | Blob, filename?: string): Promise<PluginDetail> {
    const formData = new FormData();
    formData.append('file', file, filename ?? 'plugin.zip');
    const res = await this.http.postForm<ApiResponse<PluginDetail>>(
      '/plugins/upload',
      formData
    );
    if (!res.data) {
      throw new Error('Failed to upload plugin');
    }
    return res.data;
  }

  /**
   * Get plugin settings
   */
  async getSettings(id: string): Promise<PluginSettings> {
    const res = await this.http.get<ApiResponse<PluginSettings>>(
      `/plugins/${encodeURIComponent(id)}/settings`
    );
    if (!res.data) {
      throw new Error(`Plugin settings not found: ${id}`);
    }
    return res.data;
  }

  /**
   * Update plugin settings
   */
  async updateSettings(
    id: string,
    settings: Record<string, unknown>
  ): Promise<PluginSettings> {
    const res = await this.http.put<ApiResponse<PluginSettings>>(
      `/plugins/${encodeURIComponent(id)}/settings`,
      { settings }
    );
    if (!res.data) {
      throw new Error('Failed to update plugin settings');
    }
    return res.data;
  }

  /**
   * List available actions for a plugin
   */
  async listActions(id: string): Promise<PluginActionList> {
    const res = await this.http.get<ApiResponse<PluginActionList>>(
      `/plugins/${encodeURIComponent(id)}/actions`
    );
    return res.data ?? { plugin_id: id, actions: [] };
  }

  /**
   * Invoke a plugin action (RPC)
   */
  async invokeAction<T = unknown>(
    id: string,
    action: string,
    params?: Record<string, unknown>
  ): Promise<T> {
    const res = await this.http.post<T>(
      `/plugins/${encodeURIComponent(id)}/actions/${encodeURIComponent(action)}`,
      params ?? {}
    );
    return res;
  }
}
