import type { HttpClient } from '../client.js';
import type {
  ApiResponse,
  OnboardGenerateRequest,
  OnboardGenerateResponse,
  OnboardStatusResponse,
} from '../types.js';

export class OnboardApi {
  constructor(private readonly http: HttpClient) {}

  /** Get onboarding status (Source of Truth: data_dir/onboard-state.json) */
  async status(): Promise<OnboardStatusResponse> {
    const res = await this.http.get<ApiResponse<OnboardStatusResponse>>(
      '/onboard/status',
    );
    return res.data ?? { status: 'not_started', has_provider: false };
  }

  /** Start onboarding (set status to in_progress) */
  async start(): Promise<OnboardStatusResponse> {
    const res = await this.http.post<ApiResponse<OnboardStatusResponse>>(
      '/onboard/start',
      {},
    );
    return res.data ?? { status: 'in_progress', has_provider: true };
  }

  /** Complete onboarding (set status to completed) */
  async complete(): Promise<OnboardStatusResponse> {
    const res = await this.http.post<ApiResponse<OnboardStatusResponse>>(
      '/onboard/complete',
      {},
    );
    return res.data ?? { status: 'completed', has_provider: true };
  }

  /** Generate context files via LLM */
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
