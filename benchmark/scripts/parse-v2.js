const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const RAW_DIR = path.join(ROOT, 'results', 'raw-v2');

function detectAndRead(filePath) {
  const buffer = fs.readFileSync(filePath);
  if (buffer.length >= 2 && buffer[0] === 0xff && buffer[1] === 0xfe) {
    return buffer.toString('utf16le');
  }

  let zeroBytes = 0;
  for (let i = 0; i < buffer.length; i++) {
    if (buffer[i] === 0) zeroBytes++;
  }

  if (buffer.length > 0 && zeroBytes / buffer.length > 0.2) {
    return buffer.toString('utf16le');
  }

  return buffer.toString('utf8');
}

function parseScenario(meta) {
  const m = meta.match(/^(scen[A-Z])_(\d+)ms_(\d+)loss$/);
  if (!m) {
    return { code: meta, delayMs: '', lossPct: '', label: meta };
  }
  const [, code, delayMs, lossPct] = m;
  return {
    code,
    delayMs: Number(delayMs),
    lossPct: Number(lossPct),
    label: `${delayMs}ms/${lossPct}%`,
  };
}

function endpointFromToken(token) {
  if (token.includes('_api_health')) return '/api/health';
  if (token.includes('_api_products_limit_20')) return '/api/products?limit=20';
  if (token.includes('_api_products_limit_1000')) return '/api/products?limit=1000';
  return token
    .replace(/^_+/, '/')
    .replace(/_/g, '/')
    .replace('/api/products/limit/20', '/api/products?limit=20')
    .replace('/api/products/limit/1000', '/api/products?limit=1000');
}

function parseDurationSeconds(content, connection, requests, reportedRps) {
  const runs = [...content.matchAll(/running\s*\(([0-9.]+)s\)/g)];
  if (runs.length > 0) {
    return Number(runs[runs.length - 1][1]);
  }

  if (connection === 'warm') return 10;

  if (requests > 0 && reportedRps > 0) {
    return requests / reportedRps;
  }

  return 0;
}

function parseTrend(line, key) {
  const regex = new RegExp(`${key}[^\\n]*`);
  const hit = line.match(regex);
  if (!hit) return null;
  return hit[0];
}

function readMetricToken(metricLine, token) {
  const re = new RegExp(`${token}=([^\\s]+)`);
  const m = metricLine.match(re);
  return m ? m[1] : '-';
}

function parseCountLine(content, key) {
  const lines = content.split('\n');
  const line = lines.find((l) => l.includes(key) && !l.includes('failed'));
  if (!line) return { requests: 0, reportedRps: 0 };

  const m = line.match(/:\s*([0-9,]+)\s+([0-9.]+)\/s/);
  if (!m) return { requests: 0, reportedRps: 0 };

  return {
    requests: Number(m[1].replace(/,/g, '')),
    reportedRps: Number(m[2]),
  };
}

function parseFile(file) {
  const fullPath = path.join(RAW_DIR, file);
  const content = detectAndRead(fullPath);
  const m = file.match(/^(scen[A-Z]_\d+ms_\d+loss)_(HTTP2|HTTP3)(_.+?)_c(\d+)_(warmup|r\d+)_(warm|cold)\.txt$/);
  if (!m) return null;

  const [, scenarioRaw, protocolRaw, endpointToken, conc, runToken, connection] = m;
  const scenario = parseScenario(scenarioRaw);
  const protocol = protocolRaw === 'HTTP3' ? 'HTTP/3' : 'HTTP/2';
  const endpoint = endpointFromToken(endpointToken);
  const concurrency = Number(conc);

  let status = 'success';
  if (/^SKIPPED:/m.test(content)) status = 'skipped';
  else if (/panic|sigsegv|segmentation fault/i.test(content)) status = 'tool_crash';
  else if (/status is 200[^\n]*0\.00%/i.test(content)) status = 'http_error';

  const reqKey = protocol === 'HTTP/3' ? 'http3_req_duration' : 'http_req_duration';
  const countKey = protocol === 'HTTP/3' ? 'http3_reqs' : 'http_reqs';

  const trendLine = parseTrend(content, reqKey) || '';
  const { requests, reportedRps } = parseCountLine(content, countKey);
  const durationSeconds = parseDurationSeconds(content, connection, requests, reportedRps);
  const calculatedRps = requests > 0 && durationSeconds > 0 ? requests / durationSeconds : 0;

  const runType = runToken === 'warmup' ? 'warmup' : 'measured';
  const run = runToken === 'warmup' ? 0 : Number(runToken.replace('r', ''));

  return {
    scenario_code: scenario.code,
    scenario: scenarioRaw,
    delay_ms: scenario.delayMs,
    loss_pct: scenario.lossPct,
    network: scenario.label,
    connection,
    run_type: runType,
    run,
    endpoint,
    concurrency,
    protocol,
    status,
    requests,
    duration_seconds: durationSeconds ? durationSeconds.toFixed(3) : '0.000',
    rps: calculatedRps ? calculatedRps.toFixed(3) : '0.000',
    reported_rps: reportedRps ? reportedRps.toFixed(3) : '0.000',
    p50: readMetricToken(trendLine, 'med'),
    p90: readMetricToken(trendLine, 'p\\(90\\)'),
    p95: readMetricToken(trendLine, 'p\\(95\\)'),
    p99: readMetricToken(trendLine, 'p\\(99\\)'),
    max: readMetricToken(trendLine, 'max'),
    avg: readMetricToken(trendLine, 'avg'),
    source_file: file,
  };
}

if (!fs.existsSync(RAW_DIR)) {
  console.error(`ERROR: raw-v2 directory not found at ${RAW_DIR}`);
  process.exit(1);
}

const rows = fs
  .readdirSync(RAW_DIR)
  .filter((f) => f.endsWith('.txt'))
  .map(parseFile)
  .filter(Boolean)
  .sort((a, b) => {
    if (a.delay_ms !== b.delay_ms) return a.delay_ms - b.delay_ms;
    if (a.loss_pct !== b.loss_pct) return a.loss_pct - b.loss_pct;
    if (a.endpoint !== b.endpoint) return a.endpoint.localeCompare(b.endpoint);
    if (a.concurrency !== b.concurrency) return a.concurrency - b.concurrency;
    if (a.connection !== b.connection) return a.connection.localeCompare(b.connection);
    if (a.protocol !== b.protocol) return a.protocol.localeCompare(b.protocol);
    return a.run - b.run;
  });

const header = [
  'ScenarioCode',
  'Scenario',
  'DelayMs',
  'LossPct',
  'Network',
  'Connection',
  'RunType',
  'Run',
  'Endpoint',
  'Concurrency',
  'Protocol',
  'Status',
  'Requests',
  'DurationSeconds',
  'RPS',
  'ReportedRPS',
  'P50',
  'P90',
  'P95',
  'P99',
  'Max',
  'Avg',
  'SourceFile',
];

console.log(header.join(','));
for (const r of rows) {
  console.log([
    r.scenario_code,
    r.scenario,
    r.delay_ms,
    r.loss_pct,
    r.network,
    r.connection,
    r.run_type,
    r.run,
    r.endpoint,
    r.concurrency,
    r.protocol,
    r.status,
    r.requests,
    r.duration_seconds,
    r.rps,
    r.reported_rps,
    r.p50,
    r.p90,
    r.p95,
    r.p99,
    r.max,
    r.avg,
    r.source_file,
  ].join(','));
}
