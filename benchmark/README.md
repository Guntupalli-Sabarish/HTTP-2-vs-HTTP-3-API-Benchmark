# Benchmark workspace

Scripts and artifacts for HTTP/2 vs HTTP/3 measurements.

## Key scripts
- `scripts/run-full.sh` / `scripts/run-full.ps1`: full Checkpoint 13 matrix runner
- `scripts/parse-v2.js`: parse `results/raw-v2/*.txt` to CSV
- `scripts/generate-report-v2.js`: aggregate results and generate chart-ready CSV + docs

## Output locations
- Legacy raw data (unchanged): `results/raw/`
- Checkpoint 13 raw data: `results/raw-v2/`
- Parsed per-run CSV: `results/full-results-v2.csv`
- Aggregate CSV: `results/full-results-v2-aggregated.csv`
- Chart-ready CSVs: `results/charts-v2/`
