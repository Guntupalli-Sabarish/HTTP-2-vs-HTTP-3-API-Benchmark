#!/bin/bash
set -e

echo "========================================="
echo "Starting Checkpoint 13 Benchmark Suite"
echo "========================================="

echo "Restarting Caddy..."
docker compose restart caddy
sleep 5

echo "Running full benchmark matrix..."
bash ./benchmark/scripts/run-full.sh

echo "Parsing raw-v2 results..."
node benchmark/scripts/parse-v2.js > benchmark/results/full-results-v2.csv

echo "Generating aggregate report outputs..."
node benchmark/scripts/generate-report-v2.js

echo "========================================="
echo "Checkpoint 13 benchmark complete"
echo "Per-run: benchmark/results/full-results-v2.csv"
echo "Aggregate: benchmark/results/full-results-v2-aggregated.csv"
echo "========================================="
