# mukuro Plugin Development Guide

This guide explains how to create custom plugins for the mukuro agent framework.

## Table of Contents

1. [Plugin System Overview](#plugin-system-overview)
2. [Architecture](#architecture)
3. [Core Concepts](#core-concepts)
4. [JSON-RPC 2.0 Protocol](#json-rpc-20-protocol)
5. [Plugin Manifest (manifest.json)](#plugin-manifest-manifestjson)
6. [Creating a Plugin](#creating-a-plugin)
7. [RPC Helper Reference](#rpc-helper-reference)
8. [Existing Plugins](#existing-plugins)
9. [Best Practices](#best-practices)

---

## Plugin System Overview

mukuro uses a plugin architecture that allows extending the agent with:
- **Channel plugins** - Connect to messaging platforms (Discord, Slack, Email, etc.)
- **Tool plugins** - Add custom agent tools (calculators, APIs, utilities)
- **Storage plugins** - Provide persistence (databases, memory stores)
- **Custom plugins** - Any other functionality

Plugins communicate with the host via **JSON-RPC 2.0** over configurable transports.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Agent Host                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │PluginHost   │  │PluginRegistry│  │PluginInstance│   │
│  │(host.mbt)   │──│(registry.mbt)│──│              │   │
│  └──────┬──────┘  └─────────────┘  └─────────────┘     │
│         │ JSON-RPC 2.0                                  │
└─────────┼───────────────────────────────────────────────┘
          │
    ┌─────┴─────┐     Transports:
    │           │     - HTTP (webhook)
    ▼           ▼     - Stdio (subprocess)
┌───────┐ ┌───────┐   - WebSocket (real-time)
│Plugin │ │Plugin │
│   A   │ │   B   │
└───────┘ └───────┘
```

### Key Components

| Component | File | Description |
|-----------|------|-------------|
| `PluginManifest` | `interfaces/plugin.mbt:48-67` | Plugin metadata and configuration |
| `PluginHost` | `interfaces/plugin.mbt:284-302` | Plugin lifecycle management trait |
| `PluginHostImpl` | `core/plugin/host.mbt` | Host implementation |
| `PluginRegistry` | `core/plugin/registry.mbt` | Plugin instance storage |
| `PluginMessageHandler` | `interfaces/plugin.mbt:307-310` | Request handler trait |

## Core Concepts

### PluginManifest

Every plugin is described by a manifest:

```moonbit
pub(all) struct PluginManifest {
  id : String               // Unique plugin identifier
  name : String             // Human-readable name
  version : String          // Semantic version
  plugin_type : PluginType  // Channel, Tool, Storage, Custom
  transport : PluginTransport // Http, Stdio, WebSocket
  http : PluginHttpConfig?  // HTTP configuration (if transport is Http)
  entry : String?           // Entry command to start plugin
  capabilities : Array[String] // Plugin capabilities
  config : Json?            // Plugin-specific configuration
}
```

### PluginType

```moonbit
pub(all) enum PluginType {
  Channel      // Messaging platform integration
  Tool         // Agent tools
  Storage      // Persistence providers
  Custom(String) // Custom type
}
```

### PluginTransport

```moonbit
pub(all) enum PluginTransport {
  Http       // HTTP/webhook transport
  Stdio      // stdin/stdout (subprocess)
  WebSocket  // Real-time WebSocket
}
```

### PluginMessageHandler Trait

Implement this trait to handle incoming JSON-RPC requests:

```moonbit
pub(open) trait PluginMessageHandler {
  handle_request(Self, JsonRpcRequest) -> JsonRpcResponse
}
```

## JSON-RPC 2.0 Protocol

All plugin communication uses JSON-RPC 2.0.

### Request Structure

```moonbit
pub(all) struct JsonRpcRequest {
  jsonrpc : String    // Always "2.0"
  rpc_method : String // Method name
  params : Json?      // Parameters object
  id : Int?           // Request ID (null for notifications)
}
```

### Response Structure

```moonbit
pub(all) struct JsonRpcResponse {
  jsonrpc : String       // Always "2.0"
  result : Json?         // Result (on success)
  error : JsonRpcError?  // Error (on failure)
  id : Int?              // Request ID
}
```

### Standard Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| -32700 | `jsonrpc_error_parse_error()` | Parse error |
| -32600 | `jsonrpc_error_invalid_request()` | Invalid Request |
| -32601 | `jsonrpc_error_method_not_found()` | Method not found |
| -32602 | `jsonrpc_error_invalid_params()` | Invalid params |
| -32603 | `jsonrpc_error_internal_error()` | Internal error |

## Plugin Manifest (manifest.json)

Plugins are discovered and loaded via a `manifest.json` file. This file describes the plugin's metadata, transport configuration, and capability schemas.

### Basic Structure

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "type": "tool",
  "transport": "stdio",
  "capabilities": ["method1", "method2"],
  "stdio": { ... },
  "capabilitySchemas": { ... }
}
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique plugin identifier (kebab-case recommended) |
| `name` | string | Human-readable display name |
| `version` | string | Semantic version (e.g., "1.0.0") |
| `type` | string | Plugin type: `"tool"`, `"channel"`, `"storage"`, or `"custom:xxx"` |
| `transport` | string | Communication method: `"stdio"`, `"http"`, or `"websocket"` |
| `capabilities` | string[] | List of JSON-RPC methods this plugin provides |

### Transport Configuration

#### Stdio Transport

For subprocess-based plugins communicating via stdin/stdout:

```json
{
  "transport": "stdio",
  "stdio": {
    "command": "node",
    "args": ["path/to/plugin.js"],
    "framing": "newline_delimited",
    "startupTimeoutMs": 5000,
    "restartPolicy": {
      "type": "onFailure",
      "maxRetries": 3,
      "delayMs": 1000
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `command` | string | Executable command to run |
| `args` | string[] | Command-line arguments |
| `framing` | string | Message framing: `"newline_delimited"` (NDJSON) |
| `startupTimeoutMs` | number | Maximum time to wait for plugin startup (ms) |
| `restartPolicy.type` | string | `"onFailure"`, `"always"`, or `"never"` |
| `restartPolicy.maxRetries` | number | Maximum restart attempts |
| `restartPolicy.delayMs` | number | Delay between restart attempts (ms) |

#### HTTP Transport

For webhook-based plugins:

```json
{
  "transport": "http",
  "http": {
    "port": 9200,
    "baseUrl": "http://localhost:9200",
    "rpcEndpoint": "/rpc",
    "healthEndpoint": "/health"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `port` | number | Port the HTTP server listens on |
| `baseUrl` | string | Base URL for the plugin |
| `rpcEndpoint` | string | Path for JSON-RPC requests |
| `healthEndpoint` | string | Path for health check (optional) |

#### WebSocket Transport

For real-time bidirectional communication:

```json
{
  "transport": "websocket",
  "websocket": {
    "port": 9300,
    "url": "ws://localhost:9300",
    "reconnect": {
      "enabled": true,
      "maxRetries": 5,
      "delayMs": 1000,
      "backoffMultiplier": 2
    },
    "heartbeat": {
      "enabled": true,
      "intervalMs": 30000,
      "timeoutMs": 10000
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `port` | number | Port the WebSocket server listens on |
| `url` | string | WebSocket connection URL |
| `reconnect.enabled` | boolean | Auto-reconnect on disconnect |
| `reconnect.maxRetries` | number | Maximum reconnection attempts |
| `reconnect.delayMs` | number | Initial reconnection delay |
| `reconnect.backoffMultiplier` | number | Delay multiplier for each retry |
| `heartbeat.enabled` | boolean | Enable ping/pong heartbeat |
| `heartbeat.intervalMs` | number | Heartbeat interval |
| `heartbeat.timeoutMs` | number | Heartbeat timeout |

### Capability Schemas

Define JSON Schema for each capability's parameters and return values:

```json
{
  "capabilitySchemas": {
    "greet": {
      "description": "Generate a greeting message",
      "parameters": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "description": "Name to greet"
          }
        },
        "required": ["name"]
      },
      "returns": {
        "type": "object",
        "properties": {
          "message": { "type": "string" },
          "count": { "type": "integer" }
        }
      }
    }
  }
}
```

Each capability schema contains:

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | What this capability does |
| `parameters` | object | JSON Schema for input parameters |
| `parameters.properties` | object | Parameter definitions |
| `parameters.required` | string[] | Required parameter names |
| `returns` | object | JSON Schema for return value |

### Complete Example (Native MoonBit Plugin)

```json
{
  "id": "hello-world",
  "name": "Hello World Plugin",
  "version": "1.0.0",
  "type": "tool",
  "transport": "stdio",
  "capabilities": ["greet", "echo", "reverse", "status"],
  "stdio": {
    "command": "./_build/native/debug/build/examples/plugins/hello_world_native/hello_world_native.exe",
    "args": [],
    "framing": "newline_delimited",
    "startupTimeoutMs": 5000,
    "restartPolicy": {
      "type": "onFailure",
      "maxRetries": 3,
      "delayMs": 1000
    }
  },
  "capabilitySchemas": {
    "greet": {
      "description": "Generate a greeting message",
      "parameters": {
        "type": "object",
        "properties": {
          "name": { "type": "string", "description": "Name to greet" }
        },
        "required": ["name"]
      },
      "returns": {
        "type": "object",
        "properties": {
          "message": { "type": "string" },
          "count": { "type": "integer" }
        }
      }
    },
    "status": {
      "description": "Get plugin status",
      "parameters": { "type": "object", "properties": {} },
      "returns": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "version": { "type": "string" },
          "greeting_count": { "type": "integer" },
          "uppercase": { "type": "boolean" }
        }
      }
    }
  }
}
```

### Complete Example (JavaScript Plugin)

```json
{
  "id": "hello-world-js",
  "name": "Hello World Plugin (JS)",
  "version": "1.0.0",
  "type": "tool",
  "transport": "stdio",
  "capabilities": ["greet", "echo", "reverse", "status"],
  "stdio": {
    "command": "node",
    "args": ["examples/plugins/hello_world_js/index.js"],
    "framing": "newline_delimited",
    "startupTimeoutMs": 5000,
    "restartPolicy": {
      "type": "onFailure",
      "maxRetries": 3,
      "delayMs": 1000
    }
  },
  "capabilitySchemas": {
    "greet": {
      "description": "Generate a greeting message",
      "parameters": {
        "type": "object",
        "properties": {
          "name": { "type": "string", "description": "Name to greet" }
        },
        "required": ["name"]
      },
      "returns": {
        "type": "object",
        "properties": {
          "message": { "type": "string" },
          "count": { "type": "integer" }
        }
      }
    },
    "status": {
      "description": "Get plugin status",
      "parameters": { "type": "object", "properties": {} },
      "returns": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "version": { "type": "string" },
          "greeting_count": { "type": "integer" },
          "uppercase": { "type": "boolean" },
          "runtime": { "type": "string" }
        }
      }
    }
  }
}
```

## Creating a Plugin

### Step 1: Create Package Structure

```
my_plugin/
├── moon.pkg           # Package definition
├── my_plugin.mbt      # Plugin implementation
└── my_plugin_test.mbt # Tests
```

### Step 2: Define moon.pkg

```moonbit
import {
  "trkbt10/mukuro/interfaces",
}
```

### Step 3: Implement Plugin Structure

```moonbit
pub struct MyPlugin {
  name : String
  // ... plugin state
}

pub fn MyPlugin::new(name~ : String) -> MyPlugin {
  { name }
}
```

### Step 4: Implement handle_request

```moonbit
pub fn MyPlugin::handle_request(
  self : MyPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "my_method" => self.handle_my_method(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}
```

### Step 5: Implement Method Handlers

```moonbit
fn MyPlugin::handle_my_method(
  self : MyPlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  // Extract parameters
  let param = match @interfaces.rpc_require_string(request, "param") {
    Ok(v) => v
    Err(response) => return response
  }

  // Process and return result
  @interfaces.JsonRpcResponse::success(
    result={ "message": "Hello, \{param}!" },
    id=request.id,
  )
}
```

### Step 6: Create Manifest

```moonbit
pub fn MyPlugin::manifest(self : MyPlugin) -> @interfaces.PluginManifest {
  {
    id: "my-plugin",
    name: self.name,
    version: "1.0.0",
    plugin_type: @interfaces.PluginType::Tool,
    transport: @interfaces.PluginTransport::Stdio,
    http: None,
    entry: None,
    capabilities: ["my_method"],
    config: None,
  }
}
```

## RPC Helper Reference

### Parameter Extraction (`interfaces/rpc_params.mbt`)

#### Required Parameters

```moonbit
// String - returns Err(JsonRpcResponse) on failure
rpc_require_string(request, "key") -> Result[String, JsonRpcResponse]

// Int
rpc_require_int(request, "key") -> Result[Int, JsonRpcResponse]

// Int64
rpc_require_int64(request, "key") -> Result[Int64, JsonRpcResponse]

// Double
rpc_require_double(request, "key") -> Result[Double, JsonRpcResponse]

// Bool
rpc_require_bool(request, "key") -> Result[Bool, JsonRpcResponse]
```

#### Optional Parameters with Defaults

```moonbit
// String with default
rpc_optional_string(request, "key", "default") -> String

// Int with default
rpc_optional_int(request, "key", 0) -> Int

// Int64 with default
rpc_optional_int64(request, "key", 0L) -> Int64

// Double with default
rpc_optional_double(request, "key", 0.0) -> Double

// Bool with default
rpc_optional_bool(request, "key", false) -> Bool
```

#### Optional Parameters (None if not present)

```moonbit
rpc_string_or_none(request, "key") -> String?
rpc_int_or_none(request, "key") -> Int?
rpc_int64_or_none(request, "key") -> Int64?
rpc_double_or_none(request, "key") -> Double?
```

#### Array Parameters

```moonbit
rpc_string_array(request, "key") -> Array[String]
rpc_double_array(request, "key") -> Array[Double]
```

#### Object Parameters

```moonbit
rpc_get_params(request) -> Map[String, Json]?
rpc_object_or_none(request, "key") -> Map[String, Json]?
```

### Response Builders (`interfaces/rpc_helpers.mbt`)

```moonbit
// Success with custom result
JsonRpcResponse::success(result=json, id=request.id)

// Simple OK response
rpc_ok(request.id) -> JsonRpcResponse  // {"ok": true}

// Status response
rpc_success_status("connected", request.id)

// Boolean result
rpc_success_bool("key", true, request.id)

// Integer result
rpc_success_int("count", 42, request.id)

// Double result
rpc_success_double("value", 3.14, request.id)

// Array result
rpc_success_array("items", items, to_json_fn, request.id)

// Status for connectable plugins
rpc_status_response(is_connected, extra_fields, request.id)

// Connect/disconnect responses
rpc_connect_response(request.id)
rpc_disconnect_response(request.id)
```

### Error Responses

```moonbit
// Method not found
rpc_method_not_found("unknown_method", request.id)

// Invalid parameters
rpc_invalid_params("Missing required field", request.id)

// Resource not found
rpc_not_found("User", request.id)

// Custom error
JsonRpcResponse::error(
  code=-32603,
  message="Something went wrong",
  id=request.id,
)
```

## Existing Plugins

### UtilityToolPlugin (`adapters/plugins/tools.mbt`)

A tool plugin providing utility functions:

| Method | Parameters | Returns |
|--------|------------|---------|
| `calculate` | `expression: String` | `{expression, result}` |
| `random_int` | `min?: Int, max?: Int` | `{value: Int}` |
| `random_float` | - | `{value: Double}` |
| `uuid` | - | `{uuid: String}` |
| `base64_encode` | `input: String` | `{encoded: String}` |

**Example usage:**

```moonbit
// Create plugin
let plugin = UtilityToolPlugin::new(name="utils")

// Handle request
let request = JsonRpcRequest::new(
  rpc_method="calculate",
  params=Some({ "expression": "2 + 2" }),
  id=Some(1),
)
let response = plugin.handle_request(request)
// response.result = {"expression": "2 + 2", "result": 4.0}
```

## Best Practices

### 1. Always Use RPC Helpers

Use the provided helpers for consistent error handling:

```moonbit
// Good - uses helper
let name = match @interfaces.rpc_require_string(request, "name") {
  Ok(n) => n
  Err(response) => return response
}

// Bad - manual parsing
let name = match request.params {
  Some(Object(obj)) =>
    match obj.get("name") {
      Some(String(n)) => n
      _ => return JsonRpcResponse::error(...)
    }
  _ => return JsonRpcResponse::error(...)
}
```

### 2. Handle Unknown Methods Gracefully

Always include a catch-all pattern:

```moonbit
match request.rpc_method {
  "method1" => self.handle_method1(request)
  "method2" => self.handle_method2(request)
  _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
}
```

### 3. Document Capabilities

List all methods in the manifest capabilities:

```moonbit
capabilities: ["greet", "echo", "reverse", "status"]
```

### 4. Use Descriptive Error Messages

```moonbit
Err(rpc_invalid_params("Name must be non-empty", request.id))
```

### 5. Keep Methods Idempotent

When possible, make methods safe to retry.

### 6. Test Thoroughly

Write tests for:
- Normal operation
- Missing parameters
- Invalid parameter types
- Edge cases

```moonbit
test "greet with name" {
  let plugin = MyPlugin::new(name="test")
  let request = JsonRpcRequest::new(
    rpc_method="greet",
    params=Some({ "name": "World" }),
    id=Some(1),
  )
  let response = plugin.handle_request(request)
  assert_true!(response.error.is_empty())
  // Check result...
}
```

---

## See Also

### Example Plugins

| Example | Transport | Language | Description |
|---------|-----------|----------|-------------|
| `examples/plugins/hello_world_native/` | Stdio | MoonBit | Basic greet/echo/reverse |
| `examples/plugins/hello_world_js/` | Stdio | JavaScript | Basic greet/echo/reverse |
| `examples/plugins/counter_http_js/` | HTTP | JavaScript | Stateful counter |
| `examples/plugins/echo_websocket_js/` | WebSocket | JavaScript | Real-time messaging |

### Source Files

- `adapters/plugins/tools.mbt` - Real tool plugin implementation
- `interfaces/plugin.mbt` - Plugin interfaces
- `interfaces/rpc_params.mbt` - Parameter extraction
- `interfaces/rpc_helpers.mbt` - Response builders
