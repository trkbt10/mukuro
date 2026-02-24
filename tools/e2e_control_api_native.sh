#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

BIN="_build/native/debug/build/cmd/main/main.exe"
HOST="127.0.0.1"
PORT="18080"
BASE_URL="http://${HOST}:${PORT}"
TOKEN="e2e-control-token"
CONFIG_PATH=".mukuro/e2e-control-api.json"

cleanup() {
  "$BIN" gateway stop >/dev/null 2>&1 || true
  rm -f \
    .mukuro/gateway.pid \
    .mukuro/gateway.sock \
    .mukuro/gateway-state.json \
    .mukuro/gateway.token \
    .mukuro/daemon-startup.json \
    "$CONFIG_PATH" || true
}

require_body_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg "$pattern" "$file" >/dev/null; then
    echo "[e2e-control] expected pattern not found: $pattern"
    cat "$file"
    exit 1
  fi
}

request() {
  local method="$1"
  local path="$2"
  local output_file="$3"
  shift 3
  curl -sS -o "$output_file" -w "%{http_code}" -X "$method" "$BASE_URL$path" "$@"
}

wait_until_ready() {
  local tmp_file
  tmp_file="$(mktemp)"
  for _ in $(seq 1 60); do
    local code
    code="$(request GET /health/live "$tmp_file" -H "Authorization: Bearer $TOKEN")"
    if [[ "$code" == "200" ]]; then
      if rg '"live":true' "$tmp_file" >/dev/null; then
        rm -f "$tmp_file"
        return 0
      fi
    fi
    sleep 0.2
  done
  echo "[e2e-control] control-api did not become ready"
  cat "$tmp_file"
  rm -f "$tmp_file"
  return 1
}

trap cleanup EXIT

echo "[e2e-control] build native binary"
moon build cmd/main --target native >/dev/null

cleanup
mkdir -p .mukuro
cat >"$CONFIG_PATH" <<JSON
{
  "gateway": {
    "host": "$HOST",
    "port": $PORT,
    "auth_token": "$TOKEN"
  }
}
JSON

echo "[e2e-control] start daemon with control-api"
START_OUT="$("$BIN" gateway start --daemon --control-api --config "$CONFIG_PATH" --host "$HOST" --port "$PORT")"
echo "$START_OUT"
echo "$START_OUT" | rg "Gateway daemon started in background" >/dev/null

wait_until_ready

tmp_body="$(mktemp)"
echo "[e2e-control] unauthorized status request"
code="$(request GET /status "$tmp_body")"
[[ "$code" == "401" ]]
require_body_contains "$tmp_body" '"unauthorized"'

echo "[e2e-control] authorized status request"
code="$(request GET /status "$tmp_body" -H "Authorization: Bearer $TOKEN")"
[[ "$code" == "200" ]]
require_body_contains "$tmp_body" '"state":"running"'

echo "[e2e-control] viewer role cannot dispatch outbound"
code="$(request POST /dispatch/outbound "$tmp_body" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-mukuro-role: viewer" \
  -H "Content-Type: application/json" \
  --data '{"channel":"test","chat_id":"chat-1","content":"hello"}')"
[[ "$code" == "403" ]]
require_body_contains "$tmp_body" '"forbidden"'

echo "[e2e-control] operator role can dispatch outbound"
code="$(request POST /dispatch/outbound "$tmp_body" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-mukuro-role: operator" \
  -H "Content-Type: application/json" \
  --data '{"channel":"test","chat_id":"chat-1","content":"hello"}')"
[[ "$code" == "200" ]]
require_body_contains "$tmp_body" '"ok":true'

echo "[e2e-control] stop daemon"
STOP_OUT="$("$BIN" gateway stop)"
echo "$STOP_OUT"
if ! echo "$STOP_OUT" | rg "(Stop request sent to gateway daemon via IPC|Stop signal sent to gateway daemon)" >/dev/null; then
  echo "[e2e-control] unexpected stop output"
  exit 1
fi

rm -f "$tmp_body"
echo "[e2e-control] PASS"
