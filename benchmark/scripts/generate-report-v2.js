const fs = require('fs');
const path = require('path');

const RESULTS_DIR = path.join(__dirname, '..', 'results');
const INPUT_CSV = path.join(RESULTS_DIR, 'full-results-v2.csv');
const AGG_CSV = path.join(RESULTS_DIR, 'full-results-v2-aggregated.csv');
const CHARTS_V2_DIR = path.join(RESULTS_DIR, 'charts-v2');
const DOC_RESULTS = path.join(__dirname, '..', '..', 'docs', 'results.md');
const DOC_METHOD = path.join(__dirname, '..', '..', 'docs', 'methodology.md');

function parseCsv(csvText) {
  const lines = csvText.trim().split(/\r?\n/);
  const headers = lines[0].split(',');
  return lines.slice(1).map((line) => {
    const cols = line.split(',');
    const row = {};
    headers.forEach((h, i) => {
      row[h] = cols[i] ?? '';
    });
    row.DelayMs = Number(row.DelayMs || 0);
    row.LossPct = Number(row.LossPct || 0);
    row.Concurrency = Number(row.Concurrency || 0);
    row.Run = Number(row.Run || 0);
    row.Requests = Number(row.Requests || 0);
    row.DurationSeconds = Number(row.DurationSeconds || 0);
    row.RPS = Number(row.RPS || 0);
    row.ReportedRPS = Number(row.ReportedRPS || 0);
    return row;
  });
}

function unitToMs(value) {
  if (!value || value === '-' || value === '0') return 0;
  if (value.endsWith('µs')) return Number(value.replace('µs', '')) / 1000;
  if (value.endsWith('ms')) return Number(value.replace('ms', ''));
  if (value.endsWith('s')) return Number(value.replace('s', '')) * 1000;
  return Number(value) || 0;
}

function avg(nums) {
  if (!nums.length) return 0;
  return nums.reduce((a, b) => a + b, 0) / nums.length;
}

function toCsv(rows, columns) {
  const header = columns.join(',');
  const body = rows.map((r) => columns.map((c) => r[c]).join(','));
  return [header, ...body].join('\n') + '\n';
}

function writeChartCsv(name, rows, columns) {
  if (!fs.existsSync(CHARTS_V2_DIR)) {
    fs.mkdirSync(CHARTS_V2_DIR, { recursive: true });
  }
  fs.writeFileSync(path.join(CHARTS_V2_DIR, name), toCsv(rows, columns), 'utf8');
}

if (!fs.existsSync(INPUT_CSV)) {
  console.error(`ERROR: ${INPUT_CSV} does not exist. Run parse-v2 first.`);
  process.exit(1);
}

const rows = parseCsv(fs.readFileSync(INPUT_CSV, 'utf8'));

const measuredSuccess = rows.filter(
  (r) => r.Status === 'success' && r.RunType === 'measured'
);

const keyFor = (r) => [
  r.Scenario,
  r.DelayMs,
  r.LossPct,
  r.Network,
  r.Connection,
  r.Endpoint,
  r.Concurrency,
  r.Protocol,
].join('|');

const groups = new Map();
for (const row of measuredSuccess) {
  const key = keyFor(row);
  if (!groups.has(key)) groups.set(key, []);
  groups.get(key).push(row);
}

const aggregates = [];
for (const [key, list] of groups.entries()) {
  const [Scenario, DelayMs, LossPct, Network, Connection, Endpoint, Concurrency, Protocol] = key.split('|');
  const p50Vals = list.map((r) => unitToMs(r.P50)).filter((v) => v > 0);
  const p99Vals = list.map((r) => unitToMs(r.P99)).filter((v) => v > 0);

  aggregates.push({
    Scenario,
    DelayMs,
    LossPct,
    Network,
    Connection,
    Endpoint,
    Concurrency,
    Protocol,
    Samples: list.length,
    AvgRequests: avg(list.map((r) => r.Requests)).toFixed(3),
    AvgRPS: avg(list.map((r) => r.RPS)).toFixed(3),
    AvgReportedRPS: avg(list.map((r) => r.ReportedRPS)).toFixed(3),
    AvgP50Ms: avg(p50Vals).toFixed(3),
    AvgP99Ms: avg(p99Vals).toFixed(3),
  });
}

aggregates.sort((a, b) => {
  if (Number(a.DelayMs) !== Number(b.DelayMs)) return Number(a.DelayMs) - Number(b.DelayMs);
  if (Number(a.LossPct) !== Number(b.LossPct)) return Number(a.LossPct) - Number(b.LossPct);
  if (a.Endpoint !== b.Endpoint) return a.Endpoint.localeCompare(b.Endpoint);
  if (Number(a.Concurrency) !== Number(b.Concurrency)) return Number(a.Concurrency) - Number(b.Concurrency);
  if (a.Connection !== b.Connection) return a.Connection.localeCompare(b.Connection);
  return a.Protocol.localeCompare(b.Protocol);
});

fs.writeFileSync(
  AGG_CSV,
  toCsv(aggregates, [
    'Scenario',
    'DelayMs',
    'LossPct',
    'Network',
    'Connection',
    'Endpoint',
    'Concurrency',
    'Protocol',
    'Samples',
    'AvgRequests',
    'AvgRPS',
    'AvgReportedRPS',
    'AvgP50Ms',
    'AvgP99Ms',
  ]),
  'utf8'
);

const crashRows = rows.filter((r) => r.Status === 'tool_crash' || r.Status === 'tool_error' || r.Status === 'skipped');
const crashSummary = [...new Set(crashRows.map((r) => `${r.Scenario} | ${r.Protocol} | c=${r.Concurrency} | ${r.Status}`))]
  .sort();

const chartRpsRows = aggregates
  .filter((r) => r.Connection === 'warm' && r.Endpoint === '/api/products?limit=1000' && Number(r.Concurrency) === 10)
  .map((r) => ({ Scenario: r.Network, Protocol: r.Protocol, AvgRPS: r.AvgRPS }));

const chartP99Rows = aggregates
  .filter((r) => r.Connection === 'warm' && r.Endpoint === '/api/products?limit=1000' && Number(r.Concurrency) === 10)
  .map((r) => ({ Scenario: r.Network, Protocol: r.Protocol, AvgP99Ms: r.AvgP99Ms }));

const chartColdWarmRows = aggregates
  .filter((r) => r.Endpoint === '/api/products?limit=1000' && Number(r.Concurrency) === 10 && r.Scenario === 'scenA_0ms_0loss')
  .map((r) => ({ Connection: r.Connection, Protocol: r.Protocol, AvgP50Ms: r.AvgP50Ms, AvgRPS: r.AvgRPS }));

writeChartCsv('scenario-rps-limit1000-c10-warm.csv', chartRpsRows, ['Scenario', 'Protocol', 'AvgRPS']);
writeChartCsv('scenario-p99-limit1000-c10-warm.csv', chartP99Rows, ['Scenario', 'Protocol', 'AvgP99Ms']);
writeChartCsv('cold-vs-warm-baseline-limit1000-c10.csv', chartColdWarmRows, ['Connection', 'Protocol', 'AvgP50Ms', 'AvgRPS']);

const resultsDoc = `# Experiment Results

This report now uses the Checkpoint 13 dataset generated from \`benchmark/results/raw-v2\` and preserves existing \`benchmark/results/raw\` files.

## What changed in Checkpoint 13
- Five network scenarios are captured: 0/0, 50/0, 50/1, 100/3, 200/5.
- Warm-connection tests run with repeated measured samples.
- Cold-connection tests are recorded separately.
- P99 is included in parsed output and aggregate summaries.
- RPS is reported both from k6 and from derived requests/duration.

## Output files
- Per-run dataset: \`benchmark/results/full-results-v2.csv\`
- Aggregated dataset: \`benchmark/results/full-results-v2-aggregated.csv\`
- Chart-ready CSVs: \`benchmark/results/charts-v2/*.csv\`

## HTTP/3 crash interpretation
Any \`tool_crash\`, \`tool_error\`, or \`skipped\` rows represent **benchmark tooling limitations** (xk6-http3 instability under lossy/high-concurrency conditions), not direct protocol-level conclusions.

## Crash/skip inventory
${crashSummary.length ? crashSummary.map((x) => `- ${x}`).join('\n') : '- No tool_crash/tool_error/skipped rows detected in parsed data.'}

## Reproducibility checklist
1. Build \`custom-k6\` from \`benchmark/Dockerfile.k6\`.
2. Start stack via \`docker compose up -d --build\`.
3. Run \`benchmark/scripts/run-full.sh\` (or \`.ps1\`).
4. Parse: \`node benchmark/scripts/parse-v2.js > benchmark/results/full-results-v2.csv\`.
5. Report: \`node benchmark/scripts/generate-report-v2.js\`.
6. If HTTP/3 instability appears, run \`benchmark/scripts/investigate-http3-crash.sh\` then \`benchmark/scripts/run-fallback-h2load.sh\` for affected scenario/concurrency pairs.
`;

fs.writeFileSync(DOC_RESULTS, resultsDoc, 'utf8');

const methodDoc = `# Methodology (Checkpoint 13)

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
HTTP/3 instability from xk6-http3 at lossy high-concurrency settings is recorded as tooling failure (\`tool_crash\`, \`tool_error\`, or \`skipped\`), and should not be interpreted as protocol failure without independent confirmation.

## Crash investigation and fallback
- Primary investigation script: \`benchmark/scripts/investigate-http3-crash.sh\`
- Standalone fallback benchmark: \`benchmark/scripts/run-fallback-h2load.sh\`
- Use fallback results only for unstable scenario/concurrency combinations, and keep primary data under \`benchmark/results/raw-v2/\`.
`;

fs.writeFileSync(DOC_METHOD, methodDoc, 'utf8');

console.log(`Wrote ${AGG_CSV}`);
console.log(`Wrote chart-ready CSVs to ${CHARTS_V2_DIR}`);
console.log(`Updated ${DOC_RESULTS}`);
console.log(`Updated ${DOC_METHOD}`);
