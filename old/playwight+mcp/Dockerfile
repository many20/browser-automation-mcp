# syntax=docker/dockerfile:1

# Offizielles Playwright-Image mit Browsern und Systemabhängigkeiten.
# Wir installieren darauf den MCP-Server und desktop-lite (VNC/noVNC).
FROM mcr.microsoft.com/playwright:v1.62.0-noble

LABEL org.opencontainers.image.title="Playwright MCP with desktop-lite / noVNC"
LABEL org.opencontainers.image.description="Headful Playwright MCP server accessible via HTTP/SSE with noVNC remote desktop"

ENV DEBIAN_FRONTEND=noninteractive

# --- Build args ---------------------------------------------------------------
ARG PLAYWRIGHT_MCP_VERSION=0.0.79
ARG NOVNC_VERSION=1.6.0

ARG VNC_PASSWORD=vscode
ARG NOVNC_PORT=6080
ARG VNC_PORT=5901
ARG USERNAME=root

# --- Runtime env vars ---------------------------------------------------------
ENV PLAYWRIGHT_MCP_PORT=8931 \
    PLAYWRIGHT_MCP_HOST=0.0.0.0 \
    DISPLAY=:1 \
    VNC_RESOLUTION=1920x1080x16 \
    VNC_PASSWORD=${VNC_PASSWORD} \
    NOVNC_PORT=${NOVNC_PORT} \
    VNC_PORT=${VNC_PORT}

# --- Install Playwright MCP server (uses the browsers already in the image) ---
RUN npm install -g @playwright/mcp@${PLAYWRIGHT_MCP_VERSION} \
    && rm -rf /ms-playwright/firefox-* /ms-playwright/webkit-* \
    && npm cache clean --force

# --- Install devcontainers desktop-lite feature (TigerVNC + noVNC + Fluxbox) --
RUN curl -fsSL https://raw.githubusercontent.com/devcontainers/features/main/src/desktop-lite/install.sh \
    -o /tmp/desktop-lite-install.sh \
    && chmod +x /tmp/desktop-lite-install.sh \
    && USERNAME=${USERNAME} \
    PASSWORD=${VNC_PASSWORD} \
    WEBPORT=${NOVNC_PORT} \
    VNCPORT=${VNC_PORT} \
    NOVNCVERSION=${NOVNC_VERSION} \
    /tmp/desktop-lite-install.sh \
    && rm /tmp/desktop-lite-install.sh

# --- Install nginx reverse proxy for authenticated MCP/CDP access ------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

COPY nginx.conf.template /etc/nginx/nginx.conf.template

# --- Startup helper -----------------------------------------------------------
COPY start-mcp.sh /usr/local/bin/start-mcp.sh
RUN chmod +x /usr/local/bin/start-mcp.sh

EXPOSE 8931 6080 5901 9222

ENTRYPOINT ["/usr/local/share/desktop-init.sh"]
CMD ["/usr/local/bin/start-mcp.sh"]
