# Benchmark workspace

Scripts and artifacts for HTTP/2 vs HTTP/3 measurements.

## Key scripts
- `scripts/run-full.sh` / `scripts/run-full.ps1`: full Checkpoint 13 matrix runner
- `scripts/verify-checkpoint13.sh`: standalone environment + methodology verification
- `scripts/investigate-http3-crash.sh`: reproduces/analyzes xk6-http3 degraded-concurrency crashes
- `scripts/run-fallback-h2load.sh`: fallback HTTP/2 vs HTTP/3 benchmark path for unstable xk6 cases
- `scripts/parse-v2.js`: parse `results/raw-v2/*.txt` to CSV
- `scripts/generate-report-v2.js`: aggregate results and generate chart-ready CSV + docs

## Output locations
- Legacy raw data (unchanged): `results/raw/`
- Checkpoint 13 raw data: `results/raw-v2/`
- Parsed per-run CSV: `results/full-results-v2.csv`
- Aggregate CSV: `results/full-results-v2-aggregated.csv`
- Chart-ready CSVs: `results/charts-v2/`

## Crash handling workflow
1. Run `scripts/verify-checkpoint13.sh` before the benchmark suite.
2. Run `scripts/run-full.sh` (or `.ps1`) as primary data collection.
3. If HTTP/3 degraded runs fail, run `scripts/investigate-http3-crash.sh`.
4. For unstable scenario/concurrency pairs, collect fallback data with `scripts/run-fallback-h2load.sh`.
