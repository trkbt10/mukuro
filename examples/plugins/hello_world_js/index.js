#!/usr/bin/env node
/**
 * Hello World Plugin (Pure JavaScript)
 * A minimal example plugin demonstrating the plugin system.
 * Provides: greet, echo, reverse, and status methods.
 *
 * Communication: stdin/stdout JSON-RPC 2.0 over newline-delimited JSON
 */

const readline = require('readline');

// Plugin state
const state = {
  name: 'Hello World JS',
  greetingPrefix: 'Hello',
  uppercase: false,
  greetingCount: 0
};

/**
 * Handle greet method
 */
function handleGreet(params, id) {
  const name = params?.name;
  if (!name || typeof name !== 'string') {
    return errorResponse(-32602, 'Invalid params: name is required', id);
  }
  if (name.trim() === '') {
    return errorResponse(-32602, 'Invalid params: name cannot be empty', id);
  }

  state.greetingCount++;
  let message = `${state.greetingPrefix}, ${name}!`;
  if (state.uppercase) {
    message = message.toUpperCase();
  }

  return successResponse({
    message,
    count: state.greetingCount
  }, id);
}

/**
 * Handle echo method
 */
function handleEcho(params, id) {
  const message = params?.message;
  if (!message || typeof message !== 'string') {
    return errorResponse(-32602, 'Invalid params: message is required', id);
  }

  let echoed = message;
  if (state.uppercase) {
    echoed = echoed.toUpperCase();
  }

  return successResponse({ echoed }, id);
}

/**
 * Handle reverse method
 */
function handleReverse(params, id) {
  const text = params?.text;
  if (!text || typeof text !== 'string') {
    return errorResponse(-32602, 'Invalid params: text is required', id);
  }

  let reversed = text.split('').reverse().join('');
  if (state.uppercase) {
    reversed = reversed.toUpperCase();
  }

  return successResponse({ reversed }, id);
}

/**
 * Handle status method
 */
function handleStatus(params, id) {
  return successResponse({
    name: state.name,
    version: '1.0.0',
    greeting_count: state.greetingCount,
    uppercase: state.uppercase,
    runtime: 'nodejs'
  }, id);
}

/**
 * Create a JSON-RPC success response
 */
function successResponse(result, id) {
  return {
    jsonrpc: '2.0',
    result,
    id
  };
}

/**
 * Create a JSON-RPC error response
 */
function errorResponse(code, message, id) {
  return {
    jsonrpc: '2.0',
    error: { code, message },
    id
  };
}

/**
 * Handle a JSON-RPC request
 */
function handleRequest(request) {
  const { method, params, id } = request;

  switch (method) {
    case 'greet':
      return handleGreet(params, id);
    case 'echo':
      return handleEcho(params, id);
    case 'reverse':
      return handleReverse(params, id);
    case 'status':
      return handleStatus(params, id);
    default:
      return errorResponse(-32601, `Method not found: ${method}`, id);
  }
}

/**
 * Process a line of input
 */
function processLine(line) {
  const trimmed = line.trim();
  if (!trimmed) return;

  let request;
  try {
    request = JSON.parse(trimmed);
  } catch (e) {
    const response = errorResponse(-32700, 'Parse error', null);
    console.log(JSON.stringify(response));
    return;
  }

  // Validate JSON-RPC 2.0 format
  if (request.jsonrpc !== '2.0' || !request.method) {
    const response = errorResponse(-32600, 'Invalid Request', request.id ?? null);
    console.log(JSON.stringify(response));
    return;
  }

  const response = handleRequest(request);
  console.log(JSON.stringify(response));
}

// Main: Set up readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on('line', processLine);

rl.on('close', () => {
  process.exit(0);
});
