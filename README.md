# 🚗 EV WebGIS -- Ladeinfrastruktur Bremen

**Geodatenverarbeitung Projekt -- WebGIS mit PostGIS, GeoServer und
OpenLayers**

------------------------------------------------------------------------

## 📘 Projektbeschreibung

Dieses Projekt implementiert ein vollständiges WebGIS zur Visualisierung
öffentlicher Ladepunkte für Elektrofahrzeuge in Bremen.\
Die Anwendung basiert vollständig auf offenen Geodaten- und
WebGIS-Standards (OGC).

Ziel ist die Demonstration einer modernen Geodaten-Pipeline:

-   Speicherung räumlicher Daten in **PostGIS**
-   Bereitstellung über **GeoServer (WMS Web Service)**
-   Interaktive Visualisierung im Browser mittels **OpenLayers**

Datenquelle:\
**Bundesnetzagentur -- Ladesäulenregister (Open Data)**

------------------------------------------------------------------------

## 🧭 Systemarchitektur

Browser (OpenLayers Client) ↓ GeoServer (WMS) ↓ PostgreSQL + PostGIS

### Architektur-Erklärung

1.  **Client (Frontend)**\
    Der Benutzer interagiert mit einer OpenLayers-Karte im Browser.\
    Kartenanfragen werden als WMS Requests gesendet.

2.  **GeoServer (Web Service Layer)**\
    GeoServer stellt die Geodaten als OGC-konformen Web Map Service
    bereit.\
    Zusätzlich werden GetFeatureInfo-Anfragen für Popup-Informationen
    verarbeitet.

3.  **PostGIS (Datenbank)**\
    Die Ladepunktdaten werden als räumliche Punktgeometrien gespeichert
    und effizient abgefragt.

Diese Architektur trennt Darstellung, Service und Datenhaltung klar
voneinander.

------------------------------------------------------------------------

## ✅ Voraussetzungen

-   Docker Desktop
-   Docker Compose
-   Node.js (\>= 18)
-   npm
-   (Optional) PostgreSQL / psql Client

------------------------------------------------------------------------

## 🪟 Windows Local Setup (reproducible)

This project was originally developed on macOS. Docker **named volumes**
(`postgis_data`, `geoserver_data`) live inside the Docker VM and are
**machine-local** — copying the project folder to another computer does **not**
copy the database contents or the GeoServer configuration. On a fresh machine
the containers start and GeoServer opens, but the map shows no stations because
the `public.ladepunkte` table and the `ev:ladepunkte` layer do not exist yet.

The setup script restores everything that the volumes would otherwise carry:

``` powershell
docker compose up -d
.\scripts\setup-local.ps1

cd web
npm install
npm run dev
# open http://localhost:5173
```

`scripts\setup-local.ps1` is **safe and idempotent** — run it as often as you
like. It:

1. verifies Docker is installed and running,
2. starts the Compose services and waits for PostGIS + GeoServer readiness,
3. ensures the PostGIS extension and the `public.ladepunkte` schema,
4. imports `bnetza_min.csv` **only when the table has no valid rows**
   (no duplicate imports),
5. creates/verifies the GeoServer workspace `ev`, the PostGIS datastore, and
   the `ev:ladepunkte` layer,
6. validates WMS, WFS, CQL filtering, GetMap, and GetFeatureInfo.

To force a clean re-import of the CSV (truncates only the application table —
never drops the database or removes volumes):

``` powershell
.\scripts\setup-local.ps1 -ResetData
```

### Important environment notes

- **GeoServer → database host must be `postgis`**, not `localhost`. Inside the
  GeoServer container, `localhost` refers to GeoServer itself. The datastore
  connects using the Docker service name `postgis`.
- **The Vite proxy targets `http://127.0.0.1:8080`** (in `web/vite.config.js`).
  `localhost` can resolve to IPv6 `::1` on Windows and break the proxy, so the
  IPv4 literal is used deliberately.

### Diagnostics

``` powershell
docker compose ps
docker compose logs --tail=100 postgis
docker compose logs --tail=100 geoserver
```

------------------------------------------------------------------------

## 🎨 Marker styling (GeoServer SLD)

Stations are rendered with a scale-dependent GeoServer style instead of the
default squares:

- **AC** stations → **blue** circles (`#2F80ED`), slightly smaller.
- **DC** stations → **orange** circles (`#F97316`), slightly larger and more
  prominent — matching the frontend legend.
- Marker size grows as you zoom in (regional → city → local scale bands), and
  markers are semi-transparent with a thin dark outline so dense clusters stay
  readable.

The style is stored in the repository at:

```text
geoserver/styles/ev-charging-points.sld
```

`scripts\setup-local.ps1` (via `configure-geoserver.ps1`) installs or updates
the workspace style `ev:ev-charging-points` and sets it as the default style of
`ev:ladepunkte`. It is idempotent — editing the SLD and re-running updates the
existing style in place without creating duplicates.

------------------------------------------------------------------------

## 🐳 Backend starten (PostGIS + GeoServer)

``` bash
docker compose up -d
docker ps
```

Container: - postgis - geoserver

------------------------------------------------------------------------

## 🌍 GeoServer Zugang

URL: http://localhost:8080/geoserver

Login: Benutzer: admin
Passwort: geoserver

------------------------------------------------------------------------

## 🗄️ PostGIS Zugang

Host: localhost
Port: 5432
Datenbank: gisdb
User: gisuser
Passwort: gispass

Test:

``` bash
psql -h localhost -U gisuser -d gisdb
```

------------------------------------------------------------------------

## 💻 Web-Frontend starten

``` bash
cd web
npm install
npm run dev
```

Danach öffnen: http://localhost:5173

------------------------------------------------------------------------

## 🔁 GeoServer Proxy (Vite)

Requests wie: /geoserver/ev/wms

werden weitergeleitet zu: http://127.0.0.1:8080/geoserver

Konfiguration: web/vite.config.js

------------------------------------------------------------------------

## 🧠 Implementierte Funktionen

### Kartenvisualisierung

-   OpenStreetMap Basiskarte
-   GeoServer WMS Layer
-   Serverseitige Filterung (CQL_FILTER)

### Interaktion

-   Klick → Popup via GetFeatureInfo
-   Hover Tooltip
-   Ladeanimation während Datenabfrage

### UX & Performance

-   Zoomabhängige Anzeige (AC erst ab Zoom ≥ 9)
-   Reduzierte Serveranfragen
-   Serverseitige Datenfilterung

------------------------------------------------------------------------

## 📊 Datenverarbeitung

Die Originaldaten der Bundesnetzagentur wurden:

1.  bereinigt (CSV Processing),
2.  auf die benötigten Attribute reduziert,
3.  als `bnetza_min.csv` für die reproduzierbare lokale Einrichtung gespeichert,
4.  in PostGIS importiert,
5.  als FeatureType im GeoServer veröffentlicht.

Der größere Rohdatenexport `bnetza_data.csv` ist nicht Teil des Repositorys.
`prepare_bnetza.py` kann ihn bei Bedarf erneut in die vorbereitete Datei
überführen.

------------------------------------------------------------------------

## 📁 Projektstruktur

```text
ev-webgis/
├── docker-compose.yml
├── bnetza_min.csv
├── prepare_bnetza.py
├── geoserver/
│   └── styles/
│       └── ev-charging-points.sld
├── scripts/
│   ├── setup-local.ps1
│   ├── import-bnetza.ps1
│   ├── configure-geoserver.ps1
│   ├── configure-geoserver-style.ps1
│   ├── validate-local.ps1
│   └── sql/
│       ├── create-ladepunkte.sql
│       └── import-bnetza.sql
├── web/
│   ├── public/
│   ├── src/
│   ├── index.html
│   ├── package.json
│   ├── package-lock.json
│   └── vite.config.js
├── .gitignore
└── README.md
```

------------------------------------------------------------------------

## 🔐 Hinweis zu Zugangsdaten

Die Zugangsdaten dienen ausschließlich zu lokalen Demonstrationszwecken.
Keine Produktionsumgebung.

------------------------------------------------------------------------

## 👨‍🎓 Kontext

Modul: Geodatenverarbeitung\
Thema: WebGIS & Web Services

Technologien: - PostGIS - GeoServer - OpenLayers - Docker - OGC WMS
Standard

------------------------------------------------------------------------

## 🎯 Projektergebnis

Das Projekt demonstriert erfolgreich die vollständige Umsetzung eines
WebGIS-Systems unter Verwendung offener Geostandards.
