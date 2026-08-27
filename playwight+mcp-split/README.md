# Playwright MCP + desktop-lite (noVNC) in Docker

Ein Docker-Compose-Setup mit drei Containern:

- `chromium` – basiert auf dem offiziellen `mcr.microsoft.com/playwright`-Image und enthält nur den headful Chromium-Browser sowie `desktop-lite` (TigerVNC + noVNC + Fluxbox).
- `mcp` – schlankes Node.js-Image mit `@playwright/mcp`. Verbindet sich über CDP mit dem `chromium`-Container.
- `nginx` – offizielles `nginx:alpine`-Image als Reverse-Proxy mit Bearer-Token-Authentifizierung für die MCP- und CDP-Endpunkte.

Die Container kommunizieren über ein gemeinsames Docker-Netzwerk. Die Ports für MCP und CDP werden ausschließlich vom nginx-Container nach außen freigegeben.

## Ports

| Port | Dienst                           |
| ---- | -------------------------------- |
| 8931 | Playwright MCP HTTP/SSE (`/mcp`) |
| 9222 | Chrome DevTools Protocol (CDP)   |
| 6080 | noVNC Web-Client                 |
| 5901 | TigerVNC-Server                  |

## Authentifizierung

Sowohl der MCP-Endpunkt (Port `8931`) als auch der CDP-Endpunkt (Port `9222`) sind durch einen nginx-Reverse-Proxy mit einem **Bearer-Token** geschützt. Der Token wird über die Umgebungsvariable `MCP_AUTH_TOKEN` gesetzt.

Wenn `MCP_AUTH_TOKEN` leer bleibt, startet nginx ohne gültigen Token-Check (weil `envsubst` eine leere Zeichenkette einsetzt). Für den produktiven Betrieb solltest du daher immer einen Token in `.env` hinterlegen.

In `.env` kannst du einen festen Token hinterlegen:

```dotenv
MCP_AUTH_TOKEN=dein-sicherer-token
```

Clients müssen den Token als `Authorization: Bearer <token>`-Header mitsenden:

```
Authorization: Bearer dein-sicherer-token
```

Ohne gültigen Token antworten beide Endpunkte mit **401 Unauthorized**.

## Schnellstart

```bash
# 1. Konfiguration anpassen (optional)
cp .env.example .env

# 2. Image bauen und Container starten
docker compose up --build -d

# 3. Logs anschauen
docker compose logs -f
```

## Verbindung zum MCP-Server

Der MCP-Server bietet einen HTTP-Transport auf `/mcp` an.

Beispiel-Konfiguration für einen MCP-Client (z. B. VS Code, Claude Desktop, Cursor):

```json
{
  "mcpServers": {
    "playwright": {
      "url": "http://localhost:8931/mcp",
      "headers": {
        "Authorization": "Bearer dein-sicherer-token"
      }
    }
  }
}
```

Chromium läuft als persistenter Prozess mit aktiviertem CDP im `chromium`-Container. Der `mcp`-Container verbindet sich über das Docker-Netzwerk mit dem CDP-Endpunkt, sodass das Browserfenster auch bei Wechsel der MCP-Verbindung erhalten bleibt.

## noVNC verwenden

1. Im Browser öffnen: `http://localhost:6080/`
2. Auf **Connect** klicken.
3. Passwort eingeben (Standard: `vscode`, konfigurierbar über `VNC_PASSWORD`).

Danach siehst du den Fluxbox-Desktop. Chromium läuft darin als persistenter Prozess.

## Wichtige Hinweise

- Der `chromium`-Container läuft als `root` und startet Chromium mit `--no-sandbox`. Das ist für eine lokale Entwicklungs-/Debug-Umgebung gedacht, nicht für den Zugriff auf nicht vertrauenswürdige Seiten.
- `shm_size: 2gb` und `init: true` im `chromium`-Service entsprechen den Empfehlungen aus der [Playwright-Docker-Dokumentation](https://playwright.dev/docs/docker).
- Die Browser-Version im `chromium`-Image muss mit der Version kompatibel sein, die `@playwright/mcp` intern verwendet. Falls es zu Fehlern kommt, das Playwright-Base-Image (`v1.62.0-noble`) oder die MCP-Version in `.env` anpassen.
- Chromium lauscht im Container auf `0.0.0.0:9223`, damit der `mcp`-Container und nginx über das Docker-Netzwerk darauf zugreifen können.

## Container stoppen

```bash
docker compose down
```

## Variablen anpassen

Alle Werte können über `.env` oder direkt in `docker-compose.yml` geändert werden:

- `PLAYWRIGHT_MCP_VERSION` – MCP-Version für den `mcp`-Container
- `PLAYWRIGHT_MCP_PORT` – externer Port des MCP-Servers (im nginx-Container)
- `CDP_PORT` – externer Port des Chrome DevTools Protocol-Endpunkts (im nginx-Container)
- `MCP_AUTH_TOKEN` – Bearer-Token für MCP- und CDP-Endpunkte
- `NOVNC_PORT` – Port des noVNC-Webclients
- `VNC_PORT` – Port des VNC-Servers
- `VNC_PASSWORD` – VNC-Zugangspasswort
- `VNC_RESOLUTION` – Desktop-Auflösung, z. B. `1920x1080x16`
- `SHM_SIZE` – Größe von `/dev/shm` im `chromium`-Container

## Verwendung als Browser für Websuche & Web-Recherche

Der Playwright MCP-Server ermöglicht es KI-Agenten und LLMs, einen echten Browser für Websuchen und Web-Automatisierungen zu steuern.

### Fähigkeiten des Servers

- **Navigation & Tabs:** Seiten aufrufen (`browser_navigate`), vor-/zurückblättern, Tabs verwalten (`browser_tabs`).
- **Interaktion:** Klicks (`browser_click`), Texteingabe & Formulare (`browser_type`, `browser_fill_form`), Dropdowns (`browser_select_option`), Tastatureingaben (`browser_press_key`).
- **Inhalte erfassen:** Strukturierte Snapshots für LLMs (`browser_snapshot`), Textsuche im Snapshot (`browser_find`), Screenshots (`browser_take_screenshot`).
- **Analyse & Scripting:** Netzwerk-Traffic (`browser_network_requests`), Console-Logs (`browser_console_messages`), JavaScript-Ausführung im Seitenkontext (`browser_evaluate`).

### Konfiguration für KI-Agenten via `AGENTS.md`

Damit ein KI-Assistent (z. B. Copilot, Cursor, Roo Code) den Playwright MCP Server gezielt als Browser für Recherchen und Websuchen verwendet, kann eine `AGENTS.md` im Projekt- oder Workspace-Root angelegt bzw. ergänzt werden:

```markdown
# Agent Instructions: Web Search & Browsing

Wenn du nach aktuellen Informationen im Web suchen oder Webseiten aufrufen sollst:

1. Verwende die Playwright MCP-Tools (`browser_navigate`, `browser_snapshot`, `browser_click`, etc.).
2. Nutze für Suchanfragen vorzugsweise schlanke, textbasierte Suchseiten (z. B. `https://html.duckduckgo.com/html/?q=<suchbegriff>` oder `https://lite.duckduckgo.com/lite/`), um Cookie-Banner und lange Ladezeiten zu vermeiden.
3. Erfasse den Seiteninhalt nach der Navigation mittels `browser_snapshot`.
4. Klicke bei Bedarf über `browser_click` auf relevante Suchergebnisse (`ref`-IDs aus dem Snapshot) oder navigiere direkt zur Zielseite.
```
