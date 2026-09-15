$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host "Starting Full HTTP/2 vs HTTP/3 Benchmark"
Write-Host "========================================="

# 1. Ensure Caddy is fresh and running
Write-Host "Restarting Caddy..."
docker compose restart caddy
Start-Sleep -Seconds 5

# 2. Make sure no tc rules are active
Write-Host "Removing any existing network impairment..."
docker exec -u root http-2-vs-http-3-api-benchmark-caddy-1 sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"

# 3. Run Baseline Benchmark
Write-Host "Starting Baseline Benchmark..."
.\benchmark\scripts\baseline.ps1

# 4. Apply Network Impairment (50ms latency, 5% loss)
Write-Host "Applying Network Impairment (50ms latency, 5% loss)..."
docker exec -u root http-2-vs-http-3-api-benchmark-caddy-1 sh -c "tc qdisc add dev eth0 root netem delay 50ms loss 5%"

# 5. Run Degraded Benchmark
Write-Host "Starting Degraded Benchmark..."
.\benchmark\scripts\degraded.ps1

# 6. Remove Network Impairment
Write-Host "Cleaning up Network Impairment..."
docker exec -u root http-2-vs-http-3-api-benchmark-caddy-1 sh -c "tc qdisc del dev eth0 root"

# 7. Parse Results
Write-Host "Parsing Results..."
node benchmark\scripts\parse.js > benchmark\results\summary.md

Write-Host "========================================="
Write-Host "Full Benchmark Complete!"
Write-Host "========================================="
