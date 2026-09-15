# Caddy reverse proxy

## Architecture

```text
Client -> Caddy (HTTPS on port 8443) -> Spring Boot API (HTTP on port 8080)
```

At Checkpoint 3 Caddy was configured for plain HTTP on port 8081. TLS and HTTP/2 are introduced at Checkpoint 4; HTTP/3 is introduced separately at Checkpoint 5.

## Configuration

`caddy/Caddyfile` proxies every TLS request received on port `8443` to the Compose service name `api` on port `8080`:

```caddyfile
https://localhost:8443 {
    tls internal
    reverse_proxy api:8080
}
```

The `api` service is not exposed directly to the host. Only Caddy publishes port `8443`, so a successful request to `https://localhost:8443/api/health` demonstrates the intended client-to-proxy-to-application path.

## Verification command

After Docker is available:

```bash
cd api && mvn package
cd .. && docker compose up --build -d
curl --insecure --http2-only --fail --silent --show-error https://localhost:8443/api/health
docker compose down
```

Expected response:

```json
{"status":"UP"}
```

## Current limitation

The configuration has not been live-tested in this workspace. Caddy is not installed and the Docker daemon is unavailable, so the Compose services cannot be started. No fallback proxy was substituted because that would not verify Caddy.
