#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

BIN="_build/native/debug/build/cmd/main/main.exe"

cleanup() {
  "$BIN" gateway stop >/dev/null 2>&1 || true
  rm -f .mukuro/gateway.pid .mukuro/gateway.sock .mukuro/gateway-state.json .mukuro/gateway.token || true
}

echo "[e2e] build native binary"
moon build cmd/main --target native >/dev/null

cleanup

echo "[e2e] start daemon"
START_OUT="$("$BIN" gateway start --daemon)"
echo "$START_OUT"
echo "$START_OUT" | rg "Gateway daemon started in background" >/dev/null

echo "[e2e] reject duplicate start"
DUP_OUT="$("$BIN" gateway start --daemon || true)"
echo "$DUP_OUT"
echo "$DUP_OUT" | rg "already running" >/dev/null

echo "[e2e] status json"
STATUS_JSON="$("$BIN" gateway status --json)"
echo "$STATUS_JSON"
echo "$STATUS_JSON" | rg '"mode":"daemon"' >/dev/null
echo "$STATUS_JSON" | rg '"state":"running"' >/dev/null
echo "$STATUS_JSON" | rg '"ipc":"connected"' >/dev/null

echo "[e2e] auth failure by token mismatch"
echo "0" > .mukuro/gateway.token
AUTH_FAIL_OUT="$("$BIN" gateway status 2>&1 || true)"
echo "$AUTH_FAIL_OUT"
echo "$AUTH_FAIL_OUT" | rg "Daemon IPC authentication failed" >/dev/null

echo "[e2e] snapshot exists"
test -f .mukuro/gateway-state.json
cat .mukuro/gateway-state.json

echo "[e2e] stop daemon"
STOP_OUT="$("$BIN" gateway stop)"
echo "$STOP_OUT"
if ! echo "$STOP_OUT" | rg "(Stop request sent to gateway daemon via IPC|Stop signal sent to gateway daemon)" >/dev/null; then
  echo "[e2e] unexpected stop output"
  exit 1
fi

echo "[e2e] status after stop"
STATUS_AFTER="$("$BIN" gateway status --json)"
echo "$STATUS_AFTER"
echo "$STATUS_AFTER" | rg '"mode":"in-process"' >/dev/null
echo "$STATUS_AFTER" | rg '"state":"stopped"' >/dev/null

cleanup
echo "[e2e] PASS"
