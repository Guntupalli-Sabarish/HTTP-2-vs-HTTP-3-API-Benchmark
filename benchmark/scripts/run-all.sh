#!/bin/bash
set -e

echo "========================================="
echo "Starting Full HTTP/2 vs HTTP/3 Benchmark"
echo "========================================="

# 1. Ensure Caddy is fresh and running
echo "Restarting Caddy..."
docker compose restart caddy
sleep 5

# 2. Make sure no tc rules are active
echo "Removing any existing network impairment..."
docker exec -u root http-2-vs-http-3-api-benchmark-caddy-1 sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"

# 3. Run Baseline Benchmark
echo "Starting Baseline Benchmark..."
bash ./benchmark/scripts/baseline.sh

# 4. Apply Network Impairment (50ms latency, 5% loss)
echo "Applying Network Impairment (50ms latency, 5% loss)..."
docker exec -u root http-2-vs-http-3-api-benchmark-caddy-1 sh -c "tc qdisc add dev eth0 root netem delay 50ms loss 5%"

# 5. Run Degraded Benchmark
echo "Starting Degraded Benchmark..."
bash ./benchmark/scripts/degraded.sh

# 6. Remove Network Impairment
echo "Cleaning up Network Impairment..."
docker exec -u root http-2-vs-http-3-api-benchmark-caddy-1 sh -c "tc qdisc del dev eth0 root"

# 7. Parse Results
echo "Parsing Results..."
node benchmark/scripts/parse.js > benchmark/results/full-results.csv

echo "========================================="
echo "Full Benchmark Complete! Check benchmark/results/full-results.csv"
echo "========================================="
