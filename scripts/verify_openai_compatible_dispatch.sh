#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

BIN="_build/native/debug/build/cmd/main/main.exe"
BASE_CFG=".mukuro/config.json"

if [[ ! -f "$BASE_CFG" ]]; then
  echo "[verify] missing $BASE_CFG"
  exit 1
fi

if [[ ! -x "$BIN" ]]; then
  echo "[verify] building native binary"
  moon build cmd/main --target native >/dev/null
fi

TMP_FALSE="$(mktemp /tmp/mukuro-config-false.XXXXXX.json)"
TMP_TRUE="$(mktemp /tmp/mukuro-config-true.XXXXXX.json)"

cleanup() {
  rm -f "$TMP_FALSE" "$TMP_TRUE"
}
trap cleanup EXIT

jq '.use_responses_api = false' "$BASE_CFG" >"$TMP_FALSE"
jq '.use_responses_api = true' "$BASE_CFG" >"$TMP_TRUE"

run_case() {
  local cfg="$1"
  local label="$2"
  local port="$3"
  local token
  token="$(jq -r '.gateway.auth_token // empty' "$cfg")"

  ("$BIN" gateway start --control-api --config "$cfg" --host 127.0.0.1 --port "$port" >/tmp/mukuro-verify-"$label".log 2>&1) &
  local server_pid=$!

  local health_code=""
  for _ in $(seq 1 80); do
    if [[ -n "$token" ]]; then
      health_code="$(curl -s -o /tmp/mukuro-verify-"$label"-health.json -w "%{http_code}" -H "Authorization: Bearer $token" "http://127.0.0.1:$port/health/live" || true)"
    else
      health_code="$(curl -s -o /tmp/mukuro-verify-"$label"-health.json -w "%{http_code}" "http://127.0.0.1:$port/health/live" || true)"
    fi
    [[ "$health_code" == "200" ]] && break
    sleep 0.2
  done

  local dispatch_code
  if [[ -n "$token" ]]; then
    dispatch_code="$(curl -s -o /tmp/mukuro-verify-"$label"-dispatch.json -w "%{http_code}" \
      -H "Authorization: Bearer $token" \
      -H "x-mukuro-role: operator" \
      -H "Content-Type: application/json" \
      -X POST "http://127.0.0.1:$port/dispatch" \
      --data '{"channel":"test","chat_id":"verify","sender_id":"u1","content":"Explain why fast inference is critical for reasoning models"}' || true)"
  else
    dispatch_code="$(curl -s -o /tmp/mukuro-verify-"$label"-dispatch.json -w "%{http_code}" \
      -H "x-mukuro-role: operator" \
      -H "Content-Type: application/json" \
      -X POST "http://127.0.0.1:$port/dispatch" \
      --data '{"channel":"test","chat_id":"verify","sender_id":"u1","content":"Explain why fast inference is critical for reasoning models"}' || true)"
  fi

  echo "[verify] $label health=$health_code dispatch=$dispatch_code body=$(cat /tmp/mukuro-verify-"$label"-dispatch.json)"

  kill "$server_pid" >/dev/null 2>&1 || true
  wait "$server_pid" 2>/dev/null || true
}

run_case "$TMP_FALSE" "responses-false" 18100
run_case "$TMP_TRUE" "responses-true" 18101

