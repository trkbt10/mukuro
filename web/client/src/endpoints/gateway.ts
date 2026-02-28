/**
 * Gateway API Endpoints
 * Health and status endpoints (served at root level, not /api/v1)
 */

import type {
  GatewayStatus,
  HealthSummary,
  HealthLive,
  HealthReady,
} from '../types.js';

export interface RawHttpClient {
  getRaw<T>(path: string): Promise<T>;
}

export class GatewayApi {
  constructor(private readonly http: RawHttpClient) {}

  async getStatus(): Promise<GatewayStatus> {
    return this.http.getRaw<GatewayStatus>('/status');
  }

  async getHealth(): Promise<HealthSummary> {
    return this.http.getRaw<HealthSummary>('/health');
  }

  async getHealthLive(): Promise<HealthLive> {
    return this.http.getRaw<HealthLive>('/health/live');
  }

  async getHealthReady(): Promise<HealthReady> {
    return this.http.getRaw<HealthReady>('/health/ready');
  }
}
