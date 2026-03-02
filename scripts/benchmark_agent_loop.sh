#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUNS="${RUNS:-7}"
ITERATIONS="${ITERATIONS:-20000}"
WARMUP="${WARMUP:-1000}"
CONTENT_SIZE="${CONTENT_SIZE:-64}"
RICH_METADATA="${RICH_METADATA:-0}"

echo "[bench] build cmd/bench (native)"
moon build cmd/bench --target native >/dev/null

BIN_PATH="$(
  find "$ROOT_DIR/_build/native" -type f -name "bench.exe" -perm -u+x |
    grep -v '\.dSYM/' |
    head -n 1
)"
if [[ -z "${BIN_PATH}" ]]; then
  echo "[bench] ERROR: bench.exe not found"
  exit 1
fi

echo "[bench] binary: $BIN_PATH"
echo "[bench] runs=$RUNS iterations=$ITERATIONS warmup=$WARMUP content_size=$CONTENT_SIZE rich_metadata=$RICH_METADATA"

python3 - "$BIN_PATH" "$RUNS" "$ITERATIONS" "$WARMUP" "$CONTENT_SIZE" "$RICH_METADATA" <<'PY'
import statistics
import subprocess
import sys
import time

bin_path = sys.argv[1]
runs = int(sys.argv[2])
iterations = int(sys.argv[3])
warmup = int(sys.argv[4])
content_size = int(sys.argv[5])
rich_metadata = sys.argv[6]

def measure(mode: str):
    times = []
    prime_cmd = [
        bin_path,
        "--mode", mode,
        "--iterations", str(iterations),
        "--warmup", str(warmup),
        "--content-size", str(content_size),
        "--rich-metadata", rich_metadata,
    ]
    subprocess.run(prime_cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(runs):
        cmd = [
            bin_path,
            "--mode", mode,
            "--iterations", str(iterations),
            "--warmup", str(warmup),
            "--content-size", str(content_size),
            "--rich-metadata", rich_metadata,
        ]
        t0 = time.perf_counter()
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elapsed = time.perf_counter() - t0
        times.append(elapsed)
    return times

def summarize(label: str, times):
    med = statistics.median(times)
    avg = sum(times) / len(times)
    ips_med = iterations / med if med > 0 else 0.0
    ips_avg = iterations / avg if avg > 0 else 0.0
    print(f"{label:16s} median={med:.6f}s avg={avg:.6f}s iter/s(median)={ips_med:,.1f} iter/s(avg)={ips_avg:,.1f}")
    print(f"{label:16s} runs={[round(x, 6) for x in times]}")

isolated = measure("isolated")
single = measure("single")

print("\nrun_agent_loop benchmark (native, deterministic mock model)")
summarize("isolated-session", isolated)
summarize("single-session", single)
PY
