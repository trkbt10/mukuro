import type { HistoryRecord } from '@mukuro/client';

/**
 * 共通のメッセージ表示用インターフェース
 * ChatMessage と HistoryRecord の両方から変換可能
 */
export interface DisplayMessage {
  id: string;
  role: 'user' | 'assistant' | 'system' | 'tool' | 'error';
  content: string;
  timestamp: number;
  metadata?: Record<string, unknown>;
}

/**
 * タイムスタンプをHH:MM:SS形式でフォーマット
 */
export function formatTimestamp(ts: number): string {
  const d = new Date(ts);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

/**
 * HistoryRecord の payload から content を抽出
 */
export function extractRecordContent(payload: unknown): string {
  if (typeof payload === 'string') return payload;
  if (payload && typeof payload === 'object') {
    const obj = payload as Record<string, unknown>;
    if (typeof obj.content === 'string') return obj.content;
    if (typeof obj.message === 'string') return obj.message;
  }
  return '';
}

/**
 * HistoryRecord を DisplayMessage に変換
 * session_start, session_end, tool_call, tool_result は null を返す（別途処理）
 */
export function recordToDisplayMessage(record: HistoryRecord): DisplayMessage | null {
  const { record_type, timestamp, payload } = record;
  const content = extractRecordContent(payload);

  switch (record_type) {
    case 'user_message':
      return {
        id: `record-${timestamp}-user`,
        role: 'user',
        content,
        timestamp,
      };
    case 'assistant_message':
      return {
        id: `record-${timestamp}-assistant`,
        role: 'assistant',
        content,
        timestamp,
      };
    case 'error':
      return {
        id: `record-${timestamp}-error`,
        role: 'error',
        content,
        timestamp,
      };
    default:
      return null;
  }
}

/**
 * record_type に対応するロールを取得
 */
export function getRecordRole(recordType: string): 'user' | 'assistant' | 'tool' | 'error' | 'status' {
  switch (recordType) {
    case 'user_message':
      return 'user';
    case 'assistant_message':
      return 'assistant';
    case 'tool_call':
    case 'tool_result':
      return 'tool';
    case 'error':
      return 'error';
    default:
      return 'status';
  }
}
