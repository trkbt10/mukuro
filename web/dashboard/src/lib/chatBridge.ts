/**
 * Chat WebSocket bridge logic.
 *
 * Bridges browser WebSocket ↔ MoonBit backend HTTP `/dispatch`.
 * Extracted into pure/injectable functions so it can be tested
 * without real network or WebSocket connections.
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Minimal send interface (subset of ws.WebSocket & browser WebSocket) */
export interface MessageSender {
  send(data: string): void;
}

/** Bridge configuration */
export interface ChatBridgeConfig {
  apiUrl: string;
  authToken?: string;
}

/** Messages the client can send */
export type ClientMessage =
  | { type: 'send'; chat_id: string; content: string; sender_name?: string }
  | { type: 'load_history'; chat_id: string }
  | { type: 'ping' };

/** Messages the server sends back */
export type ServerMessage =
  | { type: 'message'; role: 'assistant'; content: string; timestamp: number }
  | {
      type: 'history';
      messages: Array<{ role: string; content: string; timestamp?: number }>;
    }
  | { type: 'status'; status: 'connected' | 'thinking' | 'ready' }
  | { type: 'pong' }
  | { type: 'error'; error: string; code?: 'auth' | 'connection' | 'backend' };

// ---------------------------------------------------------------------------
// Pure helpers – easy to unit-test
// ---------------------------------------------------------------------------

export function buildDispatchHeaders(
  authToken?: string,
): Record<string, string> {
  const h: Record<string, string> = { 'Content-Type': 'application/json' };
  if (authToken) h['Authorization'] = `Bearer ${authToken}`;
  return h;
}

export function buildDispatchEnvelope(msg: {
  chat_id: string;
  content: string;
  sender_name?: string;
}) {
  return {
    channel: 'web_chat',
    chat_id: msg.chat_id,
    sender_id: 'dashboard_user',
    sender_name: msg.sender_name || 'User',
    content: msg.content,
  };
}

/**
 * Turn an HTTP response from `/dispatch` into a server message.
 *
 * Success shape : `{ ok: true, response: { content, ... } }`
 * Error shape   : `{ error: "code", message: "text" }`
 */
export function parseDispatchResult(
  httpOk: boolean,
  httpStatus: number,
  body: Record<string, unknown>,
): ServerMessage {
  if (!httpOk) {
    if (httpStatus === 401) {
      return {
        type: 'error',
        error:
          'Authentication required. Start the dashboard with: MUKURO_AUTH_TOKEN=<token> npm run dev',
        code: 'auth',
      };
    }
    const msg =
      typeof body?.message === 'string'
        ? body.message
        : `Backend error (${httpStatus})`;
    return { type: 'error', error: msg, code: 'backend' };
  }
  if (
    body?.ok === true &&
    body?.response != null &&
    typeof (body.response as Record<string, unknown>)?.content === 'string'
  ) {
    return {
      type: 'message',
      role: 'assistant',
      content: (body.response as Record<string, unknown>).content as string,
      timestamp: Date.now(),
    };
  }
  const msg =
    typeof body?.message === 'string'
      ? body.message
      : 'Unexpected response format from agent';
  return { type: 'error', error: msg, code: 'backend' };
}

/** Parse the `/api/v1/chat/sessions/{id}/history` response. */
export function parseHistoryResult(
  httpOk: boolean,
  body: Record<string, unknown>,
): ServerMessage {
  if (!httpOk) {
    const msg =
      typeof body?.message === 'string'
        ? body.message
        : 'Failed to load history';
    return { type: 'error', error: msg, code: 'backend' };
  }
  const data = body?.data as Record<string, unknown> | undefined;
  const messages = Array.isArray(data?.messages) ? data.messages : [];
  return { type: 'history', messages };
}

// ---------------------------------------------------------------------------
// Backend probe – distinguish auth vs connection errors on connect
// ---------------------------------------------------------------------------

export type ProbeResult =
  | { ok: true }
  | { ok: false; code: 'auth' | 'connection'; error: string };

/**
 * Probe the backend to check reachability and auth before accepting messages.
 * Hits `/status` (no auth required) first, then `/dispatch` with OPTIONS-like
 * check to test auth.
 */
export async function probeBackend(
  config: ChatBridgeConfig,
  fetchImpl: typeof fetch = fetch,
): Promise<ProbeResult> {
  // 1. Can we reach the backend at all?
  try {
    const res = await fetchImpl(`${config.apiUrl}/status`, {
      signal: AbortSignal.timeout(5_000),
    });
    if (!res.ok) {
      return {
        ok: false,
        code: 'connection',
        error: `Backend returned ${res.status}`,
      };
    }
  } catch {
    return {
      ok: false,
      code: 'connection',
      error: `Cannot reach mukuro backend at ${config.apiUrl}`,
    };
  }

  // 2. Does auth work? Send a minimal dispatch with empty content to check.
  //    A 401 means the token is wrong/missing.
  //    A 400 (bad_request) means auth passed but payload was invalid → auth OK.
  //    A 200 would also mean auth OK.
  try {
    const res = await fetchImpl(`${config.apiUrl}/dispatch`, {
      method: 'POST',
      headers: buildDispatchHeaders(config.authToken),
      body: JSON.stringify({ channel: '_probe' }),
      signal: AbortSignal.timeout(5_000),
    });
    if (res.status === 401) {
      return {
        ok: false,
        code: 'auth',
        error:
          'Authentication required. Start with: MUKURO_AUTH_TOKEN=<token> npm run dev',
      };
    }
  } catch {
    // Already confirmed reachable above; ignore transient errors.
  }

  return { ok: true };
}

// ---------------------------------------------------------------------------
// Main handler (injectable fetch for testing)
// ---------------------------------------------------------------------------

const DISPATCH_TIMEOUT_MS = 90_000;

export async function handleChatMessage(
  sender: MessageSender,
  msg: ClientMessage,
  config: ChatBridgeConfig,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  if (msg.type === 'send') {
    sender.send(JSON.stringify({ type: 'status', status: 'thinking' }));

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), DISPATCH_TIMEOUT_MS);

    try {
      const response = await fetchImpl(`${config.apiUrl}/dispatch`, {
        method: 'POST',
        headers: buildDispatchHeaders(config.authToken),
        body: JSON.stringify(buildDispatchEnvelope(msg)),
        signal: controller.signal,
      });
      const body = await response.json();
      sender.send(
        JSON.stringify(parseDispatchResult(response.ok, response.status, body)),
      );
    } catch (err: unknown) {
      const e = err as Error;
      sender.send(
        JSON.stringify({
          type: 'error',
          error:
            e.name === 'AbortError'
              ? 'Request timed out (90s)'
              : `Cannot reach mukuro backend: ${e.message}`,
          code: 'connection',
        } satisfies ServerMessage),
      );
    } finally {
      clearTimeout(timeout);
    }
  } else if (msg.type === 'load_history') {
    try {
      const url = `${config.apiUrl}/api/v1/chat/sessions/${encodeURIComponent(msg.chat_id)}/history`;
      const response = await fetchImpl(url);
      const body = await response.json();
      sender.send(JSON.stringify(parseHistoryResult(response.ok, body)));
    } catch (err: unknown) {
      const e = err as Error;
      sender.send(
        JSON.stringify({
          type: 'error',
          error: `Failed to load history: ${e.message}`,
          code: 'connection',
        } satisfies ServerMessage),
      );
    }
  } else if (msg.type === 'ping') {
    sender.send(JSON.stringify({ type: 'pong' }));
  }
}
