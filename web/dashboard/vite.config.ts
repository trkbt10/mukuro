import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import type { ViteDevServer } from 'vite';
import type { WebSocket as WsWebSocket } from 'ws';
import { WebSocketServer } from 'ws';

const MUKURO_API = process.env.MUKURO_API_URL ?? 'http://localhost:6960';
const AUTH_TOKEN = process.env.MUKURO_AUTH_TOKEN ?? '';

interface ChatWebSocket extends WsWebSocket {
  chatId?: string;
}

function buildHeaders(): Record<string, string> {
  const h: Record<string, string> = { 'Content-Type': 'application/json' };
  if (AUTH_TOKEN) h['Authorization'] = `Bearer ${AUTH_TOKEN}`;
  return h;
}

async function handleChatMessage(ws: ChatWebSocket, msg: { type: string; content?: string; sender_name?: string }) {
  if (msg.type === 'send') {
    if (!ws.chatId) {
      ws.send(JSON.stringify({ type: 'error', error: 'Session not initialized' }));
      return;
    }
    ws.send(JSON.stringify({ type: 'status', status: 'thinking' }));

    const envelope = {
      channel: 'web_chat',
      chat_id: ws.chatId,
      sender_id: 'dashboard_user',
      sender_name: msg.sender_name || 'User',
      content: msg.content,
    };

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 90_000);

    try {
      const response = await fetch(`${MUKURO_API}/dispatch`, {
        method: 'POST',
        headers: buildHeaders(),
        body: JSON.stringify(envelope),
        signal: controller.signal,
      });
      const result = await response.json();

      if (!response.ok) {
        const error = response.status === 401
          ? 'Authentication failed – check MUKURO_AUTH_TOKEN'
          : (result.message || `Backend error (${response.status})`);
        ws.send(JSON.stringify({ type: 'error', error }));
      } else if (result.ok && result.response) {
        ws.send(JSON.stringify({
          type: 'message',
          role: 'assistant',
          content: result.response.content,
          timestamp: Date.now(),
        }));
      } else {
        ws.send(JSON.stringify({
          type: 'error',
          error: result.message || 'Unexpected response format from agent',
        }));
      }
    } catch (err) {
      const e = err as Error;
      ws.send(JSON.stringify({
        type: 'error',
        error: e.name === 'AbortError'
          ? 'Request timed out (90s)'
          : `Agent unavailable: ${e.message}`,
      }));
    } finally {
      clearTimeout(timeout);
    }
  } else if (msg.type === 'load_history') {
    if (!ws.chatId) {
      ws.send(JSON.stringify({ type: 'error', error: 'Session not initialized' }));
      return;
    }
    try {
      const response = await fetch(
        `${MUKURO_API}/api/v1/chat/sessions/${encodeURIComponent(ws.chatId)}/history`,
        { headers: buildHeaders() },
      );
      const result = await response.json();
      if (!response.ok) {
        ws.send(JSON.stringify({
          type: 'error',
          error: result.message || 'Failed to load history',
        }));
      } else {
        ws.send(JSON.stringify({
          type: 'history',
          messages: result.data?.messages || [],
        }));
      }
    } catch (err) {
      const e = err as Error;
      ws.send(JSON.stringify({
        type: 'error',
        error: `Failed to load history: ${e.message}`,
      }));
    }
  } else if (msg.type === 'ping') {
    ws.send(JSON.stringify({ type: 'pong' }));
  }
}

function chatWebSocketPlugin(): {
  name: string;
  configureServer: (server: ViteDevServer) => void;
} {
  return {
    name: 'mukuro-chat-ws',
    configureServer(server) {
      const wss = new WebSocketServer({ noServer: true });

      wss.on('connection', async (ws: ChatWebSocket) => {
        // Set up message handler first
        ws.on('message', async (raw) => {
          try {
            const msg = JSON.parse(raw.toString());
            await handleChatMessage(ws, msg);
          } catch (err) {
            const e = err as Error;
            ws.send(JSON.stringify({
              type: 'error',
              error: `Invalid message: ${e.message}`,
            }));
          }
        });

        // Create session via backend API
        try {
          const response = await fetch(`${MUKURO_API}/api/v1/chat/sessions`, {
            method: 'POST',
            headers: buildHeaders(),
          });
          const result = await response.json();

          if (!response.ok) {
            ws.send(JSON.stringify({
              type: 'error',
              error: result.message || 'Failed to create session',
              code: response.status === 401 ? 'auth' : 'session',
            }));
            return;
          }

          ws.chatId = result.data.chat_id;
          ws.send(JSON.stringify({ type: 'session', chat_id: ws.chatId }));
        } catch (err) {
          const e = err as Error;
          ws.send(JSON.stringify({
            type: 'error',
            error: `Failed to create session: ${e.message}`,
            code: 'session',
          }));
        }
      });

      server.httpServer?.on('upgrade', (req, socket, head) => {
        if (req.url === '/ws/chat') {
          wss.handleUpgrade(req, socket, head, (ws) => {
            wss.emit('connection', ws, req);
          });
        }
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), chatWebSocketPlugin()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      'react-editor-ui/viewers/MarkdownViewer/parser': path.resolve(
        __dirname,
        'node_modules/react-editor-ui/src/viewers/MarkdownViewer/parser',
      ),
    },
  },
  server: {
    port: 3960,
    strictPort: false,
    open: true,
    proxy: {
      '/api': {
        target: MUKURO_API,
        changeOrigin: true,
      },
      '/health': {
        target: MUKURO_API,
        changeOrigin: true,
      },
      '/status': {
        target: MUKURO_API,
        changeOrigin: true,
      },
    },
  },
  preview: {
    port: 3960,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: true,
  },
});
