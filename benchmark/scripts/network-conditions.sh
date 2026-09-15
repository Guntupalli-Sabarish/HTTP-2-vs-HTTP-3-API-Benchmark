#!/bin/bash
# network-conditions.sh
# Applies, removes, or verifies tc netem rules on the Caddy container's eth0 interface.
# Usage:
#   ./benchmark/scripts/network-conditions.sh apply <delay_ms> <loss_pct>
#       Example: ./benchmark/scripts/network-conditions.sh apply 50 5
#   ./benchmark/scripts/network-conditions.sh remove
#   ./benchmark/scripts/network-conditions.sh verify

set -e

CONTAINER="http-2-vs-http-3-api-benchmark-caddy-1"

# Ensure iproute2 is installed in the container (idempotent)
_ensure_iproute2() {
    docker exec -u root "$CONTAINER" sh -c \
        "which tc >/dev/null 2>&1 || apk add --no-cache iproute2 iproute2-tc >/dev/null 2>&1"
}

_check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
        echo "ERROR: Caddy container '$CONTAINER' is not running."
        echo "Run: docker compose up -d"
        exit 1
    fi
}

case "$1" in
    apply)
        DELAY_MS="${2:-50}"
        LOSS_PCT="${3:-0}"
        _check_container
        _ensure_iproute2
        # Remove existing rule first (ignore error if none exists)
        docker exec -u root "$CONTAINER" sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"
        # Apply new netem rule
        docker exec -u root "$CONTAINER" sh -c \
            "tc qdisc add dev eth0 root netem delay ${DELAY_MS}ms loss ${LOSS_PCT}%"
        echo "Applied: delay=${DELAY_MS}ms, loss=${LOSS_PCT}%"
        # Verify
        docker exec -u root "$CONTAINER" tc qdisc show dev eth0
        ;;

    remove)
        _check_container
        _ensure_iproute2
        docker exec -u root "$CONTAINER" sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"
        echo "Network impairment removed."
        docker exec -u root "$CONTAINER" tc qdisc show dev eth0
        ;;

    verify)
        _check_container
        _ensure_iproute2
        echo "Current tc rules on eth0 in Caddy container:"
        docker exec -u root "$CONTAINER" tc qdisc show dev eth0
        ;;

    *)
        echo "Usage: $0 {apply <delay_ms> <loss_pct> | remove | verify}"
        echo ""
        echo "Scenarios:"
        echo "  $0 apply 0  0    # Scenario A: baseline (no impairment)"
        echo "  $0 apply 50 0    # Scenario B: 50ms latency, no loss"
        echo "  $0 apply 50 1    # Scenario C: 50ms latency, 1% loss"
        echo "  $0 apply 100 3   # Scenario D: 100ms latency, 3% loss"
        echo "  $0 apply 200 5   # Scenario E: 200ms latency, 5% loss"
        exit 1
        ;;
esac
