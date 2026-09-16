# Experiment Results

This report now uses the Checkpoint 13 dataset generated from `benchmark/results/raw-v2` and preserves existing `benchmark/results/raw` files.

## What changed in Checkpoint 13
- Five network scenarios are captured: 0/0, 50/0, 50/1, 100/3, 200/5.
- Warm-connection tests run with repeated measured samples.
- Cold-connection tests are recorded separately.
- P99 is included in parsed output and aggregate summaries.
- RPS is reported both from k6 and from derived requests/duration.

## Output files
- Per-run dataset: `benchmark/results/full-results-v2.csv`
- Aggregated dataset: `benchmark/results/full-results-v2-aggregated.csv`
- Chart-ready CSVs: `benchmark/results/charts-v2/*.csv`

## HTTP/3 crash interpretation
Any `tool_crash` or `skipped` rows represent **benchmark tooling limitations** (xk6-http3 instability under lossy/high-concurrency conditions), not direct protocol-level conclusions.

## Crash/skip inventory
- No tool_crash/tool_error/skipped rows detected in parsed data.

## Reproducibility checklist
1. Build `custom-k6` from `benchmark/Dockerfile.k6`.
2. Start stack via `docker compose up -d --build`.
3. Run `benchmark/scripts/run-full.sh` (or `.ps1`).
4. Parse: `node benchmark/scripts/parse-v2.js > benchmark/results/full-results-v2.csv`.
5. Report: `node benchmark/scripts/generate-report-v2.js`.
