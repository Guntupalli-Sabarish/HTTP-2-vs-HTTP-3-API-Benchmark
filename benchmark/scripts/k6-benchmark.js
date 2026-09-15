import http3 from 'k6/x/http3';
import http from 'k6/http';
import { check } from 'k6';

// Environment variables
const protocol  = __ENV.PROTOCOL   || 'h2';   // 'h2' or 'h3'
const targetUrl = __ENV.TARGET_URL || 'https://caddy:8443/api/health';
const connType  = __ENV.CONN_TYPE  || 'warm'; // 'warm' or 'cold'

// Build options — warm: run for duration; cold: one iteration per VU
export const options = {
  insecureSkipTLSVerify: true,
  discardResponseBodies: false,
  // Request P99 in summary alongside the default stats
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

export default function () {
  let res;

  if (protocol === 'h3') {
    // xk6-http3: each call reuses the QUIC connection across the VU lifetime
    res = http3.get(targetUrl);
  } else {
    const params = connType === 'cold'
      ? { headers: { 'Connection': 'close' } }
      : {};
    res = http.get(targetUrl, params);
  }

  check(res, {
    'status is 200': (r) => r && r.status === 200,
  });
}
