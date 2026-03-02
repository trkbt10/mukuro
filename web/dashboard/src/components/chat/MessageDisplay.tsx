/**
 * Shared ChatMessageDisplay configuration for Chat and History pages.
 * Uses react-editor-ui's ChatMessageDisplay with custom avatars.
 */

import { User, Sparkles, Bot, Wrench } from 'lucide-react';
import type {
  ChatMessage as DisplayMessage,
  MessageDisplayOptions,
} from 'react-editor-ui/chat/ChatMessageDisplay';
import type { ChatMessage } from '@/hooks/useChat';
import type { HistoryRecord } from '@mukuro/client';
import { extractRecordContent } from '@/lib/messages';
import styles from './MessageDisplay.module.css';

// =============================================================================
// Avatars
// =============================================================================

/** User avatar with purple gradient */
export const UserAvatar = (
  <div className={styles.avatarUser}>
    <User size={16} />
  </div>
);

/** Assistant avatar with pink gradient + sparkle animation */
export const AssistantAvatar = (
  <div className={styles.avatarAssistant}>
    <Sparkles size={16} />
  </div>
);

/** System/tool avatar */
export const SystemAvatar = (
  <div className={styles.avatarSystem}>
    <Bot size={16} />
  </div>
);

/** Tool call avatar */
export const ToolAvatar = (
  <div className={styles.avatarTool}>
    <Wrench size={16} />
  </div>
);

// =============================================================================
// Display Options
// =============================================================================

/** Default display options with avatars and timestamps */
export const defaultDisplayOptions: MessageDisplayOptions = {
  variant: 'flat',
  showAvatar: true,
  showSenderName: true,
  showTimestamp: true,
};

// =============================================================================
// Converters
// =============================================================================

/** Convert useChat's ChatMessage to react-editor-ui's ChatMessage */
export function chatMessageToDisplay(msg: ChatMessage): DisplayMessage {
  const isUser = msg.role === 'user';
  const isAssistant = msg.role === 'assistant';

  return {
    id: msg.id,
    role: msg.role === 'tool' ? 'system' : msg.role,
    content: msg.content,
    timestamp: new Date(msg.timestamp),
    senderName: isUser ? 'You' : isAssistant ? 'Mukuro' : 'System',
    avatar: isUser ? UserAvatar : isAssistant ? AssistantAvatar : SystemAvatar,
  };
}

/** Convert history records to DisplayMessage array (filters to displayable messages) */
export function historyRecordsToDisplay(records: HistoryRecord[]): DisplayMessage[] {
  const messages: DisplayMessage[] = [];

  for (const record of records) {
    const payload = record.payload ?? {};
    const content = extractRecordContent(payload);

    switch (record.record_type) {
      case 'user_message':
        messages.push({
          id: `${record.timestamp}-user`,
          role: 'user',
          content: content || '(empty)',
          timestamp: new Date(record.timestamp),
          senderName: 'You',
          avatar: UserAvatar,
        });
        break;

      case 'assistant_message':
        messages.push({
          id: `${record.timestamp}-assistant`,
          role: 'assistant',
          content: content || '(empty)',
          timestamp: new Date(record.timestamp),
          senderName: 'Mukuro',
          avatar: AssistantAvatar,
        });
        break;

      case 'tool_call': {
        const toolName = (payload as Record<string, unknown>).tool_name as string | undefined;
        const args = (payload as Record<string, unknown>).arguments;
        const argsStr = args ? JSON.stringify(args) : '';
        const truncatedArgs = argsStr.length > 100 ? argsStr.slice(0, 100) + '...' : argsStr;
        messages.push({
          id: `${record.timestamp}-tool-call`,
          role: 'system',
          content: `Tool: ${toolName ?? 'unknown'}${truncatedArgs ? `\n${truncatedArgs}` : ''}`,
          timestamp: new Date(record.timestamp),
          senderName: 'Tool Call',
          avatar: ToolAvatar,
        });
        break;
      }

      case 'tool_result': {
        const truncated = content && content.length > 200 ? content.slice(0, 200) + '...' : content;
        messages.push({
          id: `${record.timestamp}-tool-result`,
          role: 'system',
          content: truncated || '(no result)',
          timestamp: new Date(record.timestamp),
          senderName: 'Tool Result',
          avatar: ToolAvatar,
        });
        break;
      }

      case 'error':
        messages.push({
          id: `${record.timestamp}-error`,
          role: 'system',
          content: content || 'Unknown error',
          timestamp: new Date(record.timestamp),
          senderName: 'Error',
          avatar: SystemAvatar,
        });
        break;

      // Skip session_meta, session_start, session_end - they're status events
      default:
        break;
    }
  }

  return messages;
}

// =============================================================================
// Re-exports
// =============================================================================

export {
  ChatMessageDisplay,
  type ChatMessage as DisplayMessage,
  type ChatMessageDisplayHandle,
} from 'react-editor-ui/chat/ChatMessageDisplay';
