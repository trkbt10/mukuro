import type { HttpClient } from '../client.js';
import type { ApiResponse, OnboardGenerateRequest, OnboardGenerateResponse } from '../types.js';

export class OnboardApi {
  constructor(private readonly http: HttpClient) {}

  async generate(
    request: OnboardGenerateRequest,
  ): Promise<OnboardGenerateResponse> {
    const res = await this.http.post<ApiResponse<OnboardGenerateResponse>>(
      '/onboard/generate',
      request,
    );
    return res.data ?? {};
  }
}
