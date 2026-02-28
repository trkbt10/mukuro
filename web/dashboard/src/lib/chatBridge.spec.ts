import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  buildDispatchHeaders,
  buildDispatchEnvelope,
  parseDispatchResult,
  parseHistoryResult,
  handleChatMessage,
  probeBackend,
  type MessageSender,
  type ChatBridgeConfig,
  type ServerMessage,
} from './chatBridge';

// ---------------------------------------------------------------------------
// buildDispatchHeaders
// ---------------------------------------------------------------------------

describe('buildDispatchHeaders', () => {
  it('always includes Content-Type', () => {
    expect(buildDispatchHeaders()).toEqual({
      'Content-Type': 'application/json',
    });
  });

  it('adds Authorization when authToken is provided', () => {
    expect(buildDispatchHeaders('my-token')).toEqual({
      'Content-Type': 'application/json',
      Authorization: 'Bearer my-token',
    });
  });

  it('omits Authorization when authToken is empty string', () => {
    expect(buildDispatchHeaders('')).toEqual({
      'Content-Type': 'application/json',
    });
  });
});

// ---------------------------------------------------------------------------
// buildDispatchEnvelope
// ---------------------------------------------------------------------------

describe('buildDispatchEnvelope', () => {
  it('builds envelope with required fields', () => {
    const result = buildDispatchEnvelope({
      chat_id: 'chat-1',
      content: 'hello',
    });
    expect(result).toEqual({
      channel: 'web_chat',
      chat_id: 'chat-1',
      sender_id: 'dashboard_user',
      sender_name: 'User',
      content: 'hello',
    });
  });

  it('uses provided sender_name', () => {
    const result = buildDispatchEnvelope({
      chat_id: 'chat-1',
      content: 'hi',
      sender_name: 'Alice',
    });
    expect(result.sender_name).toBe('Alice');
  });

  it('defaults sender_name to "User" when empty', () => {
    const result = buildDispatchEnvelope({
      chat_id: 'c',
      content: 'x',
      sender_name: '',
    });
    expect(result.sender_name).toBe('User');
  });
});

// ---------------------------------------------------------------------------
// parseDispatchResult
// ---------------------------------------------------------------------------

describe('parseDispatchResult', () => {
  it('returns message on successful dispatch', () => {
    const result = parseDispatchResult(true, 200, {
      ok: true,
      response: { channel: 'web_chat', chat_id: 'c1', content: 'Hi there!' },
    });
    expect(result.type).toBe('message');
    expect((result as Extract<ServerMessage, { type: 'message' }>).content).toBe(
      'Hi there!',
    );
  });

  it('returns auth error on HTTP 401', () => {
    const result = parseDispatchResult(false, 401, {
      error: 'unauthorized',
      message: 'Invalid token',
    });
    expect(result.type).toBe('error');
    const err = result as Extract<ServerMessage, { type: 'error' }>;
    expect(err.error).toContain('Authentication required');
    expect(err.code).toBe('auth');
  });

  it('returns backend error with message on HTTP 500', () => {
    const result = parseDispatchResult(false, 500, {
      error: 'model_call_failed',
      message: 'Agent handler failed: provider is required',
    });
    expect(result.type).toBe('error');
    const err = result as Extract<ServerMessage, { type: 'error' }>;
    expect(err.error).toBe('Agent handler failed: provider is required');
    expect(err.code).toBe('backend');
  });

  it('returns generic backend error when HTTP error has no message', () => {
    const result = parseDispatchResult(false, 502, {});
    expect(result.type).toBe('error');
    const err = result as Extract<ServerMessage, { type: 'error' }>;
    expect(err.error).toBe('Backend error (502)');
    expect(err.code).toBe('backend');
  });

  it('returns backend error when ok is true but response has no content', () => {
    const result = parseDispatchResult(true, 200, { ok: true });
    expect(result.type).toBe('error');
    const err = result as Extract<ServerMessage, { type: 'error' }>;
    expect(err.error).toContain('Unexpected response format');
    expect(err.code).toBe('backend');
  });

  it('returns error when ok is true but response.content is not string', () => {
    const result = parseDispatchResult(true, 200, {
      ok: true,
      response: { content: 42 },
    });
    expect(result.type).toBe('error');
  });
});

// ---------------------------------------------------------------------------
// parseHistoryResult
// ---------------------------------------------------------------------------

describe('parseHistoryResult', () => {
  it('returns messages from data.messages', () => {
    const result = parseHistoryResult(true, {
      data: {
        messages: [
          { role: 'user', content: 'hi' },
          { role: 'assistant', content: 'hello' },
        ],
      },
    });
    expect(result.type).toBe('history');
    const history = result as Extract<ServerMessage, { type: 'history' }>;
    expect(history.messages).toHaveLength(2);
    expect(history.messages[0]).toEqual({ role: 'user', content: 'hi' });
  });

  it('returns empty messages when data is missing', () => {
    const result = parseHistoryResult(true, {});
    expect(result.type).toBe('history');
    expect(
      (result as Extract<ServerMessage, { type: 'history' }>).messages,
    ).toEqual([]);
  });

  it('returns empty messages when data.messages is not array', () => {
    const result = parseHistoryResult(true, { data: { messages: 'bad' } });
    expect(result.type).toBe('history');
    expect(
      (result as Extract<ServerMessage, { type: 'history' }>).messages,
    ).toEqual([]);
  });

  it('returns error on non-ok response', () => {
    const result = parseHistoryResult(false, {
      message: 'Session not found',
    });
    expect(result.type).toBe('error');
    expect((result as Extract<ServerMessage, { type: 'error' }>).error).toBe(
      'Session not found',
    );
  });

  it('returns generic error when non-ok and no message', () => {
    const result = parseHistoryResult(false, {});
    expect(result.type).toBe('error');
    expect((result as Extract<ServerMessage, { type: 'error' }>).error).toBe(
      'Failed to load history',
    );
  });
});

// ---------------------------------------------------------------------------
// handleChatMessage (integration – mocked fetch + sender)
// ---------------------------------------------------------------------------

describe('handleChatMessage', () => {
  let sender: MessageSender;
  let sent: string[];
  const config: ChatBridgeConfig = {
    apiUrl: 'http://localhost:6960',
    authToken: 'test-token',
  };

  beforeEach(() => {
    sent = [];
    sender = { send: (data: string) => sent.push(data) };
  });

  function parse(index: number): ServerMessage {
    return JSON.parse(sent[index]);
  }

  // -- ping --

  it('responds to ping with pong', async () => {
    await handleChatMessage(sender, { type: 'ping' }, config);
    expect(parse(0)).toEqual({ type: 'pong' });
  });

  // -- send: success --

  it('dispatches message and returns assistant response', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          ok: true,
          response: {
            channel: 'web_chat',
            chat_id: 'c1',
            content: 'Hello from agent',
          },
        }),
    });

    await handleChatMessage(
      sender,
      { type: 'send', chat_id: 'c1', content: 'hi' },
      config,
      mockFetch as unknown as typeof fetch,
    );

    // First message: thinking status
    expect(parse(0)).toEqual({ type: 'status', status: 'thinking' });
    // Second message: assistant response
    expect(parse(1).type).toBe('message');
    expect(
      (parse(1) as Extract<ServerMessage, { type: 'message' }>).content,
    ).toBe('Hello from agent');

    // Verify fetch was called with auth header
    const [url, options] = mockFetch.mock.calls[0];
    expect(url).toBe('http://localhost:6960/dispatch');
    expect(options.headers['Authorization']).toBe('Bearer test-token');
  });

  it('builds correct envelope from send message', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          ok: true,
          response: { content: 'ok' },
        }),
    });

    await handleChatMessage(
      sender,
      {
        type: 'send',
        chat_id: 'chat-42',
        content: 'test message',
        sender_name: 'Bob',
      },
      config,
      mockFetch as unknown as typeof fetch,
    );

    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body).toEqual({
      channel: 'web_chat',
      chat_id: 'chat-42',
      sender_id: 'dashboard_user',
      sender_name: 'Bob',
      content: 'test message',
    });
  });

  // -- send: backend errors --

  it('handles 401 unauthorized with auth code', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      json: () =>
        Promise.resolve({ error: 'unauthorized', message: 'Bad token' }),
    });

    await handleChatMessage(
      sender,
      { type: 'send', chat_id: 'c1', content: 'hi' },
      config,
      mockFetch as unknown as typeof fetch,
    );

    expect(parse(0)).toEqual({ type: 'status', status: 'thinking' });
    const err = parse(1) as Extract<ServerMessage, { type: 'error' }>;
    expect(err.type).toBe('error');
    expect(err.error).toContain('Authentication required');
    expect(err.code).toBe('auth');
  });

  it('handles 500 model error with backend code', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      json: () =>
        Promise.resolve({
          error: 'model_call_failed',
          message: 'Agent handler failed: provider is required',
        }),
    });

    await handleChatMessage(
      sender,
      { type: 'send', chat_id: 'c1', content: 'hi' },
      config,
      mockFetch as unknown as typeof fetch,
    );

    const err = parse(1) as Extract<ServerMessage, { type: 'error' }>;
    expect(err.type).toBe('error');
    expect(err.error).toBe('Agent handler failed: provider is required');
    expect(err.code).toBe('backend');
  });

  // -- send: network errors --

  it('handles network error with connection code', async () => {
    const mockFetch = vi
      .fn()
      .mockRejectedValue(new TypeError('fetch failed'));

    await handleChatMessage(
      sender,
      { type: 'send', chat_id: 'c1', content: 'hi' },
      config,
      mockFetch as unknown as typeof fetch,
    );

    expect(parse(0)).toEqual({ type: 'status', status: 'thinking' });
    const err = parse(1) as Extract<ServerMessage, { type: 'error' }>;
    expect(err.type).toBe('error');
    expect(err.error).toContain('Cannot reach mukuro backend');
    expect(err.code).toBe('connection');
  });

  it('handles abort (timeout) with connection code', async () => {
    const abortError = new DOMException('Aborted', 'AbortError');
    const mockFetch = vi.fn().mockRejectedValue(abortError);

    await handleChatMessage(
      sender,
      { type: 'send', chat_id: 'c1', content: 'hi' },
      config,
      mockFetch as unknown as typeof fetch,
    );

    const err = parse(1) as Extract<ServerMessage, { type: 'error' }>;
    expect(err.type).toBe('error');
    expect(err.error).toBe('Request timed out (90s)');
    expect(err.code).toBe('connection');
  });

  // -- send: without auth token --

  it('does not send Authorization when authToken is empty', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({ ok: true, response: { content: 'ok' } }),
    });

    await handleChatMessage(
      sender,
      { type: 'send', chat_id: 'c1', content: 'hi' },
      { apiUrl: 'http://localhost:6960' },
      mockFetch as unknown as typeof fetch,
    );

    const headers = mockFetch.mock.calls[0][1].headers;
    expect(headers['Authorization']).toBeUndefined();
  });

  // -- load_history: success --

  it('loads history successfully', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          data: {
            messages: [
              { role: 'user', content: 'hi' },
              { role: 'assistant', content: 'hello' },
            ],
          },
        }),
    });

    await handleChatMessage(
      sender,
      { type: 'load_history', chat_id: 'chat-1' },
      config,
      mockFetch as unknown as typeof fetch,
    );

    expect(parse(0).type).toBe('history');
    const history = parse(0) as Extract<ServerMessage, { type: 'history' }>;
    expect(history.messages).toHaveLength(2);

    // Verify URL encoding
    const url = mockFetch.mock.calls[0][0] as string;
    expect(url).toContain('/api/v1/chat/sessions/chat-1/history');
  });

  it('URL-encodes chat_id in history request', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () => Promise.resolve({ data: { messages: [] } }),
    });

    await handleChatMessage(
      sender,
      { type: 'load_history', chat_id: 'id with spaces/slashes' },
      config,
      mockFetch as unknown as typeof fetch,
    );

    const url = mockFetch.mock.calls[0][0] as string;
    expect(url).toContain(
      encodeURIComponent('id with spaces/slashes'),
    );
  });

  // -- load_history: errors --

  it('handles history fetch error with connection code', async () => {
    const mockFetch = vi
      .fn()
      .mockRejectedValue(new TypeError('fetch failed'));

    await handleChatMessage(
      sender,
      { type: 'load_history', chat_id: 'c1' },
      config,
      mockFetch as unknown as typeof fetch,
    );

    const err = parse(0) as Extract<ServerMessage, { type: 'error' }>;
    expect(err.type).toBe('error');
    expect(err.error).toContain('Failed to load history');
    expect(err.code).toBe('connection');
  });

  it('handles non-ok history response with backend code', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 404,
      json: () =>
        Promise.resolve({ message: 'Session not found' }),
    });

    await handleChatMessage(
      sender,
      { type: 'load_history', chat_id: 'nonexistent' },
      config,
      mockFetch as unknown as typeof fetch,
    );

    const err = parse(0) as Extract<ServerMessage, { type: 'error' }>;
    expect(err.type).toBe('error');
    expect(err.error).toBe('Session not found');
    expect(err.code).toBe('backend');
  });

  // -- unknown message type --

  it('ignores unknown message types silently', async () => {
    await handleChatMessage(
      sender,
      { type: 'unknown' } as never,
      config,
    );
    expect(sent).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// probeBackend
// ---------------------------------------------------------------------------

describe('probeBackend', () => {
  const config: ChatBridgeConfig = {
    apiUrl: 'http://localhost:6960',
    authToken: 'test-token',
  };

  function mockFetchResponses(
    statusRes: { ok: boolean; status: number },
    dispatchRes?: { ok: boolean; status: number },
  ) {
    return vi.fn().mockImplementation((url: string) => {
      if (url.endsWith('/status')) {
        return Promise.resolve(statusRes);
      }
      if (url.endsWith('/dispatch')) {
        if (!dispatchRes) return Promise.reject(new Error('unexpected'));
        return Promise.resolve(dispatchRes);
      }
      return Promise.reject(new Error(`unexpected url: ${url}`));
    });
  }

  it('returns ok when backend is reachable and auth passes', async () => {
    const mockFetch = mockFetchResponses(
      { ok: true, status: 200 },
      { ok: false, status: 400 }, // 400 = auth passed, bad payload → OK
    );

    const result = await probeBackend(config, mockFetch as unknown as typeof fetch);
    expect(result).toEqual({ ok: true });
    expect(mockFetch).toHaveBeenCalledTimes(2);
  });

  it('returns connection error when /status is unreachable', async () => {
    const mockFetch = vi.fn().mockRejectedValue(new TypeError('fetch failed'));

    const result = await probeBackend(config, mockFetch as unknown as typeof fetch);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.code).toBe('connection');
      expect(result.error).toContain('Cannot reach mukuro backend');
    }
  });

  it('returns connection error when /status returns non-ok', async () => {
    const mockFetch = mockFetchResponses({ ok: false, status: 503 });

    const result = await probeBackend(config, mockFetch as unknown as typeof fetch);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.code).toBe('connection');
      expect(result.error).toContain('Backend returned 503');
    }
    // Should NOT call /dispatch when /status failed
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('returns auth error when /dispatch returns 401', async () => {
    const mockFetch = mockFetchResponses(
      { ok: true, status: 200 },
      { ok: false, status: 401 },
    );

    const result = await probeBackend(config, mockFetch as unknown as typeof fetch);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.code).toBe('auth');
      expect(result.error).toContain('Authentication required');
    }
  });

  it('returns ok when /dispatch probe throws (transient error)', async () => {
    const mockFetch = vi.fn().mockImplementation((url: string) => {
      if (url.endsWith('/status')) {
        return Promise.resolve({ ok: true, status: 200 });
      }
      // /dispatch throws – already confirmed reachable, treat as OK
      return Promise.reject(new Error('transient'));
    });

    const result = await probeBackend(config, mockFetch as unknown as typeof fetch);
    expect(result).toEqual({ ok: true });
  });

  it('sends auth header in dispatch probe', async () => {
    const mockFetch = mockFetchResponses(
      { ok: true, status: 200 },
      { ok: false, status: 400 },
    );

    await probeBackend(config, mockFetch as unknown as typeof fetch);

    // Second call is /dispatch
    const [, options] = mockFetch.mock.calls[1];
    expect(options.headers['Authorization']).toBe('Bearer test-token');
    expect(JSON.parse(options.body)).toEqual({ channel: '_probe' });
  });

  it('probes without auth header when no token configured', async () => {
    const noAuthConfig: ChatBridgeConfig = { apiUrl: 'http://localhost:6960' };
    const mockFetch = mockFetchResponses(
      { ok: true, status: 200 },
      { ok: true, status: 200 },
    );

    const result = await probeBackend(noAuthConfig, mockFetch as unknown as typeof fetch);
    expect(result).toEqual({ ok: true });

    const [, options] = mockFetch.mock.calls[1];
    expect(options.headers['Authorization']).toBeUndefined();
  });
});
