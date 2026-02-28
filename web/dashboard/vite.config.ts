import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import type { ViteDevServer } from 'vite';
import { WebSocketServer } from 'ws';
import {
  handleChatMessage,
  probeBackend,
  type ClientMessage,
  type ChatBridgeConfig,
} from './src/lib/chatBridge';

const MUKURO_API = process.env.MUKURO_API_URL ?? 'http://localhost:6960';
const AUTH_TOKEN = process.env.MUKURO_AUTH_TOKEN ?? '';

function chatWebSocketPlugin(): {
  name: string;
  configureServer: (server: ViteDevServer) => void;
} {
  const config: ChatBridgeConfig = {
    apiUrl: MUKURO_API,
    authToken: AUTH_TOKEN,
  };

  return {
    name: 'mukuro-chat-ws',
    configureServer(server) {
      const wss = new WebSocketServer({ noServer: true });

      wss.on('connection', async (ws) => {
        // Probe backend before accepting messages
        const probe = await probeBackend(config);
        if (!probe.ok) {
          ws.send(
            JSON.stringify({
              type: 'error',
              error: probe.error,
              code: probe.code,
            }),
          );
          return;
        }
        ws.send(JSON.stringify({ type: 'status', status: 'ready' }));

        ws.on('message', async (raw) => {
          try {
            const msg: ClientMessage = JSON.parse(raw.toString());
            await handleChatMessage(ws, msg, config);
          } catch (err: unknown) {
            const e = err as Error;
            ws.send(
              JSON.stringify({
                type: 'error',
                error: `Invalid message: ${e.message}`,
              }),
            );
          }
        });
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
