$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host "Starting Checkpoint 13 Benchmark Suite"
Write-Host "========================================="

Write-Host "Restarting Caddy..."
docker compose restart caddy
Start-Sleep -Seconds 5

Write-Host "Running full benchmark matrix..."
.\benchmark\scripts\run-full.ps1

Write-Host "Parsing raw-v2 results..."
node benchmark\scripts\parse-v2.js > benchmark\results\full-results-v2.csv

Write-Host "Generating aggregate report outputs..."
node benchmark\scripts\generate-report-v2.js

Write-Host "========================================="
Write-Host "Checkpoint 13 benchmark complete"
Write-Host "Per-run: benchmark/results/full-results-v2.csv"
Write-Host "Aggregate: benchmark/results/full-results-v2-aggregated.csv"
Write-Host "========================================="
