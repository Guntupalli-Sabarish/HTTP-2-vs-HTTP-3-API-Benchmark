const fs = require('fs');
const path = require('path');

const rawDir = path.join(__dirname, '../results/raw');
const files = fs.readdirSync(rawDir).filter(f => f.endsWith('.txt'));

const results = [];

files.forEach(file => {
    const content = fs.readFileSync(path.join(rawDir, file), 'utf16le');
    
    let protocol = file.includes('HTTP3') ? 'HTTP/3' : 'HTTP/2';
    let network = file.includes('degraded') ? 'Degraded (50ms/5%loss)' : 'Baseline (Clean)';
    
    // Extract endpoint
    let endpoint = 'Unknown';
    if (file.includes('health')) endpoint = '/api/health';
    else if (file.includes('limit_20')) endpoint = '/api/products?limit=20';
    else if (file.includes('limit_1000')) endpoint = '/api/products?limit=1000';
    
    // Extract concurrency
    const cMatch = file.match(/_c(\d+)\.txt/);
    const concurrency = cMatch ? parseInt(cMatch[1]) : 0;
    
    const reqKey = protocol === 'HTTP/3' ? 'http3_req_duration' : 'http_req_duration';
    const countKey = protocol === 'HTTP/3' ? 'http3_reqs' : 'http_reqs';
    
    let avg='-', min='-', med='-', max='-', p90='-', p95='-', reqs='FAIL';
    
    const lines = content.split('\n');
    lines.forEach(line => {
        if (line.includes(reqKey)) {
            const mAvg = line.match(/avg=([^\s]+)/);
            const mMin = line.match(/min=([^\s]+)/);
            const mMed = line.match(/med=([^\s]+)/);
            const mMax = line.match(/max=([^\s]+)/);
            const mP90 = line.match(/p\(90\)=([^\s]+)/);
            const mP95 = line.match(/p\(95\)=([^\s]+)/);
            
            if (mAvg) avg = mAvg[1];
            if (mMin) min = mMin[1];
            if (mMed) med = mMed[1];
            if (mMax) max = mMax[1];
            if (mP90) p90 = mP90[1];
            if (mP95) p95 = mP95[1];
        }
        if (line.includes(countKey) && !line.includes('failed')) {
            const mReqs = line.match(new RegExp(`${countKey}[\\s\\.]+: (\\d+)`));
            if (mReqs) reqs = mReqs[1];
        }
    });
    
    results.push({
        network, protocol, endpoint, concurrency,
        reqs, avg, min, med, max, p90, p95
    });
});

// Sort results
results.sort((a, b) => {
    if (a.network !== b.network) return a.network.localeCompare(b.network);
    if (a.endpoint !== b.endpoint) return a.endpoint.localeCompare(b.endpoint);
    if (a.concurrency !== b.concurrency) return a.concurrency - b.concurrency;
    return a.protocol.localeCompare(b.protocol);
});

// Output CSV
console.log('Network,Endpoint,Concurrency,Protocol,Requests,P50,P90,P95,Max,Avg');
results.forEach(r => {
    console.log(`${r.network},${r.endpoint},${r.concurrency},${r.protocol},${r.reqs},${r.med},${r.p90},${r.p95},${r.max},${r.avg}`);
});
