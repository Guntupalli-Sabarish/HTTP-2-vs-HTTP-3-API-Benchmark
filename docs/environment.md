# Environment inspection

Inspection date: 2026-09-15

## Host operating system

| Item | Observed value |
| --- | --- |
| OS | Windows 11 (reported by Java); Windows NT build `10.0.26200.0` |
| Architecture | `amd64` |
| CPU and RAM | Could not be inspected: Windows CIM queries returned `Access denied` in this environment. |

## Development tools

| Tool | Observed value | Status |
| --- | --- | --- |
| Java | Oracle JDK `21.0.9` LTS (64-bit) | Available |
| Maven | `3.8.5` | Available |
| Gradle | Not found | Not needed; Maven is the selected build tool. |
| Docker CLI | `29.4.3` | Installed, but daemon unavailable. |
| Docker Compose | `v5.1.3` | Installed; cannot currently use it because the Docker daemon is unavailable. |
| curl | Windows `8.21.0`, Schannel | Available, but this build lists neither HTTP/2 nor HTTP/3 support. |
| Caddy | Not found | Missing |
| OpenSSL | Not found | Missing |

## Networking tools and HTTP/3 suitability

| Capability | Status | Evidence / implication |
| --- | --- | --- |
| WSL | Not verifiable from this session | `wsl.exe --status` and distribution listing returned `E_ACCESSDENIED`. |
| Linux `tc` / `netem` | Not available on the Windows host | They are Linux traffic-control utilities; neither command is available here. |
| HTTP/2 client verification | Blocked | The installed curl feature list does not contain `HTTP2`, so `curl --http2-only` cannot provide the required proof. |
| HTTP/3 client verification | Blocked | The installed curl feature list does not contain `HTTP3`, so `curl --http3-only` cannot provide the required proof. |
| Caddy edge server | Blocked | No `caddy` executable is installed. |
| Docker-based testbed | Temporarily blocked | Docker cannot connect to `//./pipe/docker_engine`; start Docker Desktop (or another Docker daemon) before using Compose. |

## Assessment

The host is suitable for building and testing the Spring Boot application with Java 21 and Maven. It is **not currently suitable for a reliable HTTP/2-versus-HTTP/3 network experiment**: the edge server, protocol-capable client, and Linux impairment tooling are unavailable or inaccessible.

For this experiment, **WSL2 is the preferred environment** once it is accessible and has a Linux distribution installed. It keeps the API, Caddy, HTTP/2 client, HTTP/3 client, and `tc netem` on one machine and supports applying comparable traffic shaping to TCP and UDP/QUIC. A Linux Docker/Compose setup within WSL2 is also acceptable if Docker is intentionally used and its daemon is running.

Running the HTTP/2 and HTTP/3 measurements directly on native Windows would require separate replacements for Caddy, an HTTP/3-capable client, and `tc/netem`; that would add avoidable variables and weaken reproducibility.

## Required changes before later checkpoints

No software was installed or configured during this checkpoint. Before proceeding beyond the project skeleton, the experiment needs:

1. An accessible WSL2 Linux distribution (recommended), or an explicitly chosen Linux Docker environment with a running daemon.
2. Caddy for the reverse proxy.
3. An HTTP/3-capable client such as a curl build compiled with HTTP/3 support.
4. Linux `iproute2` traffic control (`tc`) with the `netem` qdisc.
5. OpenSSL or Caddy's local certificate mechanism for local TLS.

## Commands run

```powershell
java -version
mvn -version
gradle -version
docker version --format '{{.Client.Version}}'
docker compose version
curl.exe --version
caddy version
wsl.exe --status
wsl.exe -l -v
openssl version
Get-Command tc,netem
```

Hardware queries using `Get-CimInstance Win32_OperatingSystem`, `Win32_Processor`, and `Win32_ComputerSystem` were also attempted, but the host denied access.
