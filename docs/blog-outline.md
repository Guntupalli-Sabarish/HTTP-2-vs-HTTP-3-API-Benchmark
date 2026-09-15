# HTTP/2 vs HTTP/3: I Built the Same API Twice. Here's What the Network Actually Did.

## Introduction
- **The premise**: Everyone says HTTP/3 is faster because of QUIC and UDP, but most benchmarks focus on static file delivery or CDNs. What about backend REST APIs? 
- **The hypothesis**: HTTP/3 shines most when the network is terrible. Under perfect conditions, HTTP/2 (TCP) might even be faster due to mature OS-level optimizations. 
- **The goal**: Build a completely unbiased testbed. Same Spring Boot API, same Caddy reverse proxy, same Docker network. Test the API over HTTP/2 and HTTP/3 under both perfect and heavily degraded network conditions.

## The Testbed Architecture
- Diagram of the setup: Client -> Caddy (HTTP/2 over TCP / HTTP/3 over QUIC) -> Spring Boot (HTTP/1.1 over TCP).
- Tools used: Docker, Caddy, Spring Boot, Linux Traffic Control (`tc`), and a custom-built `k6` benchmarking client using `xk6-http3`.

## Phase 1: The Baseline Benchmark (Clean Network)
- **The Test**: Hit the `/api/health` and `/api/products` endpoints with varying concurrencies (1, 10, 50, 100).
- **The Result**: 
  - On a clean network (localhost Docker bridge, 0ms latency, 0% packet loss), **HTTP/2 actually outperformed HTTP/3** at high concurrencies.
  - *Why?* Because TCP stacks in the Linux kernel are incredibly optimized after 40 years of development. QUIC implementations (which run in user-space) require more CPU overhead to encrypt and manage UDP packets.
- **Takeaway**: If your API runs in a high-speed, zero-loss internal datacenter (service-to-service), HTTP/2 is probably still the better choice.

## Phase 2: The Network Degradation Experiment
- **The Setup**: We used `tc netem` to simulate a poor mobile connection (50ms base latency, 5% packet loss) applied directly to the Caddy container.
- **The Result**:
  - The tables turn. For large payloads (`/api/products?limit=1000`) at concurrency 10, HTTP/3 completed **227 requests** compared to HTTP/2's **160 requests**.
  - HTTP/3 max latency was ~947ms. HTTP/2 max latency spiked to ~1.47s.
- **The Science (Head-of-Line Blocking)**: 
  - HTTP/2 relies on a single TCP connection for multiplexed streams. If packet #4 is dropped, TCP halts delivery of packets #5, #6, and #7 until #4 is retransmitted. All API requests sharing that connection stall.
  - HTTP/3 relies on QUIC. If packet #4 belonging to Request A drops, Request A stalls, but Requests B, C, and D continue receiving their packets uninterrupted. 

## The Unexpected Reality: Tooling Immaturity
- A plot twist: When we scaled the degraded network test to 50 and 100 concurrent HTTP/3 users, our `k6` client completely crashed with a `SIGSEGV` (segmentation fault).
- *Why?* The community `xk6-http3` extension panicked when trying to process metrics for dropped UDP packets.
- **Takeaway**: While the QUIC protocol is robust, the developer ecosystem and load testing tools for HTTP/3 are still catching up. It is difficult to stress-test HTTP/3 at enterprise scale today without running into edge-case bugs in the tooling.

## Conclusion
- Did HTTP/3 live up to the hype? **Yes and No.**
- **Yes**, it structurally eliminates Head-of-Line Blocking and provides massive latency benefits for clients on poor networks (e.g., mobile apps, IoT).
- **No**, it is not a magic bullet for internal microservices, and the tooling ecosystem requires significant investment before it reaches parity with HTTP/2.

## Call to Action
- Link to this GitHub repository.
- Encourage readers to clone it, run the `run-all.sh` script, and see the numbers for themselves on their own machines!
