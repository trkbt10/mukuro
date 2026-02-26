# Plugin Examples

Example plugins demonstrating the mukuro plugin system across different transports and languages.

## Overview

| Example | Transport | Language | Description |
|---------|-----------|----------|-------------|
| [hello_world_native](./hello_world_native/) | Stdio | MoonBit | Basic plugin showing MoonBit native implementation |
| [hello_world_js](./hello_world_js/) | Stdio | JavaScript | Basic plugin showing JavaScript implementation |
| [counter_http_js](./counter_http_js/) | HTTP | JavaScript | Stateful counter with HTTP transport |
| [echo_websocket_js](./echo_websocket_js/) | WebSocket | JavaScript | Real-time echo with WebSocket transport |

## Transport Comparison

### Stdio (Standard I/O)

- **Best for**: Simple tools, batch processing, command-line utilities
- **Communication**: Newline-delimited JSON (NDJSON) over stdin/stdout
- **Lifecycle**: Started as subprocess, managed by host

```bash
# Test stdio plugin
echo '{"jsonrpc":"2.0","method":"greet","params":{"name":"World"},"id":1}' | node index.js
```

### HTTP

- **Best for**: Stateless services, RESTful integrations, webhook receivers
- **Communication**: JSON-RPC 2.0 over HTTP POST
- **Lifecycle**: Runs as independent server

```bash
# Start server
node index.js

# Call method
curl -X POST http://localhost:9200/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"increment","id":1}'
```

### WebSocket

- **Best for**: Real-time communication, bidirectional messaging, pub/sub
- **Communication**: JSON-RPC 2.0 over WebSocket
- **Lifecycle**: Persistent connections, event-driven

```bash
# Install dependency
npm install ws

# Start server
node server.js

# Connect (using wscat)
wscat -c ws://localhost:9300
> {"jsonrpc":"2.0","method":"echo","params":{"message":"Hello"},"id":1}
```

## Quick Start

### Running Stdio Plugins

```bash
# Native (MoonBit)
moon build --target native
echo '{"jsonrpc":"2.0","method":"greet","params":{"name":"World"},"id":1}' | \
  ./_build/native/debug/build/examples/plugins/hello_world_native/hello_world_native.exe

# JavaScript
echo '{"jsonrpc":"2.0","method":"greet","params":{"name":"World"},"id":1}' | \
  node examples/plugins/hello_world_js/index.js
```

### Running HTTP Plugins

```bash
# Start server
node examples/plugins/counter_http_js/index.js

# In another terminal
curl http://localhost:9200/health
curl -X POST http://localhost:9200/rpc \
  -d '{"jsonrpc":"2.0","method":"status","id":1}'
```

### Running WebSocket Plugins

```bash
# Install ws dependency
cd examples/plugins/echo_websocket_js
npm install ws

# Start server
node server.js

# Connect with wscat (or any WebSocket client)
npx wscat -c ws://localhost:9300
```

## Creating Your Own Plugin

See [docs/PLUGIN_DEVELOPMENT.md](../../docs/PLUGIN_DEVELOPMENT.md) for a complete guide.

### Minimal Stdio Plugin (JavaScript)

```javascript
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on('line', (line) => {
  const { method, params, id } = JSON.parse(line);

  let response;
  if (method === 'my_method') {
    response = { jsonrpc: '2.0', result: { ok: true }, id };
  } else {
    response = { jsonrpc: '2.0', error: { code: -32601, message: 'Method not found' }, id };
  }

  console.log(JSON.stringify(response));
});
```

### Minimal manifest.json

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "type": "tool",
  "transport": "stdio",
  "capabilities": ["my_method"],
  "stdio": {
    "command": "node",
    "args": ["path/to/plugin.js"],
    "framing": "newline_delimited"
  }
}
```
