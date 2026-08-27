#!/bin/bash
set -e

# Internal port for the MCP server.
MCP_INTERNAL_PORT=8932

# External port mapped by docker-compose.
MCP_PORT="${PLAYWRIGHT_MCP_PORT:-8931}"

# Remote Chromium CDP endpoint.
CHROMIUM_HOST="${CHROMIUM_HOST:-chromium}"
CHROMIUM_CDP_PORT="${CHROMIUM_CDP_PORT:-9223}"
CDP_ENDPOINT="http://${CHROMIUM_HOST}:${CHROMIUM_CDP_PORT}"

# Bearer token for MCP and CDP endpoints (enforced by the separate nginx container).
MCP_AUTH_TOKEN="${MCP_AUTH_TOKEN:-}"
if [ -z "$MCP_AUTH_TOKEN" ]; then
  echo "Warning: MCP_AUTH_TOKEN not set. The nginx container will allow unauthenticated access."
fi

echo "============================================================"
echo " Playwright MCP server"
echo "   HTTP/SSE endpoint (via nginx): http://<docker-host>:${MCP_PORT}/mcp"
echo "   CDP endpoint (via nginx):       http://<docker-host>:${CDP_PORT:-9222}"
echo "   Remote CDP backend:             ${CDP_ENDPOINT}"
echo "============================================================"

# Wait until the remote CDP endpoint is reachable.
for i in {1..30}; do
  if curl -fs "${CDP_ENDPOINT}/json/version" >/dev/null 2>&1; then
    echo "CDP ready at ${CDP_ENDPOINT}"
    break
  fi
  echo "Waiting for CDP at ${CDP_ENDPOINT}..."
  sleep 1
done

# Start the MCP server. It connects to the remote Chromium instance.
exec playwright-mcp \
  --port "${MCP_INTERNAL_PORT}" \
  --host 0.0.0.0 \
  --allowed-hosts '*' \
  --cdp-endpoint "${CDP_ENDPOINT}" \
  --no-sandbox
