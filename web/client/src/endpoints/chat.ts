import type { HttpClient } from '../client.js';
import type {
  ApiResponse,
  ChatSession,
  ChatSessionHistory,
} from '../types.js';

export class ChatApi {
  constructor(private readonly http: HttpClient) {}

  async listSessions(): Promise<ChatSession[]> {
    const res = await this.http.get<ApiResponse<ChatSession[]>>(
      '/chat/sessions',
    );
    return res.data ?? [];
  }

  async getHistory(chatId: string): Promise<ChatSessionHistory> {
    const res = await this.http.get<ApiResponse<ChatSessionHistory>>(
      `/chat/sessions/${encodeURIComponent(chatId)}/history`,
    );
    return res.data ?? { chat_id: chatId, messages: [] };
  }

  async deleteSession(chatId: string): Promise<void> {
    await this.http.delete(
      `/chat/sessions/${encodeURIComponent(chatId)}`,
    );
  }
}
