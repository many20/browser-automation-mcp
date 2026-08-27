#!/bin/bash
set -e

# Locate the Chromium build shipped with the Playwright image.
CHROME_EXE=$(ls /ms-playwright/chromium-*/chrome-linux64/chrome | head -n1)

# CDP port. Bind to 0.0.0.0 so the MCP server container can reach it.
CDP_PORT="${CDP_PORT:-9223}"

echo "============================================================"
echo " Playwright Chromium"
echo "   Browser executable: ${CHROME_EXE}"
echo "   CDP endpoint:       http://<docker-host>:${CDP_PORT}"
echo "   noVNC web client:  http://<docker-host>:${NOVNC_PORT}/"
echo "   VNC server:        <docker-host>:${VNC_PORT}"
echo "   VNC password:      ${VNC_PASSWORD:-(none)}"
echo "============================================================"

# Start a persistent, headful Chromium instance with remote debugging.
# It binds to 0.0.0.0 so other containers in the Docker network can connect.
exec "${CHROME_EXE}" \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --remote-debugging-port="${CDP_PORT}" \
  --remote-debugging-address=0.0.0.0 \
  --window-size=1280,720 \
  --display="${DISPLAY:-:1}" \
  about:blank
