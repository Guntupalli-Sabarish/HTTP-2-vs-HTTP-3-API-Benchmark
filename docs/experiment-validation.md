# Experiment Validation

Before proceeding to benchmarking, this document proves that the experiment setup is valid, unbiased, and comparing exactly what it claims to compare.

## Architecture Diagram

```text
                ┌──────────────┐
                │    Client    │
                └──────┬───────┘
                       │
              ┌────────┴────────┐
              │                 │
           HTTP/2             HTTP/3
         (TCP + TLS)       (QUIC + UDP)
              │                 │
              └────────┬────────┘
                       │
                 Caddy (:8443)
                       │
                    HTTP/1.1
                       │
           Spring Boot API (api:8080)
```

## Validation Checklist

### Same API
- **Verified:** Both HTTP/2 and HTTP/3 requests are routed via Caddy's single `reverse_proxy api:8080` directive. There is no diverging logic based on the incoming protocol.

### Same server
- **Verified:** Both protocols ultimately terminate at the exact same Spring Boot container.

### Same endpoint
- **Verified:** Both tests query the `/api/health` endpoint on port `8443`.

### Same payload
- **Verified:** Both protocols returned the identical response body: `{"status":"UP"}`. 

### Same environment
- **Verified:** Both test requests were initiated from the same Docker bridge network (`http-2-vs-http-3-api-benchmark_default`), pointing to the same Caddy container (`172.19.0.3:8443`). No cross-machine variables were introduced.

### Protocol verification
- **Verified (HTTP/2):** The curl output in `docs/protocol-verification.md` explicitly shows `* ALPN: server accepted h2` and `* using HTTP/2`.
- **Verified (HTTP/3):** The curl output in `docs/protocol-verification.md` using the Dockerized `ymuski/curl-http3` client explicitly shows `* using HTTP/3` and `< HTTP/3 200`.

## Conclusion
The testbed is valid. Any performance differences observed in the subsequent benchmarks will be exclusively due to the transport layers (TCP vs QUIC) and the HTTP protocol versions (HTTP/2 vs HTTP/3), not application variance.