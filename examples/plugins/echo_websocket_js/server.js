#!/usr/bin/env node
/**
 * Echo Plugin (WebSocket Transport)
 * Demonstrates WebSocket-based plugin communication with real-time messaging.
 *
 * Features:
 * - Real-time bidirectional communication
 * - Broadcast to all connected clients
 * - Message history
 * - Connection tracking
 *
 * Usage:
 *   npm install ws  # Required dependency
 *   node server.js
 *
 * Connect: wscat -c ws://localhost:9300
 */

const WebSocket = require('ws');

const PORT = process.env.WS_PORT || 9300;

// Plugin state
const state = {
  messageHistory: [],
  maxHistory: 100,
  totalMessages: 0,
  startTime: Date.now()
};

// Track connected clients
const clients = new Set();

/**
 * Broadcast message to all connected clients
 */
function broadcast(message, excludeClient = null) {
  const data = JSON.stringify(message);
  for (const client of clients) {
    if (client !== excludeClient && client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  }
}

/**
 * Add message to history
 */
function addToHistory(method, params, result) {
  state.messageHistory.push({
    timestamp: Date.now(),
    method,
    params,
    result
  });
  if (state.messageHistory.length > state.maxHistory) {
    state.messageHistory.shift();
  }
}

/**
 * Handle JSON-RPC request
 */
function handleRequest(request, ws) {
  const { method, params, id } = request;
  state.totalMessages++;

  switch (method) {
    case 'echo': {
      const message = params?.message;
      if (!message || typeof message !== 'string') {
        return {
          jsonrpc: '2.0',
          error: { code: -32602, message: 'Invalid params: message is required' },
          id
        };
      }
      const result = {
        echoed: message,
        timestamp: Date.now(),
        client_count: clients.size
      };
      addToHistory('echo', params, result);
      return { jsonrpc: '2.0', result, id };
    }

    case 'broadcast': {
      const message = params?.message;
      if (!message || typeof message !== 'string') {
        return {
          jsonrpc: '2.0',
          error: { code: -32602, message: 'Invalid params: message is required' },
          id
        };
      }
      const notification = {
        jsonrpc: '2.0',
        method: 'message',
        params: {
          type: 'broadcast',
          message,
          timestamp: Date.now(),
          from: 'anonymous'
        }
      };
      broadcast(notification, ws);
      addToHistory('broadcast', params, { delivered_to: clients.size - 1 });
      return {
        jsonrpc: '2.0',
        result: { status: 'sent', delivered_to: clients.size - 1 },
        id
      };
    }

    case 'subscribe': {
      // Mark this client as subscribed (in this simple example, all clients receive broadcasts)
      ws.subscribed = true;
      return {
        jsonrpc: '2.0',
        result: { subscribed: true, client_count: clients.size },
        id
      };
    }

    case 'history': {
      const limit = Math.min(params?.limit ?? 10, state.maxHistory);
      const messages = state.messageHistory.slice(-limit);
      return {
        jsonrpc: '2.0',
        result: { messages, count: messages.length, total: state.messageHistory.length },
        id
      };
    }

    case 'ping': {
      return {
        jsonrpc: '2.0',
        result: { pong: true, timestamp: Date.now(), latency_ms: 0 },
        id
      };
    }

    case 'status': {
      return {
        jsonrpc: '2.0',
        result: {
          name: 'Echo WebSocket',
          version: '1.0.0',
          transport: 'websocket',
          connected_clients: clients.size,
          total_messages: state.totalMessages,
          history_size: state.messageHistory.length,
          uptime_ms: Date.now() - state.startTime
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

// Create WebSocket server
const wss = new WebSocket.Server({ port: PORT });

console.log(`[echo-ws] WebSocket plugin started on ws://localhost:${PORT}`);
console.log(`[echo-ws] Methods: echo, broadcast, subscribe, history, ping, status`);

wss.on('connection', (ws, req) => {
  clients.add(ws);
  console.log(`[echo-ws] Client connected (${clients.size} total)`);

  // Send welcome message
  ws.send(JSON.stringify({
    jsonrpc: '2.0',
    method: 'connected',
    params: {
      message: 'Welcome to Echo WebSocket Plugin',
      client_count: clients.size,
      timestamp: Date.now()
    }
  }));

  ws.on('message', (data) => {
    let request;
    try {
      request = JSON.parse(data.toString());
    } catch (e) {
      ws.send(JSON.stringify({
        jsonrpc: '2.0',
        error: { code: -32700, message: 'Parse error' },
        id: null
      }));
      return;
    }

    // Validate JSON-RPC 2.0
    if (request.jsonrpc !== '2.0' || !request.method) {
      ws.send(JSON.stringify({
        jsonrpc: '2.0',
        error: { code: -32600, message: 'Invalid Request' },
        id: request.id ?? null
      }));
      return;
    }

    const response = handleRequest(request, ws);
    ws.send(JSON.stringify(response));
  });

  ws.on('close', () => {
    clients.delete(ws);
    console.log(`[echo-ws] Client disconnected (${clients.size} remaining)`);
  });

  ws.on('error', (err) => {
    console.error('[echo-ws] WebSocket error:', err.message);
    clients.delete(ws);
  });
});

// Graceful shutdown
function shutdown() {
  console.log('[echo-ws] Shutting down...');

  // Notify all clients
  const goodbye = JSON.stringify({
    jsonrpc: '2.0',
    method: 'disconnecting',
    params: { reason: 'Server shutting down' }
  });

  for (const client of clients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(goodbye);
      client.close();
    }
  }

  wss.close(() => process.exit(0));
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
