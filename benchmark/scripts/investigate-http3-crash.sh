#!/bin/bash
# investigate-http3-crash.sh
# Reproduces and inventories xk6-http3 instability under degraded concurrency.

set -u -o pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

CADDY="http-2-vs-http-3-api-benchmark-caddy-1"
OUT_DIR="benchmark/results/crash-investigation"
RAW_DIR="$OUT_DIR/raw"
SUMMARY_CSV="$OUT_DIR/http3-crash-investigation.csv"
ENDPOINT="${ENDPOINT:-/api/products?limit=1000}"
BASE_URL="https://caddy:8443"
DURATION="${DURATION:-10s}"
CONCURRENCIES=(${CONCURRENCIES:-10 25 50 100})
SCENARIOS=("scenA_0ms_0loss 0 0" "scenC_50ms_1loss 50 1" "scenD_100ms_3loss 100 3" "scenE_200ms_5loss 200 5")

mkdir -p "$RAW_DIR"

if ! docker ps --format '{{.Names}}' | grep -q "^${CADDY}$"; then
  echo "ERROR: caddy container '$CADDY' is not running."
  echo "Run: docker compose up -d"
  exit 1
fi

if ! docker image ls custom-k6 --format '{{.Repository}}' | grep -q "^custom-k6$"; then
  echo "ERROR: custom-k6 image not found."
  echo "Build with: docker build -t custom-k6 -f benchmark/Dockerfile.k6 ."
  exit 1
fi

echo "Scenario,DelayMs,LossPct,Concurrency,ExitCode,Status,CrashSignature,Requests,ReportedRPS,SourceFile" > "$SUMMARY_CSV"

echo "=== HTTP/3 crash investigation (xk6-http3) ==="
for s in "${SCENARIOS[@]}"; do
  read -r scen delay loss <<< "$s"
  echo "Scenario $scen (${delay}ms/${loss}%)"
  bash benchmark/scripts/network-conditions.sh apply "$delay" "$loss" >/dev/null
  sleep 2

  for c in "${CONCURRENCIES[@]}"; do
    out_file="$RAW_DIR/${scen}_HTTP3_api_products_limit_1000_c${c}_investigation.txt"
    run_status="success"

    set +e
    docker run --rm \
      --network http-2-vs-http-3-api-benchmark_default \
      -v "$(pwd)/benchmark:/benchmark" \
      -e PROTOCOL="h3" \
      -e TARGET_URL="${BASE_URL}${ENDPOINT}" \
      -e CONN_TYPE="warm" \
      custom-k6 run \
      --vus "$c" \
      --duration "$DURATION" \
      "--summary-trend-stats=avg,min,med,max,p(90),p(95),p(99)" \
      /benchmark/scripts/k6-benchmark.js > "$out_file" 2>&1
    exit_code=$?
    set -e

    crash_sig="no"
    if rg -qi "panic|sigsegv|segmentation fault|invalid memory address|nil pointer" "$out_file"; then
      crash_sig="yes"
      run_status="tool_crash"
    elif [ "$exit_code" -ne 0 ]; then
      run_status="tool_error"
    fi

    req_line=$(rg "http3_reqs" "$out_file" -n --output-mode content -m 1 2>/dev/null || true)
    requests="0"
    reported_rps="0"
    if [ -n "$req_line" ]; then
      requests=$(echo "$req_line" | sed -E 's/.*: *([0-9,]+).*/\1/' | tr -d ',' || echo "0")
      reported_rps=$(echo "$req_line" | sed -E 's/.* ([0-9]+\.?[0-9]*)\/s.*/\1/' || echo "0")
    fi

    echo "  c=$c -> ${run_status} (exit=$exit_code, crash=$crash_sig)"
    echo "$scen,$delay,$loss,$c,$exit_code,$run_status,$crash_sig,$requests,$reported_rps,$(basename "$out_file")" >> "$SUMMARY_CSV"
  done

done

bash benchmark/scripts/network-conditions.sh remove >/dev/null

python - <<'PY'
import csv
from pathlib import Path
p = Path('benchmark/results/crash-investigation/http3-crash-investigation.csv')
rows = list(csv.DictReader(p.open()))
print('\n=== Crash investigation summary ===')
for scenario in sorted({r['Scenario'] for r in rows}):
    srows = [r for r in rows if r['Scenario']==scenario]
    stable = [int(r['Concurrency']) for r in srows if r['Status']=='success']
    crashed = [int(r['Concurrency']) for r in srows if r['Status'] in ('tool_crash','tool_error')]
    safe_max = max(stable) if stable else 0
    print(f"{scenario}: safe_max_concurrency={safe_max}; unstable_at={crashed if crashed else 'none'}")

needs_fallback = any(r['Status'] in ('tool_crash','tool_error') for r in rows if int(r['LossPct']) > 0)
print('\nRecommendation:')
if needs_fallback:
    print('- xk6-http3 is unstable in degraded scenarios at tested concurrency levels.')
    print('- Use benchmark/scripts/run-fallback-h2load.sh for those unstable scenario/concurrency pairs.')
else:
    print('- No instability observed in this run; xk6-http3 remained stable for tested settings.')
PY

echo "\nWrote: $SUMMARY_CSV"
