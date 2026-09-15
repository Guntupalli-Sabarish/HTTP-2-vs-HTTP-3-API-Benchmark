import http3 from 'k6/x/http3';
import http from 'k6/http';
import { check } from 'k6';

const protocol = __ENV.PROTOCOL || 'h2';
const targetUrl = __ENV.TARGET_URL || 'https://caddy:8443/api/health';

export const options = {
  insecureSkipTLSVerify: true,
  discardResponseBodies: true,
};

export default function () {
  let res;
  if (protocol === 'h3') {
    res = http3.get(targetUrl);
  } else {
    res = http.get(targetUrl);
  }
  
  check(res, {
    'status is 200': (r) => r.status === 200,
  });
}
