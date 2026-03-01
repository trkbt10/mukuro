import { useState, useRef, useEffect, useCallback } from 'react';
import {
  MessageCircle,
  Plus,
  Trash2,
  Send,
  AlertCircle,
} from 'lucide-react';
import { IconButton } from '@/components/ui';
import { PageToolbar } from '@/components/layout/PageToolbar';
import { MessageBubble, StatusBadge, ThinkingIndicator } from '@/components/chat';
import { useChat } from '@/hooks/useChat';
import { getClient } from '@/lib/client';
import styles from './Chat.module.css';

export function Chat() {
  const { chatId, messages, status, errorMsg, sendMessage, clearMessages } =
    useChat();
  const [input, setInput] = useState('');
  const composingRef = useRef(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, status]);

  // Auto-resize textarea
  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLTextAreaElement>) => {
      setInput(e.target.value);
      const el = e.target;
      el.style.height = 'auto';
      el.style.height = `${Math.min(el.scrollHeight, 140)}px`;
    },
    [],
  );

  const handleSend = useCallback(() => {
    const trimmed = input.trim();
    if (!trimmed || status === 'thinking' || status === 'disconnected') return;
    sendMessage(trimmed);
    setInput('');
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
  }, [input, status, sendMessage]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey && !composingRef.current) {
        e.preventDefault();
        handleSend();
      }
    },
    [handleSend],
  );

  const handleNewChat = useCallback(() => {
    // Reconnect WebSocket to get a new session from the backend
    clearMessages();
    window.location.reload();
  }, [clearMessages]);

  const handleClearHistory = useCallback(async () => {
    if (!chatId) return;
    try {
      await getClient().chat.deleteSession(chatId);
      clearMessages();
    } catch {
      // ignore
    }
  }, [chatId, clearMessages]);

  const canSend =
    input.trim().length > 0 &&
    status !== 'thinking' &&
    status !== 'disconnected' &&
    status !== 'connecting' &&
    status !== 'auth_error';

  return (
    <div className={styles.page}>
      <PageToolbar
        title="Chat"
        titleBadge={<StatusBadge status={status} />}
        noPadding
        actions={
          <>
            <IconButton
              icon={<Trash2 style={{ width: 14, height: 14 }} />}
              aria-label="Clear history"
              onClick={handleClearHistory}
              variant="ghost"
              size="sm"
              disabled={messages.length === 0}
            />
            <IconButton
              icon={<Plus style={{ width: 14, height: 14 }} />}
              aria-label="New chat"
              onClick={handleNewChat}
              variant="ghost"
              size="sm"
            />
          </>
        }
      />

      {/* Messages */}
      {messages.length === 0 && status !== 'thinking' ? (
        <div className={styles.emptyState}>
          <MessageCircle
            className={styles.emptyIcon}
            style={{ width: 48, height: 48 }}
          />
          <span className={styles.emptyText}>
            Send a message to start chatting with the agent
          </span>
        </div>
      ) : (
        <div className={styles.messageList}>
          {messages.map((msg) => (
            <MessageBubble key={msg.id} message={msg} />
          ))}
          {status === 'thinking' && <ThinkingIndicator />}
          {status === 'error' && errorMsg && (
            <div className={styles.errorBanner}>
              <AlertCircle style={{ width: 14, height: 14, flexShrink: 0 }} />
              {errorMsg}
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>
      )}

      {/* Input */}
      <div className={styles.inputArea}>
        <textarea
          ref={textareaRef}
          className={styles.chatInput}
          value={input}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onCompositionStart={() => { composingRef.current = true; }}
          onCompositionEnd={() => { composingRef.current = false; }}
          placeholder={
            status === 'auth_error'
              ? 'Authentication required — set MUKURO_AUTH_TOKEN'
              : status === 'disconnected'
                ? 'Disconnected from server...'
                : 'Type a message... (Enter to send, Shift+Enter for newline)'
          }
          rows={1}
          disabled={status === 'disconnected' || status === 'connecting' || status === 'auth_error'}
        />
        <button
          className={styles.sendBtn}
          onClick={handleSend}
          disabled={!canSend}
          aria-label="Send message"
        >
          <Send style={{ width: 16, height: 16 }} />
        </button>
      </div>
    </div>
  );
}
