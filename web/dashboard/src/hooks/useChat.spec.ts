import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useChat } from './useChat';

// ---------------------------------------------------------------------------
// Mock WebSocket
// ---------------------------------------------------------------------------

type WsHandler = {
  onopen: (() => void) | null;
  onclose: (() => void) | null;
  onmessage: ((event: { data: string }) => void) | null;
  onerror: (() => void) | null;
};

class MockWebSocket {
  static readonly OPEN = 1;
  static readonly CLOSED = 3;
  static instances: MockWebSocket[] = [];

  url: string;
  readyState = MockWebSocket.OPEN;
  onopen: WsHandler['onopen'] = null;
  onclose: WsHandler['onclose'] = null;
  onmessage: WsHandler['onmessage'] = null;
  onerror: WsHandler['onerror'] = null;
  sent: string[] = [];
  closed = false;

  constructor(url: string) {
    this.url = url;
    MockWebSocket.instances.push(this);
  }

  send(data: string) {
    this.sent.push(data);
  }

  close() {
    this.closed = true;
    this.readyState = MockWebSocket.CLOSED;
  }

  // Test helpers
  simulateOpen() {
    this.readyState = MockWebSocket.OPEN;
    this.onopen?.();
  }

  simulateMessage(data: Record<string, unknown>) {
    this.onmessage?.({ data: JSON.stringify(data) });
  }

  simulateClose() {
    this.readyState = MockWebSocket.CLOSED;
    this.onclose?.();
  }

  simulateError() {
    this.onerror?.();
  }
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

const origWebSocket = globalThis.WebSocket;
let uuidCounter: number;

beforeEach(() => {
  MockWebSocket.instances = [];
  (globalThis as any).WebSocket = MockWebSocket as any;
  // Deterministic UUIDs for tests
  uuidCounter = 0;
  vi.spyOn(crypto, 'randomUUID').mockImplementation(
    () => `uuid-${++uuidCounter}` as `${string}-${string}-${string}-${string}-${string}`,
  );
  vi.useFakeTimers();
});

afterEach(() => {
  globalThis.WebSocket = origWebSocket;
  vi.restoreAllMocks();
  vi.useRealTimers();
});

/** Advance past the setTimeout(connect, 0) */
async function flushConnect() {
  await act(async () => {
    vi.advanceTimersByTime(1);
  });
}

function latestWs(): MockWebSocket {
  return MockWebSocket.instances[MockWebSocket.instances.length - 1];
}

/**
 * Simulate the full connection handshake:
 * 1. Flush deferred connect (setTimeout)
 * 2. WebSocket opens
 * 3. Server sends { type: 'session', chat_id: '...' }
 * 4. Client sets 'connected' and sends load_history
 */
async function setupConnected(chatId = 'server-chat-id') {
  const hook = renderHook(() => useChat());
  await flushConnect();
  await act(async () => {
    latestWs().simulateOpen();
  });
  await act(async () => {
    latestWs().simulateMessage({ type: 'session', chat_id: chatId });
  });
  return hook;
}

// ---------------------------------------------------------------------------
// useChat – connection lifecycle
// ---------------------------------------------------------------------------

describe('useChat', () => {
  it('starts in connecting status with null chatId', () => {
    const { result } = renderHook(() => useChat());
    expect(result.current.status).toBe('connecting');
    expect(result.current.chatId).toBeNull();
  });

  it('defers WebSocket creation with setTimeout (StrictMode safety)', () => {
    renderHook(() => useChat());
    // WebSocket should NOT be created synchronously
    expect(MockWebSocket.instances).toHaveLength(0);
  });

  it('creates WebSocket after microtask flush', async () => {
    renderHook(() => useChat());
    await flushConnect();
    expect(MockWebSocket.instances).toHaveLength(1);
    expect(latestWs().url).toContain('/ws/chat');
  });

  it('stays in connecting after open (waits for session)', async () => {
    const { result } = renderHook(() => useChat());
    await flushConnect();

    await act(async () => {
      latestWs().simulateOpen();
    });

    // Should NOT be 'connected' yet — waiting for session message
    expect(result.current.status).toBe('connecting');
    expect(result.current.chatId).toBeNull();
  });

  it('transitions to connected on session message', async () => {
    const { result } = renderHook(() => useChat());
    await flushConnect();

    await act(async () => {
      latestWs().simulateOpen();
    });
    await act(async () => {
      latestWs().simulateMessage({ type: 'session', chat_id: 'test-chat-id' });
    });

    expect(result.current.status).toBe('connected');
    expect(result.current.chatId).toBe('test-chat-id');
  });

  it('sends load_history after receiving session message', async () => {
    renderHook(() => useChat());
    await flushConnect();

    await act(async () => {
      latestWs().simulateOpen();
    });

    // No load_history yet — still waiting for session
    expect(latestWs().sent).toHaveLength(0);

    await act(async () => {
      latestWs().simulateMessage({ type: 'session', chat_id: 'test-chat-id' });
    });

    const sent = JSON.parse(latestWs().sent[0]);
    expect(sent).toEqual({ type: 'load_history' });
  });

  it('closes WebSocket on unmount', async () => {
    const { unmount } = renderHook(() => useChat());
    await flushConnect();

    unmount();
    expect(latestWs().closed).toBe(true);
  });

  it('cancels deferred connect on immediate unmount (StrictMode)', () => {
    const { unmount } = renderHook(() => useChat());
    // Unmount before the setTimeout fires
    unmount();
    vi.advanceTimersByTime(10);
    // No WebSocket should be created
    expect(MockWebSocket.instances).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// useChat – auth_error handling
// ---------------------------------------------------------------------------

describe('useChat auth_error', () => {
  it('sets auth_error status on error with code "auth"', async () => {
    const { result } = renderHook(() => useChat());
    await flushConnect();

    await act(async () => {
      latestWs().simulateOpen();
    });
    await act(async () => {
      latestWs().simulateMessage({
        type: 'error',
        error: 'Authentication required. Start with: MUKURO_AUTH_TOKEN=<token> npm run dev',
        code: 'auth',
      });
    });

    expect(result.current.status).toBe('auth_error');
    expect(result.current.errorMsg).toContain('Authentication required');
  });

  it('sets generic error status on error without auth code', async () => {
    const { result } = renderHook(() => useChat());
    await flushConnect();

    await act(async () => {
      latestWs().simulateOpen();
    });
    await act(async () => {
      latestWs().simulateMessage({
        type: 'error',
        error: 'Cannot reach mukuro backend',
        code: 'connection',
      });
    });

    expect(result.current.status).toBe('error');
    expect(result.current.errorMsg).toBe('Cannot reach mukuro backend');
  });

  it('sets error status on session creation failure', async () => {
    const { result } = renderHook(() => useChat());
    await flushConnect();

    await act(async () => {
      latestWs().simulateOpen();
    });
    await act(async () => {
      latestWs().simulateMessage({
        type: 'error',
        error: 'Failed to create session',
        code: 'session',
      });
    });

    expect(result.current.status).toBe('error');
    expect(result.current.errorMsg).toBe('Failed to create session');
  });
});

// ---------------------------------------------------------------------------
// useChat – message handling
// ---------------------------------------------------------------------------

describe('useChat message handling', () => {
  it('appends incoming assistant message', async () => {
    const { result } = await setupConnected();

    await act(async () => {
      latestWs().simulateMessage({
        type: 'message',
        role: 'assistant',
        content: 'Hello!',
        timestamp: 1000,
      });
    });

    expect(result.current.messages).toHaveLength(1);
    expect(result.current.messages[0].role).toBe('assistant');
    expect(result.current.messages[0].content).toBe('Hello!');
    expect(result.current.messages[0].timestamp).toBe(1000);
    expect(result.current.status).toBe('connected');
  });

  it('populates messages from history', async () => {
    const { result } = await setupConnected();

    await act(async () => {
      latestWs().simulateMessage({
        type: 'history',
        messages: [
          { role: 'user', content: 'hi' },
          { role: 'assistant', content: 'hello' },
          { role: 'system', content: 'ignored' },
        ],
      });
    });

    // system messages are filtered out
    expect(result.current.messages).toHaveLength(2);
    expect(result.current.messages[0].role).toBe('user');
    expect(result.current.messages[1].role).toBe('assistant');
  });

  it('sets thinking status from server', async () => {
    const { result } = await setupConnected();

    await act(async () => {
      latestWs().simulateMessage({ type: 'status', status: 'thinking' });
    });

    expect(result.current.status).toBe('thinking');
  });

  it('sets error status and message', async () => {
    const { result } = await setupConnected();

    await act(async () => {
      latestWs().simulateMessage({
        type: 'error',
        error: 'Something went wrong',
      });
    });

    expect(result.current.status).toBe('error');
    expect(result.current.errorMsg).toBe('Something went wrong');
  });

  it('clears error on successful message', async () => {
    const { result } = await setupConnected();

    await act(async () => {
      latestWs().simulateMessage({ type: 'error', error: 'err' });
    });
    expect(result.current.status).toBe('error');

    await act(async () => {
      latestWs().simulateMessage({
        type: 'message',
        role: 'assistant',
        content: 'ok',
      });
    });
    expect(result.current.status).toBe('connected');
    expect(result.current.errorMsg).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// useChat – sendMessage
// ---------------------------------------------------------------------------

describe('useChat sendMessage', () => {
  it('sends message and adds optimistic user message', async () => {
    const { result } = await setupConnected();

    await act(async () => {
      result.current.sendMessage('hello');
    });

    // Optimistic user message
    expect(result.current.messages).toHaveLength(1);
    expect(result.current.messages[0].role).toBe('user');
    expect(result.current.messages[0].content).toBe('hello');

    // WebSocket send (index 0 = load_history from session, index 1 = user message)
    const sent = JSON.parse(latestWs().sent[1]);
    expect(sent).toEqual({
      type: 'send',
      content: 'hello',
    });

    expect(result.current.status).toBe('thinking');
  });

  it('does not send when WebSocket is not open', async () => {
    const { result } = await setupConnected();
    latestWs().readyState = MockWebSocket.CLOSED;

    await act(async () => {
      result.current.sendMessage('hello');
    });

    // No new messages, no WebSocket send
    expect(result.current.messages).toHaveLength(0);
    // Only the load_history from connection
    expect(latestWs().sent).toHaveLength(1);
  });

  it('does not send before session is established', async () => {
    const { result } = renderHook(() => useChat());
    await flushConnect();
    await act(async () => {
      latestWs().simulateOpen();
    });

    // Try to send before session message
    await act(async () => {
      result.current.sendMessage('hello');
    });

    // Should not send because chatId is null
    expect(result.current.messages).toHaveLength(0);
    expect(latestWs().sent).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// useChat – clearMessages
// ---------------------------------------------------------------------------

describe('useChat clearMessages', () => {
  it('clears all messages', async () => {
    const { result } = await setupConnected();

    await act(async () => {
      latestWs().simulateMessage({
        type: 'message',
        role: 'assistant',
        content: 'hi',
      });
    });
    expect(result.current.messages).toHaveLength(1);

    await act(async () => {
      result.current.clearMessages();
    });
    expect(result.current.messages).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// useChat – reconnection
// ---------------------------------------------------------------------------

describe('useChat reconnection', () => {
  it('reconnects with exponential backoff on close', async () => {
    const { result } = renderHook(() => useChat());
    await flushConnect();
    await act(async () => {
      latestWs().simulateOpen();
    });

    // Close connection → counter=0, delay=1000ms (2^0 * 1000)
    await act(async () => {
      latestWs().simulateClose();
    });
    expect(result.current.status).toBe('disconnected');
    expect(result.current.chatId).toBeNull();
    expect(MockWebSocket.instances).toHaveLength(1);

    // Advance 999ms → should NOT reconnect yet
    await act(async () => {
      vi.advanceTimersByTime(999);
    });
    expect(MockWebSocket.instances).toHaveLength(1);

    // Advance 2ms more (total 1001ms) → first reconnect
    await act(async () => {
      vi.advanceTimersByTime(2);
    });
    expect(MockWebSocket.instances).toHaveLength(2);

    // Close without opening (counter stays at 1) → delay=2000ms (2^1 * 1000)
    await act(async () => {
      latestWs().simulateClose();
    });

    // 1500ms → should NOT reconnect yet
    await act(async () => {
      vi.advanceTimersByTime(1500);
    });
    expect(MockWebSocket.instances).toHaveLength(2);

    // 501ms more (total 2001ms) → second reconnect
    await act(async () => {
      vi.advanceTimersByTime(501);
    });
    expect(MockWebSocket.instances).toHaveLength(3);
  });

  it('resets backoff counter on successful connection', async () => {
    renderHook(() => useChat());
    await flushConnect();

    // Open then close → first reconnect at 1s
    await act(async () => {
      latestWs().simulateOpen();
    });
    await act(async () => {
      latestWs().simulateClose();
    });
    await act(async () => {
      vi.advanceTimersByTime(1001);
    });
    expect(MockWebSocket.instances).toHaveLength(2);

    // Open the new connection → resets counter
    await act(async () => {
      latestWs().simulateOpen();
    });
    // Note: status is still 'connecting' until session message,
    // but reconnect counter was already reset in onopen.

    // Close again → should reconnect at 1s (not 2s) because counter was reset
    await act(async () => {
      latestWs().simulateClose();
    });
    await act(async () => {
      vi.advanceTimersByTime(1001);
    });
    expect(MockWebSocket.instances).toHaveLength(3);
  });

  it('cancels pending reconnect on unmount', async () => {
    const { unmount } = renderHook(() => useChat());
    await flushConnect();
    await act(async () => {
      latestWs().simulateOpen();
    });
    await act(async () => {
      latestWs().simulateClose();
    });

    unmount();

    // Advance past reconnect delay
    vi.advanceTimersByTime(60_000);
    // No new WebSocket should be created after unmount
    expect(MockWebSocket.instances).toHaveLength(1);
  });

  it('clears chatId on disconnect', async () => {
    const { result } = await setupConnected('test-chat-id');
    expect(result.current.chatId).toBe('test-chat-id');

    await act(async () => {
      latestWs().simulateClose();
    });

    expect(result.current.chatId).toBeNull();
    expect(result.current.status).toBe('disconnected');
  });
});
