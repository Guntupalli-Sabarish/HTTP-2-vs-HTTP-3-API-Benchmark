$ErrorActionPreference = "Continue"

# =====================================================================
# run-full.ps1 — Full HTTP/2 vs HTTP/3 benchmark (Checkpoint 13)
#
# Covers:
#   - 5 network scenarios (A–E)
#   - 3 endpoints × 4 concurrencies × 2 protocols
#   - 5 repeated runs per configuration (warm)
#   - 1 cold-connection run per configuration
#   - P99 via --summary-trend-stats
#   - HTTP/3 concurrency capped at 25 VUs for lossy scenarios
#     to avoid xk6-http3 SIGSEGV (stats.go:179 nil pointer bug)
#
# Results are saved to benchmark/results/raw-v2/
# Existing benchmark/results/raw/ is NOT modified.
# =====================================================================

# ---- Configuration --------------------------------------------------

$URLS          = @("/api/health", "/api/products?limit=20", "/api/products?limit=1000")
$CONCURRENCIES = @(1, 10, 50, 100)
$PROTOCOLS     = @("h2", "h3")
$DURATION      = "10s"
$BASE_URL      = "https://caddy:8443"
$OUT_DIR       = "benchmark\results\raw-v2"
$CADDY         = "http-2-vs-http-3-api-benchmark-caddy-1"
$TREND_STATS   = "avg,min,med,max,p(90),p(95),p(99)"
$WARM_REPS     = 5      # number of warm-connection repetitions to keep
$H3_MAX_VUS_LOSSY = 25  # cap HTTP/3 VUs when packet loss > 0 (avoids SIGSEGV)

# Network scenarios: @(name, delay_ms, loss_pct)
$SCENARIOS = @(
    @("scenA_0ms_0loss",   0,   0),
    @("scenB_50ms_0loss",  50,  0),
    @("scenC_50ms_1loss",  50,  1),
    @("scenD_100ms_3loss", 100, 3),
    @("scenE_200ms_5loss", 200, 5)
)

# ---- Helpers --------------------------------------------------------

function Invoke-TC {
    param([string]$cmd)
    docker exec -u root $CADDY sh -c $cmd
}

function Apply-Network {
    param([int]$DelayMs, [int]$LossPct)
    Invoke-TC "tc qdisc del dev eth0 root 2>/dev/null || true"
    if ($DelayMs -gt 0 -or $LossPct -gt 0) {
        Invoke-TC "tc qdisc add dev eth0 root netem delay ${DelayMs}ms loss ${LossPct}%"
    }
    $rule = docker exec -u root $CADDY tc qdisc show dev eth0
    Write-Host "  tc: $rule"
}

function Run-K6 {
    param(
        [string]$Script,
        [string]$Proto,
        [string]$Url,
        [int]$VUs,
        [string]$ConnType,
        [string]$OutFile
    )
    $PWD_PATH = (Get-Location).Path
    $MOUNT = "$PWD_PATH\benchmark:/benchmark"
    if ($ConnType -eq "cold") {
        # cold: vus iterations, no duration — each VU runs once
        docker run --rm `
            --network http-2-vs-http-3-api-benchmark_default `
            -v $MOUNT `
            -e PROTOCOL=$Proto `
            -e TARGET_URL=$Url `
            -e CONN_TYPE=cold `
            custom-k6 run `
                --vus $VUs `
                --iterations $VUs `
                "--summary-trend-stats=$TREND_STATS" `
                $Script > $OutFile 2>&1
    } else {
        docker run --rm `
            --network http-2-vs-http-3-api-benchmark_default `
            -v $MOUNT `
            -e PROTOCOL=$Proto `
            -e TARGET_URL=$Url `
            -e CONN_TYPE=warm `
            custom-k6 run `
                --vus $VUs `
                --duration $DURATION `
                "--summary-trend-stats=$TREND_STATS" `
                $Script > $OutFile 2>&1
    }
}

# ---- Setup ----------------------------------------------------------

Write-Host "================================================================"
Write-Host " HTTP/2 vs HTTP/3 Full Benchmark — Checkpoint 13"
Write-Host "================================================================"

if (-not (Test-Path $OUT_DIR)) {
    New-Item -ItemType Directory -Force -Path $OUT_DIR | Out-Null
}

# Ensure iproute2 installed in Caddy
docker exec -u root $CADDY sh -c "which tc >/dev/null 2>&1 || apk add --no-cache iproute2 iproute2-tc >/dev/null 2>&1"

# Verify k6 image exists
$k6Check = docker image ls custom-k6 --format "{{.Repository}}"
if (-not $k6Check) {
    Write-Host "ERROR: custom-k6 Docker image not found. Build it first:"
    Write-Host "  docker build -t custom-k6 -f benchmark/Dockerfile.k6 ."
    exit 1
}

# ---- Main loop ------------------------------------------------------

foreach ($scenario in $SCENARIOS) {
    $SCEN_NAME = $scenario[0]
    $DELAY_MS  = [int]$scenario[1]
    $LOSS_PCT  = [int]$scenario[2]
    $IS_LOSSY  = ($LOSS_PCT -gt 0)

    Write-Host ""
    Write-Host "================================================================"
    Write-Host " Scenario: $SCEN_NAME  (delay=${DELAY_MS}ms  loss=${LOSS_PCT}%)"
    Write-Host "================================================================"

    # Apply network condition
    Apply-Network -DelayMs $DELAY_MS -LossPct $LOSS_PCT
    Start-Sleep -Seconds 3

    foreach ($PROTO in $PROTOCOLS) {
        $PROTO_NAME = if ($PROTO -eq "h2") { "HTTP2" } else { "HTTP3" }

        foreach ($ENDPOINT in $URLS) {
            $SAFE_EP = $ENDPOINT -replace '/', '_' -replace '\?', '_' -replace '=', '_'
            $TARGET  = "$BASE_URL$ENDPOINT"

            foreach ($C in $CONCURRENCIES) {

                # Cap HTTP/3 VUs on lossy scenarios to avoid SIGSEGV
                $ACTUAL_VUS = $C
                if ($PROTO -eq "h3" -and $IS_LOSSY -and $C -gt $H3_MAX_VUS_LOSSY) {
                    Write-Host "  [SKIP] $PROTO_NAME c=$C skipped on lossy scenario (SIGSEGV cap=$H3_MAX_VUS_LOSSY)"
                    # Write a placeholder file so the parser knows it was skipped
                    $SKIP_FILE = "$OUT_DIR\${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_r0_warm.txt"
                    "SKIPPED: xk6-http3 SIGSEGV cap — concurrency $C > $H3_MAX_VUS_LOSSY on lossy network" | Out-File -FilePath $SKIP_FILE -Encoding UTF8
                    continue
                }

                # ---- Warm connections: 1 discarded warmup + WARM_REPS kept ----
                Write-Host "  [WARM] $PROTO_NAME | $ENDPOINT | c=$C"

                # Warmup run (discarded — not saved with r0..rN naming)
                Write-Host "    Warmup (discarded)..."
                $WARMUP_FILE = "$OUT_DIR\${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_warmup_warm.txt"
                Run-K6 -Script "/benchmark/scripts/k6-benchmark.js" `
                       -Proto $PROTO -Url $TARGET -VUs $C -ConnType "warm" -OutFile $WARMUP_FILE
                Start-Sleep -Seconds 2

                # 5 kept repetitions
                for ($R = 1; $R -le $WARM_REPS; $R++) {
                    Write-Host "    Run $R/$WARM_REPS..."
                    $OUT_FILE = "$OUT_DIR\${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_r${R}_warm.txt"
                    Run-K6 -Script "/benchmark/scripts/k6-benchmark.js" `
                           -Proto $PROTO -Url $TARGET -VUs $C -ConnType "warm" -OutFile $OUT_FILE
                    Start-Sleep -Seconds 2
                }

                # ---- Cold connections: single run (no repetition needed — each VU = 1 req) ----
                Write-Host "  [COLD] $PROTO_NAME | $ENDPOINT | c=$C"
                $COLD_FILE = "$OUT_DIR\${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_r1_cold.txt"
                Run-K6 -Script "/benchmark/scripts/k6-cold.js" `
                       -Proto $PROTO -Url $TARGET -VUs $C -ConnType "cold" -OutFile $COLD_FILE
                Start-Sleep -Seconds 2
            }
        }
    }
}

# ---- Cleanup --------------------------------------------------------

Write-Host ""
Write-Host "Removing all network impairment..."
docker exec -u root $CADDY sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"

Write-Host ""
Write-Host "================================================================"
Write-Host " Full benchmark complete! Results in: $OUT_DIR"
Write-Host " Run: node benchmark/scripts/parse-v2.js > benchmark/results/full-results-v2.csv"
Write-Host "================================================================"
