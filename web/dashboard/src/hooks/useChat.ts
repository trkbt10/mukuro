import { useState, useEffect, useRef, useCallback } from 'react';

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant' | 'system' | 'tool';
  content: string;
  timestamp: number;
}

export type ChatStatus =
  | 'connecting'
  | 'connected'
  | 'disconnected'
  | 'thinking'
  | 'error'
  | 'auth_error';

const CHAT_ID_KEY = 'mukuro_chat_id';

export function getChatId(): string {
  let id = localStorage.getItem(CHAT_ID_KEY);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(CHAT_ID_KEY, id);
  }
  return id;
}

export function resetChatId(): string {
  const id = crypto.randomUUID();
  localStorage.setItem(CHAT_ID_KEY, id);
  return id;
}

export function useChat(chatId: string) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [status, setStatus] = useState<ChatStatus>('connecting');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectRef = useRef(0);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    let disposed = false;

    function connect() {
      if (disposed) return;

      const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
      const ws = new WebSocket(`${protocol}//${location.host}/ws/chat`);
      wsRef.current = ws;
      setStatus('connecting');

      ws.onopen = () => {
        if (disposed) { ws.close(); return; }
        // Don't set 'connected' yet — wait for probe result ('ready' or 'error')
        setErrorMsg(null);
        reconnectRef.current = 0;
      };

      ws.onmessage = (event) => {
        if (disposed) return;
        const msg = JSON.parse(event.data);

        switch (msg.type) {
          case 'message':
            setMessages((prev) => [
              ...prev,
              {
                id: crypto.randomUUID(),
                role: msg.role,
                content: msg.content,
                timestamp: msg.timestamp ?? Date.now(),
              },
            ]);
            setStatus('connected');
            setErrorMsg(null);
            break;

          case 'history':
            if (Array.isArray(msg.messages)) {
              setMessages(
                msg.messages
                  .filter((m: any) => m.role === 'user' || m.role === 'assistant')
                  .map((m: any) => ({
                    id: crypto.randomUUID(),
                    role: m.role,
                    content: m.content,
                    timestamp: m.timestamp ?? 0,
                  })),
              );
            }
            break;

          case 'status':
            if (msg.status === 'thinking') setStatus('thinking');
            else if (msg.status === 'ready' || msg.status === 'connected') {
              setStatus('connected');
              setErrorMsg(null);
              // Now that probe passed, load history
              ws.send(JSON.stringify({ type: 'load_history', chat_id: chatId }));
            }
            break;

          case 'error':
            if (msg.code === 'auth') {
              setStatus('auth_error');
            } else {
              setStatus('error');
            }
            setErrorMsg(msg.error ?? 'Unknown error');
            break;
        }
      };

      ws.onclose = () => {
        if (disposed) return;
        setStatus('disconnected');
        wsRef.current = null;

        const delay = Math.min(1000 * 2 ** reconnectRef.current, 30_000);
        reconnectRef.current++;
        reconnectTimer.current = setTimeout(connect, delay);
      };

      ws.onerror = () => {
        // onclose will fire after this
      };
    }

    // Defer connection to avoid React StrictMode double-mount causing
    // "WebSocket closed before established" errors in development.
    const connectTimer = setTimeout(connect, 0);

    return () => {
      disposed = true;
      clearTimeout(connectTimer);
      if (reconnectTimer.current) clearTimeout(reconnectTimer.current);
      wsRef.current?.close();
      wsRef.current = null;
    };
  }, [chatId]);

  const sendMessage = useCallback(
    (content: string) => {
      if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return;

      setMessages((prev) => [
        ...prev,
        {
          id: crypto.randomUUID(),
          role: 'user',
          content,
          timestamp: Date.now(),
        },
      ]);

      wsRef.current.send(
        JSON.stringify({ type: 'send', chat_id: chatId, content }),
      );
      setStatus('thinking');
      setErrorMsg(null);
    },
    [chatId],
  );

  const clearMessages = useCallback(() => {
    setMessages([]);
  }, []);

  return { messages, status, errorMsg, sendMessage, clearMessages };
}
