# Blog Data

## 1. Research question
When network conditions become slower or experience packet loss, does HTTP/3 provide better API latency and behavior than HTTP/2?

## 2. Architecture
```text
                         Benchmark Client (k6)
                                │
                  ┌─────────────┴─────────────┐
                  │                           │
             HTTP/2 ONLY                 HTTP/3 ONLY
              TCP + TLS                  QUIC + TLS
                  │                           │
                  └─────────────┬─────────────┘
                                │
                           ┌────▼────┐
                           │  Caddy  │ (localhost:8443)
                           └────┬────┘
                                │
                             HTTP/1.1
                                │
                         ┌──────▼──────┐
                         │ Spring Boot │ (localhost:8080)
                         │     API     │
                         └─────────────┘
```

## 3. Experimental methodology
- **Server:** A local Spring Boot API serving deterministic JSON responses.
- **Proxy:** Caddy reverse proxy used to terminate both HTTP/2 and HTTP/3 uniformly and pass HTTP/1.1 back to the API.
- **Client:** A custom dockerized build of `k6` using the `xk6-http3` extension.
- **Metrics:** We collected P50, P90, P95, Max Latency, and Total Requests (Throughput) over 10-second intervals for varying payloads and concurrencies.

## 4. Test conditions
- **Baseline (Clean):** 0ms added latency, 0% packet loss.
- **Degraded:** 50ms added latency, 5% packet loss (simulating a poor mobile network or congested Wi-Fi).

## 5. Raw benchmark summary
Full raw benchmark data can be found in `benchmark/results/full-results.csv`.

## 6. Important results
- **Clean Network (Baseline):** HTTP/2 consistently outperformed HTTP/3 at high concurrencies (e.g., 50 and 100 VUs). The P50 latency was lower, and throughput was higher for HTTP/2.
- **Degraded Network (Lossy):** HTTP/3 dramatically outperformed HTTP/2. For the 1000-item JSON payload at concurrency 10, HTTP/3 served **227 requests** compared to HTTP/2's **160 requests**. HTTP/2 maximum latency spiked to **1.47 seconds**, whereas HTTP/3 peaked at **947ms**.

## 7. Unexpected results
The community HTTP/3 benchmarking tool (`xk6-http3`) completely crashed with a memory segmentation fault (`SIGSEGV`) when subjected to 5% packet loss at concurrencies of 50 and 100. It failed to complete the test.

## 8. Possible explanations
- **Why HTTP/2 won the Baseline:** TCP in the Linux kernel is incredibly optimized (40 years of refinement). QUIC is implemented in user-space and requires higher CPU overhead to encrypt and manage UDP packets.
- **Why HTTP/3 won the Degraded test:** HTTP/2 suffers from TCP Head-of-Line (HoL) blocking. If one packet drops, the entire TCP connection (and all multiplexed API requests sharing it) pauses until the packet is retransmitted. HTTP/3 QUIC operates on independent streams; a dropped packet only delays one specific request, letting the others finish seamlessly.
- **Why the tool crashed:** The QUIC ecosystem and load-testing tools are still immature compared to HTTP/2.

## 9. Limitations
- The client and server were hosted on the same machine (localhost Docker bridge), relying on Linux `tc` to simulate network distance rather than physical geographical distance.
- The benchmarking client ecosystem for HTTP/3 is still brittle, preventing us from successfully capturing 100-concurrency degraded metrics.
- Connections were "warm" (k6 reuses connections during the 10-second loop). We did not heavily measure the "cold" 0-RTT handshake benefits of HTTP/3.

## 10. API-design implications
APIs serving large, data-heavy payloads (like massive JSON arrays) to mobile clients will see massive latency reductions under HTTP/3 because they avoid TCP HoL blocking.

## 11. Infrastructure implications
Enabling HTTP/3 at the edge (via Caddy, Nginx, or Cloudflare) is practically free and highly beneficial for clients. However, you should probably stick to HTTP/2 (or HTTP/1.1) for internal service-to-service communication within a reliable, low-latency datacenter, as the QUIC user-space overhead isn't worth it.

## 12. Conclusions that are justified by the data
1. HTTP/3 effectively solves TCP Head-of-Line blocking, making it vastly superior for poor networks.
2. HTTP/2 is faster in perfect network conditions.
3. The HTTP/3 tooling ecosystem is not fully production-ready for heavy stress testing.
