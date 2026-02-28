import type { ChatMessage } from '@/hooks/useChat';
import { AssistantContent } from './AssistantContent';
import styles from './MessageBubble.module.css';

export function MessageBubble({ message }: { message: ChatMessage }) {
  const isUser = message.role === 'user';
  return (
    <div className={isUser ? styles.messageRowUser : styles.messageRowAssistant}>
      <div className={isUser ? styles.bubbleUser : styles.bubbleAssistant}>
        {isUser ? (
          message.content
        ) : (
          <AssistantContent content={message.content} />
        )}
      </div>
    </div>
  );
}
