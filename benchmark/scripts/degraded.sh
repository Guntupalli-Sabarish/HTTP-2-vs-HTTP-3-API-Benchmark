#!/bin/bash
# baseline.sh - Runs the baseline HTTP/2 and HTTP/3 benchmarks using k6

# Configuration
URLS=("/api/health" "/api/products?limit=20" "/api/products?limit=1000")
CONCURRENCIES=(1 10 50 100)
PROTOCOLS=("h2" "h3")
DURATION="10s"
BASE_URL="https://caddy:8443"
OUT_DIR="./benchmark/results/raw"

mkdir -p "$OUT_DIR"

echo "Starting Degraded Benchmark with k6 (50ms latency, 5% loss)..."

for PROTO in "${PROTOCOLS[@]}"; do
    if [ "$PROTO" = "h2" ]; then
        PROTO_NAME="HTTP2"
    else
        PROTO_NAME="HTTP3"
    fi

    for ENDPOINT in "${URLS[@]}"; do
        # Safe filename conversion
        SAFE_ENDPOINT=$(echo "$ENDPOINT" | sed 's|/|_|g' | sed 's|?|_|g' | sed 's|=|_|g')
        
        for C in "${CONCURRENCIES[@]}"; do
            OUT_FILE="${OUT_DIR}/degraded_${PROTO_NAME}_${SAFE_ENDPOINT}_c${C}.txt"
            
            echo "Running $PROTO_NAME test against $ENDPOINT with concurrency $C..."
            
            # Run docker k6
            docker run --rm \
                --network http-2-vs-http-3-api-benchmark_default \
                -v "$(pwd)/benchmark:/benchmark" \
                -e PROTOCOL="$PROTO" \
                -e TARGET_URL="${BASE_URL}${ENDPOINT}" \
                custom-k6 run --vus "$C" --duration "$DURATION" /benchmark/scripts/k6-baseline.js > "$OUT_FILE" 2>&1
            
            # Brief pause between tests
            sleep 2
        done
    done
done

echo "Benchmark complete! Results saved in $OUT_DIR"
