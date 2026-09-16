$ErrorActionPreference = "Continue"

# =====================================================================
# run-full.ps1 — Full HTTP/2 vs HTTP/3 benchmark (Checkpoint 13)
# =====================================================================

$URLS          = @("/api/health", "/api/products?limit=20", "/api/products?limit=1000")
$CONCURRENCIES = @(1, 10, 50, 100)
$PROTOCOLS     = @("h2", "h3")
$DURATION      = "10s"
$BASE_URL      = "https://caddy:8443"
$OUT_DIR       = "benchmark\results\raw-v2"
$CADDY         = "http-2-vs-http-3-api-benchmark-caddy-1"
$TREND_STATS   = "avg,min,med,max,p(90),p(95),p(99)"
$WARM_REPS     = 5
$H3_MAX_VUS_LOSSY = if ($env:H3_MAX_VUS_LOSSY) { [int]$env:H3_MAX_VUS_LOSSY } else { 25 }
$H3_LOSSY_MODE = if ($env:H3_LOSSY_MODE) { $env:H3_LOSSY_MODE } else { "cap" } # cap | full

$SCENARIOS = @(
    @("scenA_0ms_0loss",   0,   0),
    @("scenB_50ms_0loss",  50,  0),
    @("scenC_50ms_1loss",  50,  1),
    @("scenD_100ms_3loss", 100, 3),
    @("scenE_200ms_5loss", 200, 5)
)

$RunFailures = 0

function Invoke-TC {
    param([string]$cmd)
    docker exec -u root $CADDY sh -c $cmd | Out-Null
}

function Apply-Network {
    param([int]$DelayMs, [int]$LossPct)
    docker exec -u root $CADDY sh -c "tc qdisc del dev eth0 root 2>/dev/null || true" | Out-Null
    if ($DelayMs -gt 0 -or $LossPct -gt 0) {
        docker exec -u root $CADDY sh -c "tc qdisc add dev eth0 root netem delay ${DelayMs}ms loss ${LossPct}%" | Out-Null
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
                $Script *> $OutFile
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
                $Script *> $OutFile
    }

    return $LASTEXITCODE
}

Write-Host "================================================================"
Write-Host " HTTP/2 vs HTTP/3 Full Benchmark — Checkpoint 13"
Write-Host "================================================================"

if (-not (Test-Path $OUT_DIR)) {
    New-Item -ItemType Directory -Force -Path $OUT_DIR | Out-Null
}

docker exec -u root $CADDY sh -c "which tc >/dev/null 2>&1 || apk add --no-cache iproute2 iproute2-tc >/dev/null 2>&1" | Out-Null

$k6Check = docker image ls custom-k6 --format "{{.Repository}}"
if (-not $k6Check) {
    Write-Host "ERROR: custom-k6 Docker image not found. Build it first:"
    Write-Host "  docker build -t custom-k6 -f benchmark/Dockerfile.k6 ."
    exit 1
}

foreach ($scenario in $SCENARIOS) {
    $SCEN_NAME = $scenario[0]
    $DELAY_MS  = [int]$scenario[1]
    $LOSS_PCT  = [int]$scenario[2]
    $IS_LOSSY  = ($LOSS_PCT -gt 0)

    Write-Host ""
    Write-Host "================================================================"
    Write-Host " Scenario: $SCEN_NAME  (delay=${DELAY_MS}ms  loss=${LOSS_PCT}%)"
    Write-Host "================================================================"

    Apply-Network -DelayMs $DELAY_MS -LossPct $LOSS_PCT
    Start-Sleep -Seconds 3

    foreach ($PROTO in $PROTOCOLS) {
        $PROTO_NAME = if ($PROTO -eq "h2") { "HTTP2" } else { "HTTP3" }

        foreach ($ENDPOINT in $URLS) {
            $SAFE_EP = $ENDPOINT -replace '/', '_' -replace '\?', '_' -replace '=', '_'
            $TARGET  = "$BASE_URL$ENDPOINT"

            foreach ($C in $CONCURRENCIES) {
                if ($PROTO -eq "h3" -and $IS_LOSSY -and $H3_LOSSY_MODE -eq "cap" -and $C -gt $H3_MAX_VUS_LOSSY) {
                    Write-Host "  [SKIP] $PROTO_NAME c=$C — lossy safe cap $H3_MAX_VUS_LOSSY"
                    $SKIP_FILE = "$OUT_DIR\${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_r0_warm.txt"
                    "SKIPPED: xk6-http3 lossy safe cap — concurrency $C > $H3_MAX_VUS_LOSSY" | Out-File -FilePath $SKIP_FILE -Encoding UTF8
                    continue
                }

                Write-Host "  [WARM] $PROTO_NAME | $ENDPOINT | c=$C"
                $WARMUP_FILE = "$OUT_DIR\${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_warmup_warm.txt"
                $ec = Run-K6 -Script "/benchmark/scripts/k6-benchmark.js" -Proto $PROTO -Url $TARGET -VUs $C -ConnType "warm" -OutFile $WARMUP_FILE
                if ($ec -ne 0) {
                    $RunFailures += 1
                    "BENCHMARK_RUN_EXIT_CODE=$ec" | Add-Content -Path $WARMUP_FILE
                    Write-Host "    Warmup failed (recorded): $WARMUP_FILE"
                }
                Start-Sleep -Seconds 2

                for ($R = 1; $R -le $WARM_REPS; $R++) {
                    Write-Host "    Run $R/$WARM_REPS..."
                    $OUT_FILE = "$OUT_DIR\${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_r${R}_warm.txt"
                    $ec = Run-K6 -Script "/benchmark/scripts/k6-benchmark.js" -Proto $PROTO -Url $TARGET -VUs $C -ConnType "warm" -OutFile $OUT_FILE
                    if ($ec -ne 0) {
                        $RunFailures += 1
                        "BENCHMARK_RUN_EXIT_CODE=$ec" | Add-Content -Path $OUT_FILE
                        Write-Host "    Run failed (recorded): $OUT_FILE"
                    }
                    Start-Sleep -Seconds 2
                }

                Write-Host "  [COLD] $PROTO_NAME | $ENDPOINT | c=$C"
                $COLD_FILE = "$OUT_DIR\${SCEN_NAME}_${PROTO_NAME}${SAFE_EP}_c${C}_r1_cold.txt"
                $ec = Run-K6 -Script "/benchmark/scripts/k6-cold.js" -Proto $PROTO -Url $TARGET -VUs $C -ConnType "cold" -OutFile $COLD_FILE
                if ($ec -ne 0) {
                    $RunFailures += 1
                    "BENCHMARK_RUN_EXIT_CODE=$ec" | Add-Content -Path $COLD_FILE
                    Write-Host "    Cold run failed (recorded): $COLD_FILE"
                }
                Start-Sleep -Seconds 2
            }
        }
    }
}

Write-Host ""
Write-Host "Removing all network impairment..."
docker exec -u root $CADDY sh -c "tc qdisc del dev eth0 root 2>/dev/null || true" | Out-Null

Write-Host ""
Write-Host "================================================================"
Write-Host " Full benchmark complete! Results in: $OUT_DIR"
Write-Host " Recorded non-zero run exits: $RunFailures"
Write-Host " Run: node benchmark/scripts/parse-v2.js > benchmark/results/full-results-v2.csv"
if ($RunFailures -gt 0) {
    Write-Host " Use investigate-http3-crash.sh and/or run-fallback-h2load.sh for unstable HTTP/3 cases."
}
Write-Host "================================================================"
