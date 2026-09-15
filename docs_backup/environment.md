# Environment Inspection

## Operating System
Windows with WSL2 (Ubuntu)

## Development Tools
- **Java**: 21.0.12 (Ubuntu WSL) / 21.0.9 (Windows)
- **Build Tool**: Maven 3.9.12 (Ubuntu WSL) / 3.8.5 (Windows)
- **Docker**: 29.4.3 (Windows, via Docker Desktop)
- **Docker Compose**: v5.1.3 (Windows)

## Networking & Proxy Tools
- **curl**: 8.18.0 (Ubuntu WSL)
- **Caddy**: Not found in PATH (neither Windows nor WSL).
- **Networking Tools**: `tc` (iproute2-6.19.0) and `netem` are available in Ubuntu WSL (`/sbin/tc`).
- **OpenSSL**: 3.5.5 (Ubuntu WSL)

## HTTP/3 Support & Limitations
- **curl HTTP/3 Support**: The installed version of `curl` (8.18.0) supports HTTP/2, but **does not** list HTTP/3 or QUIC in its supported features.
- **Caddy**: Not currently installed.
- **Docker WSL Integration**: Docker commands currently fail inside the Ubuntu WSL distro, meaning Docker Desktop's WSL integration is likely not enabled for the Ubuntu profile.

## Recommended Environment for the Experiment
**WSL2 (Ubuntu)** is the definitively better environment for the networking experiment because:
1. `tc` and `netem` operate at the Linux kernel level (using `qdisc`). Network degradation (adding latency/packet loss) is extremely difficult to do reliably on Windows, especially for localhost traffic.
2. By running everything inside WSL, we can apply `tc` rules to the loopback (`lo`) interface or a virtual interface to reliably simulate network degradation.

**How to address the limitations:**
1. **Caddy**: Rather than fighting Docker networking namespaces with `tc` (since Docker integration is off in Ubuntu anyway), I recommend downloading the static Linux binary for Caddy directly into the WSL environment when we reach Checkpoint 3.
2. **HTTP/3 Client**: For Checkpoint 5 and beyond, we will need to either download a statically compiled `curl` that includes HTTP/3 support for Linux, or use a dedicated benchmark tool (e.g., a pre-compiled Go/Rust tool) that natively supports HTTP/3. 

I will await your approval before proceeding to Checkpoint 1 (Project Skeleton).
