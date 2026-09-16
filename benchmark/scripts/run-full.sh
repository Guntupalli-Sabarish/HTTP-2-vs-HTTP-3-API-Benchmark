#!/bin/bash
# run-full.sh — Full HTTP/2 vs HTTP/3 benchmark (Linux/macOS equivalent of run-full.ps1)
set -e

# ---- Configuration --------------------------------------------------
URLS=("/api/health" "/api/products?limit=20" "/api/products?limit=1000")
CONCURRENCIES=(1 10 50 100)
PROTOCOLS=("h2" "h3")
DURATION="10s"
BASE_URL="https://caddy:8443"
OUT_DIR="benchmark/results/raw-v2"
CADDY="http-2-vs-http-3-api-benchmark-caddy-1"
TREND_STATS="avg,min,med,max,p(90),p(95),p(99)"
WARM_REPS=5
H3_MAX_VUS_LOSSY=25

# Scenarios: "name delay_ms loss_pct"
declare -a SCENARIOS=(
    "scenA_0ms_0loss   0   0"
    "scenB_50ms_0loss  50  0"
    "scenC_50ms_1loss  50  1"
    "scenD_100ms_3loss 100 3"
    "scenE_200ms_5loss 200 5"
)

# ---- Helpers --------------------------------------------------------
apply_network() {
    local delay=$1 loss=$2
    docker exec -u root "$CADDY" sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"
    if [ "$delay" -gt 0 ] || [ "$loss" -gt 0 ]; then
        docker exec -u root "$CADDY" sh -c "tc qdisc add dev eth0 root netem delay ${delay}ms loss ${loss}%"
    fi
    echo "  tc: $(docker exec -u root "$CADDY" tc qdisc show dev eth0)"
}

run_k6() {
    local script=$1 proto=$2 url=$3 vus=$4 conn_type=$5 out_file=$6
    local pwd_path; pwd_path=$(pwd)
    local mount="${pwd_path}/benchmark:/benchmark"

    if [ "$conn_type" = "cold" ]; then
        docker run --rm \
            --network http-2-vs-http-3-api-benchmark_default \
            -v "$mount" \
            -e PROTOCOL="$proto" \
            -e TARGET_URL="$url" \
            -e CONN_TYPE=cold \
            custom-k6 run \
                --vus "$vus" \
                --iterations "$vus" \
                "--summary-trend-stats=$TREND_STATS" \
                "$script" > "$out_file" 2>&1
    else
        docker run --rm \
            --network http-2-vs-http-3-api-benchmark_default \
            -v "$mount" \
            -e PROTOCOL="$proto" \
            -e TARGET_URL="$url" \
            -e CONN_TYPE=warm \
            custom-k6 run \
                --vus "$vus" \
                --duration "$DURATION" \
                "--summary-trend-stats=$TREND_STATS" \
                "$script" > "$out_file" 2>&1
    fi
}

# ---- Setup ----------------------------------------------------------
echo "================================================================"
echo " HTTP/2 vs HTTP/3 Full Benchmark — Checkpoint 13"
echo "================================================================"

mkdir -p "$OUT_DIR"

docker exec -u root "$CADDY" sh -c \
    "which tc >/dev/null 2>&1 || apk add --no-cache iproute2 iproute2-tc >/dev/null 2>&1"

if ! docker image ls custom-k6 --format "{{.Repository}}" | grep -q "custom-k6"; then
    echo "ERROR: custom-k6 image not found. Build it first:"
    echo "  docker build -t custom-k6 -f benchmark/Dockerfile.k6 ."
    exit 1
fi

# ---- Main loop ------------------------------------------------------
for scenario_str in "${SCENARIOS[@]}"; do
    read -r SCEN_NAME DELAY_MS LOSS_PCT <<< "$scenario_str"
    IS_LOSSY=false
    [ "$LOSS_PCT" -gt 0 ] && IS_LOSSY=true

    echo ""
    echo "================================================================"
    echo " Scenario: $SCEN_NAME  (delay=${DELAY_MS}ms  loss=${LOSS_PCT}%)"
    echo "================================================================"

    apply_network "$DELAY_MS" "$LOSS_PCT"
    sleep 3

    for PROTO in "${PROTOCOLS[@]}"; do
        PROTO_NAME=$( [ "$PROTO" = "h2" ] && echo "HTTP2" || echo "HTTP3" )

        for ENDPOINT in "${URLS[@]}"; do
            SAFE_EP=$(echo "$ENDPOINT" | sed 's|/|_|g; s|?|_|g; s|=|_|g')
            TARGET="${BASE_URL}${ENDPOINT}"

            for C in "${CONCURRENCIES[@]}"; do
                # Cap HTTP/3 VUs on lossy scenarios
                if [ "$PROTO" = "h3" ] && [ "$IS_LOSSY" = "true" ] && [ "$C" -gt "$H3_MAX_VUS_LOSSY" ]; then
                    echo "  [SKIP] ${PROTO_NAME} c=$C — SIGSEGV cap on lossy network"
                    SKIP_FILE="${OUT_DIR}/${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_r0_warm.txt"
                    echo "SKIPPED: xk6-http3 SIGSEGV cap — concurrency $C > $H3_MAX_VUS_LOSSY on lossy network" > "$SKIP_FILE"
                    continue
                fi

                # Warm: 1 warmup + WARM_REPS kept
                echo "  [WARM] ${PROTO_NAME} | ${ENDPOINT} | c=${C}"
                WARMUP_FILE="${OUT_DIR}/${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_warmup_warm.txt"
                run_k6 "/benchmark/scripts/k6-benchmark.js" "$PROTO" "$TARGET" "$C" "warm" "$WARMUP_FILE"
                sleep 2

                for (( R=1; R<=WARM_REPS; R++ )); do
                    echo "    Run $R/$WARM_REPS..."
                    OUT_FILE="${OUT_DIR}/${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_r${R}_warm.txt"
                    run_k6 "/benchmark/scripts/k6-benchmark.js" "$PROTO" "$TARGET" "$C" "warm" "$OUT_FILE"
                    sleep 2
                done

                # Cold: single run
                echo "  [COLD] ${PROTO_NAME} | ${ENDPOINT} | c=${C}"
                COLD_FILE="${OUT_DIR}/${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_r1_cold.txt"
                run_k6 "/benchmark/scripts/k6-cold.js" "$PROTO" "$TARGET" "$C" "cold" "$COLD_FILE"
                sleep 2
            done
        done
    done
done

# ---- Cleanup --------------------------------------------------------
echo ""
echo "Removing all network impairment..."
docker exec -u root "$CADDY" sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"

echo ""
echo "================================================================"
echo " Full benchmark complete! Results in: $OUT_DIR"
echo " Run: node benchmark/scripts/parse-v2.js > benchmark/results/full-results-v2.csv"
echo "================================================================"
