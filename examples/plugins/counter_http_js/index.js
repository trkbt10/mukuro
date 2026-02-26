#!/usr/bin/env node
/**
 * Counter Plugin (HTTP Transport)
 * Demonstrates HTTP-based plugin communication with stateful operations.
 *
 * Provides: increment, decrement, get, reset, set methods
 *
 * Usage:
 *   node index.js
 *   curl -X POST http://localhost:9200/rpc -d '{"jsonrpc":"2.0","method":"increment","id":1}'
 */

const http = require('http');

const PORT = process.env.COUNTER_PORT || 9200;

// Plugin state
const state = {
  counters: new Map(),  // Multiple named counters
  defaultCounter: 0,
  totalOperations: 0
};

/**
 * Get counter value
 */
function getCounter(name) {
  if (!name || name === 'default') {
    return state.defaultCounter;
  }
  return state.counters.get(name) || 0;
}

/**
 * Set counter value
 */
function setCounter(name, value) {
  state.totalOperations++;
  if (!name || name === 'default') {
    state.defaultCounter = value;
  } else {
    state.counters.set(name, value);
  }
}

/**
 * Handle JSON-RPC request
 */
function handleRequest(request) {
  const { method, params, id } = request;

  switch (method) {
    case 'increment': {
      const name = params?.name;
      const amount = params?.amount ?? 1;
      const current = getCounter(name);
      const newValue = current + amount;
      setCounter(name, newValue);
      return {
        jsonrpc: '2.0',
        result: { value: newValue, previous: current },
        id
      };
    }

    case 'decrement': {
      const name = params?.name;
      const amount = params?.amount ?? 1;
      const current = getCounter(name);
      const newValue = current - amount;
      setCounter(name, newValue);
      return {
        jsonrpc: '2.0',
        result: { value: newValue, previous: current },
        id
      };
    }

    case 'get': {
      const name = params?.name;
      return {
        jsonrpc: '2.0',
        result: { value: getCounter(name), name: name || 'default' },
        id
      };
    }

    case 'set': {
      const name = params?.name;
      const value = params?.value;
      if (typeof value !== 'number') {
        return {
          jsonrpc: '2.0',
          error: { code: -32602, message: 'Invalid params: value must be a number' },
          id
        };
      }
      const previous = getCounter(name);
      setCounter(name, value);
      return {
        jsonrpc: '2.0',
        result: { value, previous },
        id
      };
    }

    case 'reset': {
      const name = params?.name;
      const previous = getCounter(name);
      setCounter(name, 0);
      return {
        jsonrpc: '2.0',
        result: { value: 0, previous },
        id
      };
    }

    case 'list': {
      const counters = { default: state.defaultCounter };
      for (const [name, value] of state.counters) {
        counters[name] = value;
      }
      return {
        jsonrpc: '2.0',
        result: { counters, total_operations: state.totalOperations },
        id
      };
    }

    case 'status': {
      return {
        jsonrpc: '2.0',
        result: {
          name: 'Counter HTTP',
          version: '1.0.0',
          transport: 'http',
          counter_count: state.counters.size + 1,
          total_operations: state.totalOperations
        },
        id
      };
    }

    default:
      return {
        jsonrpc: '2.0',
        error: { code: -32601, message: `Method not found: ${method}` },
        id
      };
  }
}

/**
 * HTTP request handler
 */
async function httpHandler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Health check endpoint
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', uptime: process.uptime() }));
    return;
  }

  // JSON-RPC endpoint
  if (req.method === 'POST' && (req.url === '/rpc' || req.url === '/')) {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      let request;
      try {
        request = JSON.parse(body);
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          jsonrpc: '2.0',
          error: { code: -32700, message: 'Parse error' },
          id: null
        }));
        return;
      }

      // Validate JSON-RPC 2.0
      if (request.jsonrpc !== '2.0' || !request.method) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          jsonrpc: '2.0',
          error: { code: -32600, message: 'Invalid Request' },
          id: request.id ?? null
        }));
        return;
      }

      const response = handleRequest(request);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(response));
    });
    return;
  }

  // 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
}

// Start server
const server = http.createServer(httpHandler);

server.listen(PORT, () => {
  console.log(`[counter] HTTP plugin started on port ${PORT}`);
  console.log(`[counter] Endpoints:`);
  console.log(`  POST http://localhost:${PORT}/rpc     - JSON-RPC 2.0`);
  console.log(`  GET  http://localhost:${PORT}/health  - Health check`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[counter] Shutting down...');
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  console.log('[counter] Shutting down...');
  server.close(() => process.exit(0));
});
