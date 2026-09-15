import http3 from 'k6/x/http3';
import http from 'k6/http';
import { check } from 'k6';

// Cold-connection script: each VU runs exactly 1 iteration (fresh connection per measurement)
const protocol  = __ENV.PROTOCOL   || 'h2';
const targetUrl = __ENV.TARGET_URL || 'https://caddy:8443/api/health';

export const options = {
  insecureSkipTLSVerify: true,
  discardResponseBodies: false,
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
  // iterations = vus * 1 so each VU connects exactly once (cold)
};

export default function () {
  let res;

  if (protocol === 'h3') {
    res = http3.get(targetUrl);
  } else {
    // Force new TCP connection per request
    res = http.get(targetUrl, { headers: { 'Connection': 'close' } });
  }

  check(res, {
    'status is 200': (r) => r && r.status === 200,
  });
}
