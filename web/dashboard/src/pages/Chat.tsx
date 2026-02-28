import { useState, useRef, useEffect, useCallback, memo } from 'react';
import {
  MessageCircle,
  Plus,
  Trash2,
  Send,
  Wifi,
  WifiOff,
  Loader2,
  AlertCircle,
  ShieldAlert,
} from 'lucide-react';
import { MarkdownViewer } from 'react-editor-ui/viewers/MarkdownViewer';
import { parseTable } from 'react-editor-ui/viewers/MarkdownViewer/parser/table-detector';
import { Badge, IconButton } from '@/components/ui';
import {
  useChat,
  getChatId,
  resetChatId,
  type ChatMessage,
  type ChatStatus,
} from '@/hooks/useChat';
import { useMarkdownBlocks, type ParsedBlock } from '@/hooks/useMarkdownParser';
import { getClient } from '@/lib/client';
import styles from './Chat.module.css';

const iconSm = { width: 10, height: 10, marginRight: 4 };

function StatusBadge({ status }: { status: ChatStatus }) {
  const config: Record<
    ChatStatus,
    { label: string; variant: 'success' | 'warning' | 'error' | 'default'; icon: React.ReactNode }
  > = {
    connected:    { label: 'Connected',    variant: 'success', icon: <Wifi style={iconSm} /> },
    thinking:     { label: 'Thinking...',  variant: 'warning', icon: <Wifi style={iconSm} /> },
    connecting:   { label: 'Connecting',   variant: 'default', icon: <Loader2 style={{ ...iconSm, animation: 'spin 1s linear infinite' }} /> },
    disconnected: { label: 'Disconnected', variant: 'error',   icon: <WifiOff style={iconSm} /> },
    error:        { label: 'Error',        variant: 'error',   icon: <AlertCircle style={iconSm} /> },
    auth_error:   { label: 'Auth Required',variant: 'warning', icon: <ShieldAlert style={iconSm} /> },
  };

  const { label, variant, icon } = config[status];
  return (
    <Badge variant={variant} size="sm">
      {icon}
      {label}
    </Badge>
  );
}

function ThinkingIndicator() {
  return (
    <div className={styles.thinking}>
      <div className={styles.thinkingDots}>
        <span className={styles.thinkingDot} />
        <span className={styles.thinkingDot} />
        <span className={styles.thinkingDot} />
      </div>
      <span>Agent is thinking...</span>
    </div>
  );
}

function BlockView({ block }: { block: ParsedBlock }) {
  if (block.type === 'horizontal_rule') {
    return <hr className={styles.mdHr} />;
  }

  if (block.type === 'code') {
    const lang = (block.metadata?.language as string) ?? '';
    return (
      <div className={styles.mdCodeBlock}>
        {lang && lang !== 'text' && (
          <span className={styles.mdCodeLang}>{lang}</span>
        )}
        <pre className={styles.mdPre}>
          <code>{block.content}</code>
        </pre>
      </div>
    );
  }

  if (block.type === 'table') {
    const parsed = parseTable(block.content);
    if (parsed) {
      return (
        <table className={styles.mdTable}>
          <thead>
            <tr>
              {parsed.headers.map((h, i) => (
                <th key={i} style={{ textAlign: parsed.alignments[i] ?? 'left' }}>
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {parsed.rows.map((row, ri) => (
              <tr key={ri}>
                {row.map((cell, ci) => (
                  <td key={ci} style={{ textAlign: parsed.alignments[ci] ?? 'left' }}>
                    {cell}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      );
    }
    return <pre className={styles.mdPre}>{block.content}</pre>;
  }

  if (block.type === 'list') {
    const lines = block.content.split('\n').filter(Boolean);
    const Tag = block.metadata?.ordered ? 'ol' : 'ul';
    return (
      <Tag className={styles.mdList}>
        {lines.map((line, i) => (
          <li key={i}>{line}</li>
        ))}
      </Tag>
    );
  }

  if (block.type === 'header') {
    const level = (block.metadata?.level as number) ?? 1;
    const Tag = `h${Math.min(level, 6)}` as 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6';
    return <Tag className={styles.mdHeader}>{block.content}</Tag>;
  }

  if (block.type === 'quote') {
    return <blockquote className={styles.mdQuote}>{block.content}</blockquote>;
  }

  // text / other
  return <p className={styles.mdText}>{block.content}</p>;
}

const AssistantContent = memo(function AssistantContent({
  content,
}: {
  content: string;
}) {
  const blocks = useMarkdownBlocks(content);
  return (
    <MarkdownViewer value={content} className={styles.markdown}>
      {blocks.map((block) => (
        <BlockView key={block.id} block={block} />
      ))}
    </MarkdownViewer>
  );
});

function MessageBubble({ message }: { message: ChatMessage }) {
  const isUser = message.role === 'user';
  return (
    <div
      className={isUser ? styles.messageRowUser : styles.messageRowAssistant}
    >
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

export function Chat() {
  const [chatId, setChatId] = useState(getChatId);
  const { messages, status, errorMsg, sendMessage, clearMessages } =
    useChat(chatId);
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
    const newId = resetChatId();
    clearMessages();
    setChatId(newId);
  }, [clearMessages]);

  const handleClearHistory = useCallback(async () => {
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
      {/* Header */}
      <div className={styles.header}>
        <div className={styles.titleGroup}>
          <h1 className={styles.title}>Chat</h1>
          <StatusBadge status={status} />
        </div>
        <div className={styles.actions}>
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
        </div>
      </div>

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
