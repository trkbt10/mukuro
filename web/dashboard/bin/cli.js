#!/usr/bin/env node

import { createServer } from 'http';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import sirv from 'sirv';
import { createProxyMiddleware } from 'http-proxy-middleware';
import { WebSocketServer } from 'ws';

const __dirname = dirname(fileURLToPath(import.meta.url));
const distDir = join(__dirname, '..', 'dist');

// Parse CLI arguments
const args = process.argv.slice(2);
let port = 3960;
let apiUrl = 'http://localhost:6960';
let authToken = '';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '-p' || args[i] === '--port') {
    port = parseInt(args[++i], 10);
  } else if (args[i] === '-a' || args[i] === '--api') {
    apiUrl = args[++i];
  } else if (args[i] === '--token') {
    authToken = args[++i];
  } else if (args[i] === '-h' || args[i] === '--help') {
    console.log(`
mukuro-dashboard - Web dashboard for mukuro

Usage:
  npx @mukuro/dashboard [options]

Options:
  -p, --port <port>      Port to listen on (default: 3960)
  -a, --api <url>        Mukuro API URL (default: http://localhost:6960)
      --token <token>    Auth token for mukuro API
  -h, --help             Show this help message

Environment variables:
  MUKURO_API_URL         Mukuro API URL (alternative to --api)
  MUKURO_AUTH_TOKEN      Auth token for mukuro API (alternative to --token)
  PORT                   Port to listen on (alternative to --port)

Examples:
  npx @mukuro/dashboard
  npx @mukuro/dashboard --port 8000 --api http://mukuro.local:8080
`);
    process.exit(0);
  }
}

// Environment variable overrides
port = parseInt(process.env.PORT, 10) || port;
apiUrl = process.env.MUKURO_API_URL || apiUrl;
authToken = process.env.MUKURO_AUTH_TOKEN || authToken;

// Create static file server
const serve = sirv(distDir, {
  single: true, // SPA mode - serve index.html for all routes
  gzip: true,
  brotli: true,
});

// Create API proxy
const apiProxy = createProxyMiddleware({
  target: apiUrl,
  changeOrigin: true,
  ws: true,
  logLevel: 'warn',
});

// Create HTTP server
const server = createServer((req, res) => {
  // Proxy /api/* requests
  if (req.url.startsWith('/api/')) {
    return apiProxy(req, res);
  }
  // Serve static files
  serve(req, res);
});

// --- WebSocket Chat Bridge ---

const wss = new WebSocketServer({ noServer: true });

function buildHeaders() {
  const h = { 'Content-Type': 'application/json' };
  if (authToken) h['Authorization'] = `Bearer ${authToken}`;
  return h;
}

async function handleChatMessage(ws, msg) {
  if (msg.type === 'send') {
    ws.send(JSON.stringify({ type: 'status', status: 'thinking' }));

    const envelope = {
      channel: 'web_chat',
      chat_id: msg.chat_id,
      sender_id: 'dashboard_user',
      sender_name: msg.sender_name || 'User',
      content: msg.content,
    };

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 90_000);

    try {
      const response = await fetch(`${apiUrl}/dispatch`, {
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
      ws.send(JSON.stringify({
        type: 'error',
        error: err.name === 'AbortError'
          ? 'Request timed out (90s)'
          : `Agent unavailable: ${err.message}`,
      }));
    } finally {
      clearTimeout(timeout);
    }
  } else if (msg.type === 'load_history') {
    try {
      const response = await fetch(
        `${apiUrl}/api/v1/chat/sessions/${encodeURIComponent(msg.chat_id)}/history`,
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
      ws.send(JSON.stringify({
        type: 'error',
        error: `Failed to load history: ${err.message}`,
      }));
    }
  } else if (msg.type === 'ping') {
    ws.send(JSON.stringify({ type: 'pong' }));
  }
}

wss.on('connection', (ws) => {
  ws.send(JSON.stringify({ type: 'status', status: 'connected' }));

  ws.on('message', async (raw) => {
    try {
      const msg = JSON.parse(raw.toString());
      await handleChatMessage(ws, msg);
    } catch (err) {
      ws.send(JSON.stringify({
        type: 'error',
        error: `Invalid message: ${err.message}`,
      }));
    }
  });
});

// Handle WebSocket upgrades
server.on('upgrade', (req, socket, head) => {
  if (req.url === '/ws/chat') {
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  } else if (req.url.startsWith('/ws')) {
    apiProxy.upgrade(req, socket, head);
  }
});

server.listen(port, () => {
  console.log(`
  ┌─────────────────────────────────────────┐
  │                                         │
  │   mukuro dashboard                      │
  │                                         │
  │   Local:   http://localhost:${port.toString().padEnd(5)}      │
  │   API:     ${apiUrl.padEnd(27)}│
  │                                         │
  └─────────────────────────────────────────┘
`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  wss.close();
  server.close(() => {
    process.exit(0);
  });
});
