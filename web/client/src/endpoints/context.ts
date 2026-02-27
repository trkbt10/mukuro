/**
 * Context Files API Endpoints
 */

import type { ApiResponse, ContextFileResponse, ContextFilesListResponse } from '../types.js';
import type { HttpClient } from '../client.js';

export class ContextApi {
  constructor(private readonly http: HttpClient) {}

  /**
   * List all context files
   */
  async list(): Promise<ContextFileResponse[]> {
    const res = await this.http.get<ApiResponse<ContextFilesListResponse>>(
      '/context'
    );
    return res.data?.files ?? [];
  }

  /**
   * Get a specific context file by name
   */
  async get(name: string): Promise<ContextFileResponse> {
    const res = await this.http.get<ApiResponse<ContextFileResponse>>(
      `/context/${encodeURIComponent(name)}`
    );
    if (!res.data) {
      throw new Error(`Context file not found: ${name}`);
    }
    return res.data;
  }

  /**
   * Update a context file's content
   */
  async update(name: string, content: string): Promise<ContextFileResponse> {
    const res = await this.http.put<ApiResponse<ContextFileResponse>>(
      `/context/${encodeURIComponent(name)}`,
      { content }
    );
    if (!res.data) {
      throw new Error(`Failed to update context file: ${name}`);
    }
    return res.data;
  }

  /**
   * Delete a context file
   */
  async delete(name: string): Promise<void> {
    await this.http.delete(`/context/${encodeURIComponent(name)}`);
  }
}
