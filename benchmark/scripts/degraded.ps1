$ErrorActionPreference = "Continue"

$URLS = @("/api/health", "/api/products?limit=20", "/api/products?limit=1000")
$CONCURRENCIES = @(1, 10, 50, 100)
$PROTOCOLS = @("h2", "h3")
$DURATION = "10s"
$BASE_URL = "https://caddy:8443"
$OUT_DIR = "benchmark\results\raw"

if (-not (Test-Path $OUT_DIR)) {
    New-Item -ItemType Directory -Force -Path $OUT_DIR | Out-Null
}

Write-Host "Starting Degraded Benchmark with k6 (50ms latency, 5% loss)..."

foreach ($PROTO in $PROTOCOLS) {
    if ($PROTO -eq "h2") {
        $PROTO_NAME = "HTTP2"
    } else {
        $PROTO_NAME = "HTTP3"
    }

    foreach ($ENDPOINT in $URLS) {
        # Safe filename conversion
        $SAFE_ENDPOINT = $ENDPOINT -replace '/', '_' -replace '\?', '_' -replace '=', '_'
        
        foreach ($C in $CONCURRENCIES) {
            $OUT_FILE = "$OUT_DIR\degraded_${PROTO_NAME}_${SAFE_ENDPOINT}_c${C}.txt"
            
            Write-Host "Running $PROTO_NAME test against $ENDPOINT with concurrency $C..."
            
            # Run docker k6
            $TARGET_URL = "$BASE_URL$ENDPOINT"
            
            # Use absolute path for Docker volume mounting
            $PWD = (Get-Location).Path
            $MOUNT = "$PWD\benchmark:/benchmark"
            
            # Execute and redirect output
            docker run --rm `
                --network http-2-vs-http-3-api-benchmark_default `
                -v $MOUNT `
                -e PROTOCOL=$PROTO `
                -e TARGET_URL=$TARGET_URL `
                custom-k6 run --vus $C --duration $DURATION /benchmark/scripts/k6-baseline.js > $OUT_FILE 2>&1
            
            Start-Sleep -Seconds 2
        }
    }
}

Write-Host "Benchmark complete! Results saved in $OUT_DIR"
