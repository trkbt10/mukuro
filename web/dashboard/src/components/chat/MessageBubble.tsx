import type { ChatMessage } from '@/hooks/useChat';
import { AssistantContent } from './AssistantContent';
import styles from './MessageBubble.module.css';

export function MessageBubble({ message }: { message: ChatMessage }) {
  return (
    <div className={styles.messageRow} data-role={message.role}>
      <div className={styles.bubble} data-role={message.role}>
        {message.role === 'user' ? (
          message.content
        ) : (
          <AssistantContent content={message.content} />
        )}
      </div>
    </div>
  );
}
