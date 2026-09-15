import http from 'k6/http';
import { check } from 'k6';

export default function () {
  // Try using experimental HTTP which might support HTTP/3
  const res = http.get('https://caddy:8443/api/health', {
    headers: { 'Alt-Svc': 'h3=":8443"' } // Just in case Alt-Svc helps
  });
  console.log(`Proto: ${res.proto}`);
}
