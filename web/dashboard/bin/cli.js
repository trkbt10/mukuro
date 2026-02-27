#!/usr/bin/env node

import { createServer } from 'http';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import sirv from 'sirv';
import { createProxyMiddleware } from 'http-proxy-middleware';

const __dirname = dirname(fileURLToPath(import.meta.url));
const distDir = join(__dirname, '..', 'dist');

// Parse CLI arguments
const args = process.argv.slice(2);
let port = 3960;
let apiUrl = 'http://localhost:6960';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '-p' || args[i] === '--port') {
    port = parseInt(args[++i], 10);
  } else if (args[i] === '-a' || args[i] === '--api') {
    apiUrl = args[++i];
  } else if (args[i] === '-h' || args[i] === '--help') {
    console.log(`
mukuro-dashboard - Web dashboard for mukuro

Usage:
  npx @mukuro/dashboard [options]

Options:
  -p, --port <port>   Port to listen on (default: 3960)
  -a, --api <url>     Mukuro API URL (default: http://localhost:6960)
  -h, --help          Show this help message

Environment variables:
  MUKURO_API_URL      Mukuro API URL (alternative to --api)
  PORT                Port to listen on (alternative to --port)

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

// Handle WebSocket upgrades
server.on('upgrade', (req, socket, head) => {
  if (req.url.startsWith('/ws')) {
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
  server.close(() => {
    process.exit(0);
  });
});
