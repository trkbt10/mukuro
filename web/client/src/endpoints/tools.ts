/**
 * Tools API Endpoints
 */

import type {
  ApiResponse,
  ToolListItem,
  ToolDetail,
  ToolStats,
  ToolListResponse,
} from '../types.js';
import type { HttpClient } from '../client.js';

export class ToolsApi {
  constructor(private readonly http: HttpClient) {}

  /**
   * List all tools with stats
   */
  async list(): Promise<{ tools: ToolListItem[]; stats: ToolStats }> {
    const res = await this.http.get<ToolListResponse>('/tools');
    return {
      tools: res.data ?? [],
      stats: res.stats ?? {
        total: 0,
        enabled: 0,
        builtin: 0,
        plugin: 0,
        user_defined: 0,
        mcp: 0,
      },
    };
  }

  /**
   * Get tool details by ID
   */
  async get(id: string): Promise<ToolDetail> {
    const res = await this.http.get<ApiResponse<ToolDetail>>(
      `/tools/${encodeURIComponent(id)}`
    );
    if (!res.data) {
      throw new Error(`Tool not found: ${id}`);
    }
    return res.data;
  }

  /**
   * Enable a tool
   */
  async enable(id: string): Promise<void> {
    await this.http.put(`/tools/${encodeURIComponent(id)}/enable`, {});
  }

  /**
   * Disable a tool
   */
  async disable(id: string): Promise<void> {
    await this.http.put(`/tools/${encodeURIComponent(id)}/disable`, {});
  }

  /**
   * Delete a tool (user-defined only)
   */
  async delete(id: string): Promise<void> {
    await this.http.delete(`/tools/${encodeURIComponent(id)}`);
  }

  /**
   * List available actions for a tool
   */
  async listActions(id: string): Promise<{ tool_id: string; actions: string[] }> {
    const res = await this.http.get<ApiResponse<{ tool_id: string; actions: string[] }>>(
      `/tools/${encodeURIComponent(id)}/actions`
    );
    return res.data ?? { tool_id: id, actions: [] };
  }

  /**
   * Invoke a tool action
   */
  async invokeAction<T = unknown>(
    id: string,
    action: string,
    params?: Record<string, unknown>
  ): Promise<T> {
    const res = await this.http.post<T>(
      `/tools/${encodeURIComponent(id)}/actions/${encodeURIComponent(action)}`,
      params ?? {}
    );
    return res;
  }
}
