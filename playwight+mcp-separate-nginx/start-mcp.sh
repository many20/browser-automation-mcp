#!/bin/bash
set -e

# Locate the Chromium build shipped with the Playwright image.
CHROME_EXE=$(ls /ms-playwright/chromium-*/chrome-linux64/chrome | head -n1)

# Internal ports (not exposed directly; the external nginx container proxies them).
CDP_INTERNAL_PORT=9223
MCP_INTERNAL_PORT=8932

# External ports mapped by docker-compose.
CDP_PORT="${CDP_PORT:-9222}"
MCP_PORT="${PLAYWRIGHT_MCP_PORT:-8931}"

# Bearer token for MCP and CDP endpoints (enforced by the separate nginx container).
MCP_AUTH_TOKEN="${MCP_AUTH_TOKEN:-}"
if [ -z "$MCP_AUTH_TOKEN" ]; then
  echo "Warning: MCP_AUTH_TOKEN not set. The nginx container will allow unauthenticated access."
fi

echo "============================================================"
echo " Playwright MCP server"
echo "   HTTP/SSE endpoint (via nginx): http://<docker-host>:${MCP_PORT}/mcp"
echo "   Browser executable: ${CHROME_EXE}"
echo "   CDP endpoint (via nginx):       http://<docker-host>:${CDP_PORT}"
echo "   noVNC web client:              http://<docker-host>:${NOVNC_PORT}/"
echo "   VNC server:                    <docker-host>:${VNC_PORT}"
echo "   VNC password:                  ${VNC_PASSWORD:-(none)}"
echo "============================================================"

# Start a persistent, headful Chromium instance with remote debugging.
# It binds to 127.0.0.1 only; nginx proxies external access.
"${CHROME_EXE}" \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --remote-debugging-port="${CDP_INTERNAL_PORT}" \
  --remote-debugging-address=127.0.0.1 \
  --window-size=1280,720 \
  --display="${DISPLAY:-:1}" \
  about:blank &

CHROME_PID=$!
echo "Chromium started with PID ${CHROME_PID}"

# Wait until the CDP endpoint is reachable.
CDP_ENDPOINT="http://127.0.0.1:${CDP_INTERNAL_PORT}"
for i in {1..30}; do
  if curl -fs "${CDP_ENDPOINT}/json/version" >/dev/null 2>&1; then
    echo "CDP ready at ${CDP_ENDPOINT}"
    break
  fi
  sleep 0.5
done

# Start the MCP server on localhost only; nginx exposes it externally with auth.
exec playwright-mcp \
  --port "${MCP_INTERNAL_PORT}" \
  --host 127.0.0.1 \
  --allowed-hosts '*' \
  --cdp-endpoint "${CDP_ENDPOINT}" \
  --no-sandbox
