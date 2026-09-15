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

### Endpoint

```text
https://caddy:8443/api/health
```

### Configuration

Caddy enables HTTP/3 by default on the same port it uses for HTTPS. To support HTTP/3, the UDP port `8443` must be explicitly exposed in Docker Compose alongside the TCP port. The `Caddyfile` was updated to explicitly serve `https://caddy:8443` to ensure the internal TLS certificate is valid when queried from within the Docker network.

### Verification command

Because the default `curl` build on WSL does not support HTTP/3, we use a Dockerized client (`ymuski/curl-http3`) attached directly to the project's Docker network to issue the request:

```bash
docker run --rm --network http-2-vs-http-3-api-benchmark_default ymuski/curl-http3 curl --insecure --http3 --verbose https://caddy:8443/api/health
```

### Required evidence

The curl verbose output must confirm the usage of HTTP/3 via UDP:

```text
* using HTTP/3
< HTTP/3 200
```

### Result

Verified on 2026-09-15 using the `ymuski/curl-http3` Docker image:

```text
* Connected to caddy (172.19.0.3) port 8443
* using HTTP/3
* Using HTTP/3 Stream ID: 0
> GET /api/health HTTP/3
> Host: caddy:8443
> User-Agent: curl/8.2.1-DEV
> Accept: */*
> 
< HTTP/3 200 
< content-type: application/json
< date: Tue, 15 Sep 2026 16:35:17 GMT
< via: 1.1 Caddy
< 
{"status":"UP"}
```

This proves that the client successfully reached Caddy over QUIC (UDP) and negotiated HTTP/3, returning the exact same application payload as HTTP/2.
