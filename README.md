# HTTP/2 vs HTTP/3 API Benchmark

This repository contains a reproducible experiment comparing **HTTP/2** (TCP) and **HTTP/3** (QUIC) against the same Spring Boot API through the same Caddy reverse proxy.

## Architecture

1. **Spring Boot API** (`:8080`)
2. **Caddy reverse proxy** (`:8443`) terminating both HTTP/2 and HTTP/3
3. **Custom `k6` client** built with `xk6-http3`

Both protocols route to the same backend container, minimizing application-layer bias.

## Prerequisites

- Docker + Docker Compose
- Node.js (for parsing/report scripts)
- Bash or PowerShell

## Reproducibility (Checkpoint 13)

### 1) Build the HTTP/3 benchmarking client

```bash
docker build -t custom-k6 -f benchmark/Dockerfile.k6 .
```

### 2) Start stack

```bash
docker compose up -d --build
```

### 3) Run the full suite

The full suite runs:
- **5 network scenarios**: `0/0`, `50/0`, `50/1`, `100/3`, `200/5`
- **Warm mode**: 1 warmup + **5 measured repetitions**
- **Cold mode**: dedicated cold-connection run
- **P50/P90/P95/P99/Max/Avg** metrics

Linux/macOS:
```bash
bash ./benchmark/scripts/run-all.sh
```

Windows:
```powershell
.\benchmark\scripts\run-all.ps1
```

### 4) Outputs

- Per-run parsed CSV: `benchmark/results/full-results-v2.csv`
- Aggregated CSV: `benchmark/results/full-results-v2-aggregated.csv`
- Chart-ready CSVs: `benchmark/results/charts-v2/`
- Methodology/results docs: `docs/methodology.md`, `docs/results.md`

## Important note on HTTP/3 high-concurrency failures

If degraded high-concurrency HTTP/3 runs fail, treat them as **benchmark-client/tooling limitations** (xk6-http3 instability) unless independently validated otherwise. They should not be treated as direct evidence of protocol-level HTTP/3 failure.

---

Existing historical raw outputs in `benchmark/results/raw/` are preserved; Checkpoint 13 data is written to `benchmark/results/raw-v2/`.
