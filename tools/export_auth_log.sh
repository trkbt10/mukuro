#!/usr/bin/env bash
set -euo pipefail

INPUT_PATH="${1:-.mukuro/gateway-auth.log}"
OUT_DIR="${2:-.mukuro/auth-export}"
SINCE_SECONDS="${SINCE_SECONDS:-0}"

mkdir -p "$OUT_DIR"

NDJSON_OUT="$OUT_DIR/auth-log.ndjson"
CSV_OUT="$OUT_DIR/auth-log.csv"

python3 - "$INPUT_PATH" "$NDJSON_OUT" "$CSV_OUT" "$SINCE_SECONDS" <<'PY'
import csv
import json
import sys
import time
from pathlib import Path

input_path = Path(sys.argv[1])
ndjson_out = Path(sys.argv[2])
csv_out = Path(sys.argv[3])
since_seconds = int(sys.argv[4] or "0")
cutoff = int(time.time()) - since_seconds if since_seconds > 0 else 0

rows = []
if input_path.exists():
    for raw in input_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts = int(obj.get("ts", 0) or 0)
        if cutoff and ts < cutoff:
            continue
        rows.append(obj)

with ndjson_out.open("w", encoding="utf-8") as f:
    for row in rows:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")

fieldnames = [
    "ts",
    "event",
    "source",
    "client_id",
    "session_id",
    "reason",
    "value",
    "token_age_sec",
    "blocked_until",
]
with csv_out.open("w", encoding="utf-8", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for row in rows:
        writer.writerow({k: row.get(k, "") for k in fieldnames})

print(f"exported rows={len(rows)}")
print(f"ndjson={ndjson_out}")
print(f"csv={csv_out}")
PY
