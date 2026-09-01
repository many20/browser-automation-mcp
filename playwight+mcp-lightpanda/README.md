# Lightpanda MCP in Docker

Ein Docker-Compose-Setup mit zwei Containern:

- `lightpanda` – offizielles `lightpanda/browser:nightly`-Image, das den nativen Lightpanda MCP-Server über HTTP bereitstellt.
- `nginx` – offizielles `nginx:alpine`-Image als Reverse-Proxy mit Bearer-Token-Authentifizierung für den MCP-Endpunkt.

Lightpanda ist ein von Grund auf neu entwickelter Headless-Browser für AI Agents und Automation (nicht Chromium-basiert). Er ist deutlich kleiner und schneller als Chromium, bietet aber keine grafische Oberfläche (kein noVNC/VNC).

## Ports

| Port | Dienst                           |
| ---- | -------------------------------- |
| 8931 | Lightpanda MCP HTTP/SSE (`/mcp`) |

## Authentifizierung

Der MCP-Endpunkt (Port `8931`) ist durch einen nginx-Reverse-Proxy mit einem **Bearer-Token** geschützt. Der Token wird über die Umgebungsvariable `MCP_AUTH_TOKEN` gesetzt.

Wenn `MCP_AUTH_TOKEN` leer bleibt, startet nginx ohne gültigen Token-Check (weil `envsubst` eine leere Zeichenkette einsetzt). Für den produktiven Betrieb solltest du daher immer einen Token in `.env` hinterlegen.

In `.env` kannst du einen festen Token hinterlegen:

```dotenv
MCP_AUTH_TOKEN=dein-sicherer-token
```

Clients müssen den Token als `Authorization: Bearer <token>`-Header mitsenden:

```
Authorization: Bearer dein-sicherer-token
```

Ohne gültigen Token antwortet der Endpunkt mit **401 Unauthorized**.

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

Lightpanda bietet einen nativen MCP-HTTP-Transport auf `/mcp` an.

Beispiel-Konfiguration für einen MCP-Client (z. B. VS Code, Claude Desktop, Cursor):

```json
{
  "mcpServers": {
    "lightpanda": {
      "url": "http://localhost:8931/mcp",
      "headers": {
        "Authorization": "Bearer dein-sicherer-token"
      }
    }
  }
}
```

Lightpanda erzeugt pro MCP-Verbindung eine eigene Browsing-Session (Seite, Cookies, Memory). Über den `Mcp-Session-Id`-Header können Clients eine Session wiederaufnehmen oder gemeinsam nutzen. Siehe [Lightpanda MCP-Dokumentation](https://lightpanda.io/docs/open-source/guides/mcp-server).

## Wichtige Hinweise

- Lightpanda ist ein rein headless Browser ohne grafische Oberfläche. Es gibt kein noVNC oder VNC.
- Lightpanda befindet sich im Beta-Stadium. Nicht alle Webseiten oder CDP-Features funktionieren bereits.
- Standardmäßig sendet Lightpanda Telemetrie. Dieses Setup deaktiviert sie über `LIGHTPANDA_DISABLE_TELEMETRY=true`.
- Der native MCP-Modus verwendet keine separate Playwright- oder Chromium-Installation.

## Container stoppen

```bash
docker compose down
```

## Variablen anpassen

Alle Werte können über `.env` oder direkt in `docker-compose.yml` geändert werden:

- `LIGHTPANDA_MCP_PORT` – externer Port des Lightpanda MCP-Servers (im nginx-Container)
- `MCP_AUTH_TOKEN` – Bearer-Token für den MCP-Endpunkt
- `LIGHTPANDA_DISABLE_TELEMETRY` – auf `true` setzen, um Lightpanda-Telemetrie zu deaktivieren

## Verwendung als Browser für Websuche & Web-Recherche

Lightpandas nativer MCP-Server ermöglicht es KI-Agenten und LLMs, einen schlanken Browser für Websuchen und Web-Automatisierungen zu steuern.

### Fähigkeiten des Servers

Lightpanda bietet eigene MCP-Tools für Navigation, Interaktion und Datenextraktion. Die konkrete Tool-Liste findest du in der [offiziellen Lightpanda MCP-Dokumentation](https://lightpanda.io/docs/open-source/guides/mcp-server).

### Konfiguration für KI-Agenten via `AGENTS.md`

Damit ein KI-Assistent (z. B. Copilot, Cursor, Roo Code) den **Lightpanda MCP Server** gezielt als Browser für Recherchen und Websuchen verwendet, kann eine `AGENTS.md` im Projekt- oder Workspace-Root angelegt bzw. ergänzt werden:

```markdown
# Agent Instructions: Web Search & Browsing

Wenn du nach aktuellen Informationen im Web suchen oder Webseiten aufrufen sollst:

1. Verwende die Lightpanda MCP-Tools (`goto`, `search`, `markdown`, `tree`, `click`, `fill`, etc.).
2. Nutze für Suchanfragen vorzugsweise schlanke, textbasierte Suchseiten (z. B. `https://html.duckduckgo.com/html/?q=<suchbegriff>` oder `https://lite.duckduckgo.com/lite/`), um Cookie-Banner und lange Ladezeiten zu vermeiden.
3. Erfasse den Seiteninhalt nach der Navigation mittels `markdown` oder `tree`.
4. Klicke bei Bedarf über `click` auf relevante Suchergebnisse (`backendNodeId`- oder `selector`-basiert) oder navigiere direkt zur Zielseite mit `goto`.
```
