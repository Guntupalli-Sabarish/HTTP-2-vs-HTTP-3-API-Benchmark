#!/bin/bash
# run-fallback-h2load.sh
# Alternative benchmark path when xk6-http3 is unstable.
# Uses h2load with explicit HTTP/2 and HTTP/3 ALPN selection.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

IMAGE="${H2LOAD_IMAGE:-ghcr.io/nghttp2/nghttp2:latest}"
OUT_DIR="benchmark/results/fallback-h2load"
RAW_DIR="$OUT_DIR/raw"
CSV="$OUT_DIR/fallback-h2load-results.csv"
CADDY="http-2-vs-http-3-api-benchmark-caddy-1"
BASE_URL="https://caddy:8443"
ENDPOINT="${ENDPOINT:-/api/products?limit=1000}"
DURATION_SECONDS="${DURATION_SECONDS:-10}"
REPS="${REPS:-5}"
THREADS="${THREADS:-2}"
CONCURRENCIES=(${CONCURRENCIES:-50 100})
SCENARIOS=("scenC_50ms_1loss 50 1" "scenD_100ms_3loss 100 3" "scenE_200ms_5loss 200 5")

mkdir -p "$RAW_DIR"

if ! docker ps --format '{{.Names}}' | grep -q "^${CADDY}$"; then
  echo "ERROR: caddy container '$CADDY' is not running."
  echo "Run: docker compose up -d"
  exit 1
fi

echo "Checking h2load HTTP/3 support in $IMAGE ..."
if ! docker run --rm "$IMAGE" sh -lc "h2load --help" | rg -q "--h3"; then
  echo "ERROR: selected h2load image does not expose --h3 support."
  echo "Set H2LOAD_IMAGE to an HTTP/3-capable build and retry."
  exit 1
fi

echo "Scenario,DelayMs,LossPct,Protocol,Concurrency,Run,Requests,DurationSeconds,RPS,P50Ms,P90Ms,P95Ms,P99Ms,MaxMs,Status,SourceRaw,SourceLog" > "$CSV"

run_h2load() {
  local proto=$1   # h2 or h3
  local conc=$2
  local raw_file=$3
  local log_file=$4

  local proto_flag="--alpn-list=h2"
  [ "$proto" = "h3" ] && proto_flag="--h3"

  set +e
  docker run --rm \
    --network http-2-vs-http-3-api-benchmark_default \
    -v "$(pwd)/benchmark:/benchmark" \
    "$IMAGE" sh -lc \
    "h2load $proto_flag -c $conc -t $THREADS -D $DURATION_SECONDS --warm-up-time=1 --log-file=/benchmark/results/fallback-h2load/$(basename "$log_file") ${BASE_URL}${ENDPOINT}" > "$raw_file" 2>&1
  exit_code=$?
  set -e

  echo "$exit_code"
}

percentiles_from_log() {
  local log_file=$1
  python - "$log_file" <<'PY'
import math,sys
p = sys.argv[1]
vals = []
with open(p, 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        parts=line.strip().split('\t')
        if len(parts) < 3:
            continue
        try:
            vals.append(float(parts[2]) / 1000.0)  # us -> ms
        except ValueError:
            pass
if not vals:
    print('0,0,0,0,0,0,0')
    raise SystemExit
vals.sort()

def pct(v, p):
    if not v:
        return 0.0
    k=(len(v)-1)*(p/100.0)
    f=math.floor(k)
    c=math.ceil(k)
    if f==c:
        return v[int(k)]
    return v[f]*(c-k)+v[c]*(k-f)

count=len(vals)
p50=pct(vals,50)
p90=pct(vals,90)
p95=pct(vals,95)
p99=pct(vals,99)
mx=max(vals)
print(f"{count},{p50:.3f},{p90:.3f},{p95:.3f},{p99:.3f},{mx:.3f}")
PY
}

extract_rps() {
  local raw_file=$1
  local rps
  rps=$(rg "req/s" "$raw_file" -m 1 | sed -E 's/.* ([0-9]+\.?[0-9]*) req\/s.*/\1/' || true)
  echo "${rps:-0}"
}

echo "=== h2load fallback benchmark ==="
for s in "${SCENARIOS[@]}"; do
  read -r scen delay loss <<< "$s"
  echo "Scenario $scen (${delay}ms/${loss}%)"
  bash benchmark/scripts/network-conditions.sh apply "$delay" "$loss" >/dev/null
  sleep 2

  for conc in "${CONCURRENCIES[@]}"; do
    for proto in h2 h3; do
      for ((run=1; run<=REPS; run++)); do
        raw_file="$RAW_DIR/${scen}_${proto}_c${conc}_r${run}.txt"
        log_file="$RAW_DIR/${scen}_${proto}_c${conc}_r${run}.log"

        exit_code=$(run_h2load "$proto" "$conc" "$raw_file" "$log_file")
        status="success"
        if [ "$exit_code" -ne 0 ]; then
          status="tool_error"
        fi

        req_count=0; p50=0; p90=0; p95=0; p99=0; pmax=0
        if [ "$status" = "success" ] && [ -s "$log_file" ]; then
          metrics=$(percentiles_from_log "$log_file")
          IFS=',' read -r req_count p50 p90 p95 p99 pmax <<< "$metrics"
        fi

        rps=$(extract_rps "$raw_file")
        echo "  ${proto} c=${conc} run=${run} -> ${status}"
        echo "$scen,$delay,$loss,HTTP/${proto#h},$conc,$run,$req_count,$DURATION_SECONDS,$rps,$p50,$p90,$p95,$p99,$pmax,$status,$(basename "$raw_file"),$(basename "$log_file")" >> "$CSV"
      done
    done
  done
done

bash benchmark/scripts/network-conditions.sh remove >/dev/null

echo "Wrote fallback results: $CSV"
