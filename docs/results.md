# Experiment Results

## Observed result
In the baseline (clean network), HTTP/2 consistently served more requests per second at higher concurrencies with lower latency than HTTP/3.
However, in the degraded network (50ms latency, 5% loss), HTTP/3 significantly outperformed HTTP/2. For a 1000-item payload at concurrency 10, HTTP/3 served ~40% more requests and maintained a maximum latency under 1 second, while HTTP/2 spiked to nearly 1.5 seconds. 

At concurrencies of 50 and 100 on the degraded network, the HTTP/3 benchmarking client encountered fatal crashes, failing the test.

## Interpretation
- **Baseline:** Linux kernel TCP (HTTP/2) is vastly more optimized for CPU overhead than userspace QUIC implementations (HTTP/3) in high-speed, zero-loss environments.
- **Degraded:** TCP Head-of-Line blocking cripples HTTP/2 when packets are lost. QUIC's independent streams allow HTTP/3 to continue serving unaffected requests seamlessly.
- **Client Crashes:** The HTTP/3 load generation ecosystem (xk6-http3) is immature and brittle under packet loss at scale.

## Limitation
- This experiment used local Docker bridge networking with simulated impairment, not a true geographically distributed WAN.
- The inability to test HTTP/3 at concurrency 50+ under packet loss limits our conclusions about its high-load resilience.

## Charts

### Baseline Latency
![Baseline P50 Latency](../benchmark/results/charts/baseline-p50-latency.png)

### Degraded Throughput (Packet Loss Impact)
![Degraded Throughput](../benchmark/results/charts/degraded-throughput.png)
