#!/bin/bash
# verify-http3.sh
# Verifies that Caddy is negotiating HTTP/3 over QUIC.
# Must be run from the project root.
# Requires Docker to be running.

set -e

echo "=== HTTP/3 Protocol Verification ==="

CADDY_CONTAINER="http-2-vs-http-3-api-benchmark-caddy-1"
URL="https://localhost:8443/api/health"

# Check Caddy container is running
if ! docker ps --format '{{.Names}}' | grep -q "$CADDY_CONTAINER"; then
    echo "ERROR: Caddy container '$CADDY_CONTAINER' is not running."
    echo "Run: docker compose up -d"
    exit 1
fi

echo "Sending request via ymuski/curl-http3 (shares Caddy network namespace)..."
RESULT=$(docker run --rm \
    --network "container:${CADDY_CONTAINER}" \
    ymuski/curl-http3 \
    curl -sk --http3 \
    -o /dev/null \
    -w "HTTP_VERSION=%{http_version} STATUS=%{http_code}" \
    "$URL")

HTTP_VERSION=$(echo "$RESULT" | grep -oP 'HTTP_VERSION=\K[^\s]+')
STATUS=$(echo "$RESULT" | grep -oP 'STATUS=\K[^\s]+')

echo "HTTP Version negotiated: $HTTP_VERSION"
echo "HTTP Status: $STATUS"

if [ "$HTTP_VERSION" = "3" ] && [ "$STATUS" = "200" ]; then
    echo "PASS: HTTP/3 verified."
    exit 0
else
    echo "FAIL: Expected HTTP/3 (got $HTTP_VERSION) with status 200 (got $STATUS)."
    exit 1
fi
