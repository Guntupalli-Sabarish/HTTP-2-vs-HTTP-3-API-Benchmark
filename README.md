# HTTP/2 vs HTTP/3 API Benchmark

This repository contains an end-to-end reproducible experiment comparing **HTTP/2** (over TCP) and **HTTP/3** (over QUIC) performance against a Spring Boot REST API, specifically focusing on behavior during network degradation (latency and packet loss).

It serves as the technical testbed for the blog post:
**"HTTP/2 vs HTTP/3: I Built the Same API Twice. Here's What the Network Actually Did."**

## Architecture

The benchmark uses Docker Compose to spin up:
1. **Spring Boot API** (`:8080`)
2. **Caddy Reverse Proxy** (`:8443`) terminating both HTTP/2 and HTTP/3.
3. **Custom `k6` Client** with the `xk6-http3` extension for load generation.

All HTTP/2 and HTTP/3 requests are routed by Caddy to the exact same Spring Boot container, ensuring zero application-level bias.

## Prerequisites

- **Docker** and **Docker Compose**
- **Node.js** (for parsing results to CSV)
- **PowerShell** or **Bash** (for running the automation scripts)

## How to Reproduce

### 1. Build the HTTP/3 benchmarking client
Standard `k6` does not support HTTP/3 out-of-the-box. We have provided a Dockerfile to build `k6` with the community `xk6-http3` plugin:

```bash
docker build -t custom-k6 -f benchmark/Dockerfile.k6 .
```

### 2. Start the Server Stack
Start the Spring Boot API and Caddy reverse proxy:

```bash
docker compose up -d --build
```

### 3. Run the Benchmark Suite

The suite will automatically:
- Run a baseline test (0ms latency, 0% loss)
- Artificially degrade the Caddy network interface using `tc netem` (50ms latency, 5% packet loss)
- Run a degraded test
- Parse the results into a CSV

**On Windows (PowerShell):**
```powershell
.\benchmark\scripts\run-all.ps1
```

**On Linux/macOS (Bash):**
```bash
bash ./benchmark/scripts/run-all.sh
```

*(Note: The benchmark takes about 10 minutes to complete. The degraded HTTP/3 tests at higher concurrencies may output panic errors—this is an expected limitation of the `xk6-http3` plugin under packet loss and is part of our findings!)*

### 4. View Results

Once the scripts complete, your parsed data will be available at:
`benchmark/results/full-results.csv`

You can import this CSV into Excel, Google Sheets, or Pandas for data visualization.

---
**Disclaimer**: This project intentionally runs the client and server on the same host machine to maintain a tightly controlled baseline environment before artificially introducing network latency via Linux Traffic Control (`tc`).
