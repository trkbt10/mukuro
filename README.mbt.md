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

- Gateway lifecycle via CLI (`gateway`, `gateway status`, `gateway stop`)
- Background daemon mode on native target (`--daemon`)
- HTTP Control API (`/status`, `/health*`, `/dispatch*`)
- Interactive agent REPL and single-shot execution
- File-based runtime bootstrap for model and channels

## Setup

Requirements:

- MoonBit toolchain (`moon`)
- SQLite3 (`-lsqlite3`)
- zlib (`-lz`)

```bash
moon build --target native
```

The CLI binary is built to `_build/native/debug/build/cmd/main/main.exe`.

## Quick Start

```bash
MUKURO=_build/native/debug/build/cmd/main/main.exe

# 1) Generate initial config
$MUKURO onboard \
  --provider anthropic \
  --api-key YOUR_API_KEY \
  --model claude-sonnet-4-20250514

# 2) Start gateway (uses default config path automatically)
$MUKURO gateway

# 3) Check status
$MUKURO gateway status

# 4) Stop gateway
$MUKURO gateway stop
```

The default config path is OS-standard:
- macOS: `~/Library/Application Support/mukuro/config.json`
- Linux: `~/.local/share/mukuro/config.json`

Use `--local` to store config in `.mukuro/` relative to the current directory instead.

## Operations

```bash
# Start in daemon mode
$MUKURO gateway --daemon

# Specify custom config
$MUKURO gateway --config /path/to/config.json

# Override host/port (default: 127.0.0.1:6960)
$MUKURO gateway --host 0.0.0.0 --port 8080

# Status as JSON
$MUKURO gateway status --json

# Interactive agent REPL
$MUKURO agent

# Single-shot agent execution
$MUKURO agent -m "What is MoonBit?"

# Use project-local data directory
$MUKURO --local gateway
```

## Control API

The gateway always serves the HTTP Control API when running in foreground mode.

Endpoints:

- `GET /status`
- `GET /health`
- `GET /health/live`
- `GET /health/ready`
- `POST /dispatch`
- `POST /dispatch/outbound`

Examples:

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://127.0.0.1:6960/status

curl -X POST http://127.0.0.1:6960/dispatch \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"channel":"test","chat_id":"chat-1","sender_id":"u1","content":"hello"}'
```

Auth notes:

- If `gateway.auth_token` is set, Bearer token is required.
- Optional role-based authorization via `x-mukuro-role: viewer|operator|admin`.

## Configuration Example

```json
{
  "provider": "anthropic",
  "api_key": "YOUR_API_KEY",
  "default_model": "claude-sonnet-4-20250514",
  "gateway": {
    "host": "127.0.0.1",
    "port": 6960,
    "auth_token": "change-me",
    "auto_connect_channels": true
  }
}
```

## Targets

- `native`: recommended, all features supported
- `js/wasm`: partial support (`gateway` and related runtime features are limited)

## Utility Commands

```bash
$MUKURO help
$MUKURO version
$MUKURO cron list
$MUKURO config path
$MUKURO config show
```

## Development

```bash
moon build --target native          # build
moon test --target native           # run all tests
moon check --target native          # type check
moon info && moon fmt               # regenerate .mbti files & format
```
