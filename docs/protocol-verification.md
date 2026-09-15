# Protocol verification

## HTTP/2 over TLS

### Endpoint

```text
https://localhost:8443/api/health
```

### Configuration

Caddy terminates local TLS with its internal certificate authority and proxies requests to the unchanged `api:8080` backend. The Caddy site address uses HTTPS, so Caddy can negotiate HTTP/2 through ALPN.

### Verification command

```bash
curl --insecure --http2 --verbose https://localhost:8443/api/health
```

The Ubuntu curl `8.18.0` build in this environment supports HTTP/2 but does not expose the older `--http2-only` command-line switch. `--http2` requests HTTP/2; the verbose negotiation output and HTTP response version below are the explicit proof that it did not fall back to HTTP/1.1. `--insecure` is required only because the development certificate is issued by Caddy's local, private CA rather than a public CA.

### Required evidence

The curl verbose output must include a negotiated protocol line such as:

```text
ALPN: server accepted h2
using HTTP/2
```

An HTTPS response without those lines is not proof of HTTP/2.

### Result

Verified from Ubuntu WSL on 2026-09-15 using curl `8.18.0` with the `HTTP2` feature enabled.

```text
* ALPN: curl offers h2,http/1.1
* ALPN: server accepted h2
* using HTTP/2
< HTTP/2 200
{"status":"UP"}
```

This proves that the request reached Caddy over TLS and negotiated HTTP/2. The response is the same fixed health JSON returned directly by the Spring Boot API.

## HTTP/3 over QUIC

Not configured yet. This section will be updated at Checkpoint 5 only after a client with verified HTTP/3 support is available.
