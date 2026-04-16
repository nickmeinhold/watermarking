#!/usr/bin/env bash
#
# Build and start the watermarking API in a Docker container for local testing.
#
# Usage:
#   ./scripts/start-docker.sh          # Build and start
#   ./scripts/start-docker.sh --stop   # Stop the container
#
# The container runs with:
#   - API_KEY=test-battery-key (matches config.js default)
#   - RATE_LIMIT_MAX=9999 (effectively no rate limiting for tests)
#   - Port 8080 exposed
#

set -euo pipefail

CONTAINER_NAME="watermark-test-battery"
IMAGE_NAME="watermarking-api"
API_PORT="${TEST_API_PORT:-8080}"
API_KEY="${TEST_API_KEY:-test-battery-key}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
API_DIR="$PROJECT_ROOT/watermarking-api"

# Stop command
if [[ "${1:-}" == "--stop" ]]; then
  echo "Stopping $CONTAINER_NAME..."
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  echo "Stopped."
  exit 0
fi

# Stop any existing container
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Build the Docker image
echo "=== Building watermarking API Docker image ==="
echo "This may take a few minutes on first build..."
cd "$API_DIR"

# Ensure build context is prepared (copies C++ sources)
if [[ -f build.sh ]]; then
  bash build.sh
else
  echo "ERROR: build.sh not found in $API_DIR"
  exit 1
fi

# Build with AMD64 platform (required even on Apple Silicon, matches production)
docker build --platform linux/amd64 -t "$IMAGE_NAME" .

# Start the container
echo ""
echo "=== Starting container ==="
docker run -d \
  --name "$CONTAINER_NAME" \
  --platform linux/amd64 \
  -p "$API_PORT:8080" \
  -e "API_KEY=$API_KEY" \
  -e "RATE_LIMIT_MAX=9999" \
  -e "GOOGLE_APPLICATION_CREDENTIALS=/dev/null" \
  "$IMAGE_NAME"

# Wait for health check
echo "Waiting for API to be ready..."
MAX_WAIT=60
WAITED=0
while [[ $WAITED -lt $MAX_WAIT ]]; do
  if curl -sf "http://localhost:$API_PORT/health" > /dev/null 2>&1; then
    echo "API is healthy at http://localhost:$API_PORT"
    echo ""
    echo "Run tests with:"
    echo "  cd test-battery && npm test"
    echo ""
    echo "Stop with:"
    echo "  ./scripts/start-docker.sh --stop"
    exit 0
  fi
  sleep 2
  WAITED=$((WAITED + 2))
  echo "  ...waiting ($WAITED/$MAX_WAIT seconds)"
done

echo ""
echo "ERROR: API did not become healthy within ${MAX_WAIT}s"
echo "Check container logs: docker logs $CONTAINER_NAME"
docker logs --tail 20 "$CONTAINER_NAME"
exit 1
