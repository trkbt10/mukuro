<div align="center">
  <h1>mukuro</h1>
  <p><strong>MoonBit Native Personal AI Assistant Gateway</strong></p>
</div>

mukuro is a personal AI assistant gateway built with MoonBit.
It runs locally and handles inbound events, agent execution, and outbound replies.

## Name

The name comes from the MoonBit reinterpretation of OpenClaw:
`moonclaw -> ムーンクロー -> むくろ（躯）`.

## Features

- Gateway lifecycle via CLI (`start`, `status`, `stop`)
- Background daemon mode on native target (`--daemon`)
- HTTP Control API (`/status`, `/health*`, `/dispatch*`)
- File-based runtime bootstrap for model and channels

## Setup

Requirements:

- MoonBit toolchain (`moon`)

```bash
moon build cmd/main --target native
```

## Quick Start

```bash
# 1) Generate initial config
_build/native/debug/build/cmd/main/main.exe onboard \
  --provider anthropic \
  --api-key YOUR_API_KEY \
  --model claude-3-5-sonnet-latest

# 2) Start gateway
_build/native/debug/build/cmd/main/main.exe gateway start --config .mukuro/config.json

# 3) Check status
_build/native/debug/build/cmd/main/main.exe gateway status

# 4) Stop gateway
_build/native/debug/build/cmd/main/main.exe gateway stop
```

## Operations

```bash
# Start in daemon mode
_build/native/debug/build/cmd/main/main.exe gateway start --daemon --config .mukuro/config.json

# Status as JSON
_build/native/debug/build/cmd/main/main.exe gateway status --json
```

## Control API

Start with Control API enabled:

```bash
_build/native/debug/build/cmd/main/main.exe gateway start --control-api --host 127.0.0.1 --port 8080
```

Endpoints:

- `GET /status`
- `GET /health`
- `GET /health/live`
- `GET /health/ready`
- `POST /dispatch`
- `POST /dispatch/outbound`

Examples:

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://127.0.0.1:8080/status

curl -X POST http://127.0.0.1:8080/dispatch \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"channel":"test","chat_id":"chat-1","sender_id":"u1","content":"hello"}'
```

Auth notes:

- If `gateway.auth_token` is set, Bearer token is required.
- Optional role-based authorization via `x-mukuro-role: viewer|operator|admin`.

## Configuration Example

`.mukuro/config.json`

```json
{
  "provider": "anthropic",
  "api_key": "YOUR_API_KEY",
  "default_model": "claude-3-5-sonnet-latest",
  "gateway": {
    "host": "127.0.0.1",
    "port": 8080,
    "auth_token": "change-me",
    "auto_connect_channels": true
  }
}
```

## Targets

- `native`: recommended, main features supported
- `js/wasm`: partial support (`gateway start` and related runtime features are limited)

## Utility Commands

```bash
_build/native/debug/build/cmd/main/main.exe help
_build/native/debug/build/cmd/main/main.exe version
_build/native/debug/build/cmd/main/main.exe cron list
```

## Development

```bash
moon test
moon check
moon info && moon fmt
```
