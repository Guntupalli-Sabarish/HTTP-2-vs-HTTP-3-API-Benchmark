# Methodology (Checkpoint 13)

## Scope
This benchmark compares HTTP/2 and HTTP/3 against the same backend API through the same Caddy reverse proxy path.

## Network scenarios
- scenA: 0ms delay, 0% loss
- scenB: 50ms delay, 0% loss
- scenC: 50ms delay, 1% loss
- scenD: 100ms delay, 3% loss
- scenE: 200ms delay, 5% loss

## Matrix
- Endpoints: /api/health, /api/products?limit=20, /api/products?limit=1000
- Concurrency: 1, 10, 50, 100
- Protocols: HTTP/2 and HTTP/3
- Connection modes: warm and cold

## Repetition strategy
- Warm mode: 1 warmup run discarded + 5 measured runs per configuration
- Cold mode: single run per configuration with one iteration per VU

## Metrics
- Latency: P50, P90, P95, P99, Max, Avg
- Throughput: total requests and RPS (derived and reported)

## Tooling limitation handling
HTTP/3 instability from xk6-http3 at lossy high-concurrency settings is recorded as tooling failure (`tool_crash` or `skipped`), and should not be interpreted as protocol failure without independent confirmation.
