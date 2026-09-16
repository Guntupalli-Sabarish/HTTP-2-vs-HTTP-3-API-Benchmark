#!/bin/bash
# verify-checkpoint13.sh
# Standalone preflight verification for Checkpoint 13 benchmark rigor.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

CADDY="http-2-vs-http-3-api-benchmark-caddy-1"
SCENARIOS=("0 0" "50 0" "50 1" "100 3" "200 5")

require_file() {
  local f=$1
  if [ ! -f "$f" ]; then
    echo "FAIL: missing file $f"
    exit 1
  fi
}

echo "=== Checkpoint 13 verification ==="

require_file "benchmark/scripts/run-full.sh"
require_file "benchmark/scripts/run-full.ps1"
require_file "benchmark/scripts/parse-v2.js"
require_file "benchmark/scripts/generate-report-v2.js"
require_file "benchmark/scripts/k6-cold.js"
require_file "benchmark/scripts/k6-benchmark.js"

if ! docker ps --format '{{.Names}}' | grep -q "^${CADDY}$"; then
  echo "FAIL: caddy container not running ($CADDY)."
  echo "Run: docker compose up -d"
  exit 1
fi

echo "1) Protocol verification"
bash benchmark/scripts/verify-http2.sh >/dev/null
bash benchmark/scripts/verify-http3.sh >/dev/null
echo "   PASS"

echo "2) Network scenario verification"
for s in "${SCENARIOS[@]}"; do
  delay=$(echo "$s" | awk '{print $1}')
  loss=$(echo "$s" | awk '{print $2}')
  bash benchmark/scripts/network-conditions.sh apply "$delay" "$loss" >/dev/null
  out=$(bash benchmark/scripts/network-conditions.sh verify)

  if [ "$delay" -eq 0 ] && [ "$loss" -eq 0 ]; then
    if echo "$out" | grep -qi "netem"; then
      echo "FAIL: baseline scenario unexpectedly still has netem rule"
      exit 1
    fi
  else
    if ! echo "$out" | grep -q "delay ${delay}ms"; then
      echo "FAIL: missing delay ${delay}ms in tc output"
      echo "$out"
      exit 1
    fi
    if ! echo "$out" | grep -q "loss ${loss}%"; then
      echo "FAIL: missing loss ${loss}% in tc output"
      echo "$out"
      exit 1
    fi
  fi
  echo "   PASS scenario ${delay}ms/${loss}%"
done
bash benchmark/scripts/network-conditions.sh remove >/dev/null

echo "3) Script invariants verification"
if ! rg -q "WARM_REPS=5" benchmark/scripts/run-full.sh; then
  echo "FAIL: run-full.sh does not enforce 5 repetitions"
  exit 1
fi
if ! rg -q "p\(99\)" benchmark/scripts/run-full.sh; then
  echo "FAIL: run-full.sh does not request p99"
  exit 1
fi
if ! rg -q "scenE_200ms_5loss" benchmark/scripts/run-full.sh; then
  echo "FAIL: run-full.sh does not define all five scenarios"
  exit 1
fi
if ! rg -q "p99" benchmark/scripts/parse-v2.js; then
  echo "FAIL: parse-v2.js does not parse P99"
  exit 1
fi
if ! rg -q "benchmark/results/raw-v2|raw-v2" README.md benchmark/README.md docs/methodology.md; then
  echo "FAIL: raw-v2 output path not documented"
  exit 1
fi

echo "All Checkpoint 13 verification checks passed."
