/**
 * Mukuro API Client
 */

import { MukuroApiError, MukuroNetworkError, MukuroTimeoutError } from './errors.js';
import { PluginsApi } from './endpoints/plugins.js';
import { ContextApi } from './endpoints/context.js';
import { SettingsApi } from './endpoints/settings.js';
import { ProvidersApi } from './endpoints/providers.js';
import { GatewayApi } from './endpoints/gateway.js';
import { ChatApi } from './endpoints/chat.js';
import { HistoryApi } from './endpoints/history.js';
import { ToolsApi } from './endpoints/tools.js';
import { OnboardApi } from './endpoints/onboard.js';
import type { ApiRole } from './types.js';

export interface MukuroClientOptions {
  baseUrl: string;
  token?: string;
  role?: ApiRole;
  clientId?: string;
  timeout?: number;
}

export interface HttpClient {
  get<T>(path: string): Promise<T>;
  post<T>(path: string, body: unknown): Promise<T>;
  put<T>(path: string, body: unknown): Promise<T>;
  delete(path: string): Promise<void>;
  postForm<T>(path: string, formData: FormData): Promise<T>;
}

export class MukuroClient implements HttpClient {
  private readonly baseUrl: string;
  private readonly token?: string;
  private readonly role?: ApiRole;
  private readonly clientId?: string;
  private readonly timeout: number;

  readonly plugins: PluginsApi;
  readonly context: ContextApi;
  readonly settings: SettingsApi;
  readonly providers: ProvidersApi;
  readonly gateway: GatewayApi;
  readonly chat: ChatApi;
  readonly history: HistoryApi;
  readonly tools: ToolsApi;
  readonly onboard: OnboardApi;

  constructor(options: MukuroClientOptions) {
    this.baseUrl = options.baseUrl.replace(/\/$/, '');
    this.token = options.token;
    this.role = options.role;
    this.clientId = options.clientId;
    this.timeout = options.timeout ?? 30000;

    this.plugins = new PluginsApi(this);
    this.context = new ContextApi(this);
    this.settings = new SettingsApi(this);
    this.providers = new ProvidersApi(this);
    this.gateway = new GatewayApi(this);
    this.chat = new ChatApi(this);
    this.history = new HistoryApi(this);
    this.tools = new ToolsApi(this);
    this.onboard = new OnboardApi(this);
  }

  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    if (this.role) {
      headers['X-Mukuro-Role'] = this.role;
    }
    if (this.clientId) {
      headers['X-Mukuro-Client-Id'] = this.clientId;
    }
    return headers;
  }

  private async requestRaw<T>(
    method: string,
    path: string,
    body?: unknown,
    customHeaders?: Record<string, string>
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    const headers = { ...this.getHeaders(), ...customHeaders };

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(url, {
        method,
        headers,
        body: body !== undefined ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorBody = await response.json().catch(() => ({}));
        throw MukuroApiError.fromResponse(response.status, errorBody);
      }

      if (response.status === 204) {
        return undefined as T;
      }

      return (await response.json()) as T;
    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof MukuroApiError) {
        throw error;
      }

      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          throw new MukuroTimeoutError(this.timeout);
        }
        throw new MukuroNetworkError(error.message, error);
      }

      throw new MukuroNetworkError('Unknown error occurred');
    }
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
    customHeaders?: Record<string, string>
  ): Promise<T> {
    const url = `${this.baseUrl}/api/v1${path}`;
    const headers = { ...this.getHeaders(), ...customHeaders };

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(url, {
        method,
        headers,
        body: body !== undefined ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorBody = await response.json().catch(() => ({}));
        throw MukuroApiError.fromResponse(response.status, errorBody);
      }

      if (response.status === 204) {
        return undefined as T;
      }

      return (await response.json()) as T;
    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof MukuroApiError) {
        throw error;
      }

      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          throw new MukuroTimeoutError(this.timeout);
        }
        throw new MukuroNetworkError(error.message, error);
      }

      throw new MukuroNetworkError('Unknown error occurred');
    }
  }

  async get<T>(path: string): Promise<T> {
    return this.request<T>('GET', path);
  }

  async getRaw<T>(path: string): Promise<T> {
    return this.requestRaw<T>('GET', path);
  }

  async post<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>('POST', path, body);
  }

  async put<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>('PUT', path, body);
  }

  async delete(path: string): Promise<void> {
    await this.request<void>('DELETE', path);
  }

  async postForm<T>(path: string, formData: FormData): Promise<T> {
    const url = `${this.baseUrl}/api/v1${path}`;
    const headers: Record<string, string> = {};

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    if (this.role) {
      headers['X-Mukuro-Role'] = this.role;
    }
    if (this.clientId) {
      headers['X-Mukuro-Client-Id'] = this.clientId;
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers,
        body: formData,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorBody = await response.json().catch(() => ({}));
        throw MukuroApiError.fromResponse(response.status, errorBody);
      }

      return (await response.json()) as T;
    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof MukuroApiError) {
        throw error;
      }

      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          throw new MukuroTimeoutError(this.timeout);
        }
        throw new MukuroNetworkError(error.message, error);
      }

      throw new MukuroNetworkError('Unknown error occurred');
    }
  }
}

export function createClient(options: MukuroClientOptions): MukuroClient {
  return new MukuroClient(options);
}
