#!/bin/bash
# verify-http2.sh
# Verifies that Caddy is negotiating HTTP/2 via ALPN.
# Must be run from the project root.

set -e

echo "=== HTTP/2 Protocol Verification ==="

CONTAINER="http-2-vs-http-3-api-benchmark-caddy-1"
URL="https://localhost:8443/api/health"

# Check container is running
if ! docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
    echo "ERROR: Caddy container '$CONTAINER' is not running."
    echo "Run: docker compose up -d"
    exit 1
fi

echo "Sending request via curl --http2 inside the Caddy container..."
RESULT=$(docker exec "$CONTAINER" curl -sk --http2 -o /dev/null -w "HTTP_VERSION=%{http_version} STATUS=%{http_code}" "$URL")
HTTP_VERSION=$(echo "$RESULT" | grep -oP 'HTTP_VERSION=\K[^\s]+')
STATUS=$(echo "$RESULT" | grep -oP 'STATUS=\K[^\s]+')

echo "HTTP Version negotiated: $HTTP_VERSION"
echo "HTTP Status: $STATUS"

if [ "$HTTP_VERSION" = "2" ] && [ "$STATUS" = "200" ]; then
    echo "PASS: HTTP/2 verified."
    exit 0
else
    echo "FAIL: Expected HTTP/2 (got $HTTP_VERSION) with status 200 (got $STATUS)."
    exit 1
fi
