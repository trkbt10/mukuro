/**
 * Context Files API Endpoints
 */

import type { ApiResponse, ContextFileResponse, ContextFilesListResponse } from '../types.js';
import type { HttpClient } from '../client.js';

export class ContextApi {
  constructor(private readonly http: HttpClient) {}

  // ============================================================
  // Data Endpoints (/context/data/*)
  // ============================================================

  /**
   * List all context data files
   */
  async listData(): Promise<ContextFileResponse[]> {
    const res = await this.http.get<ApiResponse<ContextFilesListResponse>>(
      '/context/data'
    );
    return res.data?.files ?? [];
  }

  /**
   * Get a specific context data file by name
   */
  async getData(name: string): Promise<ContextFileResponse> {
    const res = await this.http.get<ApiResponse<ContextFileResponse>>(
      `/context/data/${encodeURIComponent(name)}`
    );
    if (!res.data) {
      throw new Error(`Context file not found: ${name}`);
    }
    return res.data;
  }

  /**
   * Update a context data file's content
   */
  async updateData(name: string, content: string): Promise<ContextFileResponse> {
    const res = await this.http.put<ApiResponse<ContextFileResponse>>(
      `/context/data/${encodeURIComponent(name)}`,
      { content }
    );
    if (!res.data) {
      throw new Error(`Failed to update context file: ${name}`);
    }
    return res.data;
  }

  /**
   * Delete a context data file
   */
  async deleteData(name: string): Promise<void> {
    await this.http.delete(`/context/data/${encodeURIComponent(name)}`);
  }

  // ============================================================
  // Template Endpoints (/context/templates/*)
  // ============================================================

  /**
   * List all templates
   */
  async listTemplates(): Promise<ContextFileResponse[]> {
    const res = await this.http.get<ApiResponse<ContextFilesListResponse>>(
      '/context/templates'
    );
    return res.data?.files ?? [];
  }

  /**
   * Get a specific template by name
   */
  async getTemplate(name: string): Promise<ContextFileResponse> {
    const res = await this.http.get<ApiResponse<ContextFileResponse>>(
      `/context/templates/${encodeURIComponent(name)}`
    );
    if (!res.data) {
      throw new Error(`Template not found: ${name}`);
    }
    return res.data;
  }
}
