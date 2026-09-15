# HTTP/2 vs HTTP/3 API Benchmark

A reproducible experiment comparing identical Spring Boot API responses through HTTP/2 over TCP/TLS and HTTP/3 over QUIC/TLS.

The project is being built checkpoint by checkpoint. It does not yet contain benchmark results or a configured reverse proxy.

## Layout

```text
api/                  Spring Boot application
caddy/                Caddy configuration (introduced at checkpoint 3)
benchmark/scripts/    Benchmark and verification scripts
benchmark/results/    Immutable raw results, processed data, and charts
docs/                 Environment, methodology, and result documentation
```

