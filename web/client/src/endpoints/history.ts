import type { HttpClient } from '../client.js';
import type {
  ApiResponse,
  HistoryDateEntry,
  HistorySessionSummary,
  HistorySessionDetail,
  ResumeSessionResponse,
} from '../types.js';

export class HistoryApi {
  constructor(private readonly http: HttpClient) {}

  async listDates(): Promise<HistoryDateEntry[]> {
    const res = await this.http.get<ApiResponse<HistoryDateEntry[]>>(
      '/history/dates',
    );
    return res.data ?? [];
  }

  async listSessions(
    year: number,
    month: number,
    day: number,
  ): Promise<HistorySessionSummary[]> {
    const res = await this.http.get<ApiResponse<HistorySessionSummary[]>>(
      `/history/sessions?year=${year}&month=${month}&day=${day}`,
    );
    return res.data ?? [];
  }

  async getSession(sessionId: string): Promise<HistorySessionDetail> {
    const res = await this.http.get<ApiResponse<HistorySessionDetail>>(
      `/history/sessions/${encodeURIComponent(sessionId)}`,
    );
    return res.data ?? { session_id: sessionId, records: [] };
  }

  async resumeSession(sessionId: string): Promise<ResumeSessionResponse> {
    const res = await this.http.post<ApiResponse<ResumeSessionResponse>>(
      '/chat/resume',
      { session_id: sessionId },
    );
    return res.data ?? { chat_id: '' };
  }
}
