# EV Charging Infrastructure WebGIS

A full-stack geospatial web application for visualizing public electric-vehicle charging infrastructure across Germany.

The project combines a responsive OpenLayers frontend with GeoServer, PostgreSQL/PostGIS and Docker. Charging-station data from the German Federal Network Agency is imported into PostGIS, published through OGC services and rendered as an interactive map with server-side filtering.

## Overview

The application demonstrates a complete geospatial data pipeline:

```text
Bundesnetzagentur CSV
        ↓
PostgreSQL + PostGIS
        ↓
GeoServer (WMS / WFS / GetFeatureInfo)
        ↓
OpenLayers web application
```

The prepared dataset contains more than 100,000 charging-station records with valid point geometries in EPSG:4326.

## Features

### Interactive map

- OpenStreetMap basemap
- GeoServer WMS charging-station layer
- AC and DC charging filters using `CQL_FILTER`
- Scale-dependent station rendering
- Station details through `GetFeatureInfo`
- Desktop hover tooltip
- Map reset and browser geolocation actions
- Live GeoServer connection status

### Responsive interface

- Full-screen dark geospatial dashboard
- Desktop control panel
- Mobile filter drawer
- Accessible keyboard navigation and focus states
- Reduced-motion support
- Non-blocking status and error messages

### Data and service layer

- PostgreSQL/PostGIS spatial storage
- GeoServer WMS and WFS publication
- Reproducible CSV import
- Automated GeoServer workspace, datastore, layer and style setup
- Safe and idempotent PowerShell setup scripts
- Validation for WMS, WFS, CQL filtering and `GetFeatureInfo`

## Charging-station styling

The GeoServer layer uses a scale-dependent SLD style:

- **AC stations:** blue circular markers
- **DC stations:** orange circular markers with slightly larger symbols
- Marker sizes increase from regional to local map scales
- Semi-transparent fills and thin dark outlines preserve readability in dense areas

The style is stored at:

```text
geoserver/styles/ev-charging-points.sld
```

The local setup process installs or updates the workspace style `ev:ev-charging-points` and assigns it to `ev:ladepunkte` automatically.

## Technology stack

### Geospatial and backend

- PostgreSQL
- PostGIS
- GeoServer
- OGC WMS
- OGC WFS
- CQL filters
- Docker Compose

### Frontend

- OpenLayers
- Vanilla JavaScript
- Vite
- HTML5
- CSS3
- OpenStreetMap

### Automation and data preparation

- PowerShell
- SQL
- Python
- CSV processing

## Data source

The application uses public charging-infrastructure data from the **Bundesnetzagentur Ladesäulenregister**.

The repository includes the prepared file:

```text
bnetza_min.csv
```

The larger raw export is intentionally not included. `prepare_bnetza.py` documents the preprocessing workflow used to create the reduced dataset.

## Local setup on Windows

### Requirements

- Docker Desktop
- Docker Compose
- A current Node.js LTS release
- npm
- Windows PowerShell or PowerShell 7

### 1. Start the services

From the repository root:

```powershell
docker compose up -d
```

### 2. Configure PostGIS and GeoServer

```powershell
.\scripts\setup-local.ps1
```

The setup script:

1. verifies that Docker is available,
2. waits for PostGIS and GeoServer,
3. creates the PostGIS schema when required,
4. imports `bnetza_min.csv` only when no valid rows exist,
5. configures the GeoServer workspace and datastore,
6. publishes `ev:ladepunkte`,
7. installs the custom SLD style,
8. validates WMS, WFS, CQL and `GetFeatureInfo`.

The script is safe to run repeatedly and does not duplicate imported data or GeoServer resources.

To intentionally rebuild the application table from the prepared CSV:

```powershell
.\scripts\setup-local.ps1 -ResetData
```

This option affects only the application table. It does not remove the database or Docker volumes.

### 3. Start the frontend

```powershell
cd web
npm install
npm run dev
```

Open:

```text
http://localhost:5173
```

GeoServer is available at:

```text
http://127.0.0.1:8080/geoserver
```

## Important environment notes

### Docker volumes

The `postgis_data` and `geoserver_data` named volumes are machine-local. Copying the repository to another computer does not copy the database contents or GeoServer configuration.

Running `scripts/setup-local.ps1` restores the required local resources from the files stored in the repository.

### Container networking

GeoServer connects to PostgreSQL through the Docker service name:

```text
postgis
```

Using `localhost` or `127.0.0.1` inside the GeoServer container would point back to the GeoServer container itself.

### Vite proxy

The frontend forwards `/geoserver` requests to:

```text
http://127.0.0.1:8080
```

The IPv4 address is used deliberately because `localhost` may resolve to IPv6 `::1` on Windows.

## Filtering behavior

The frontend applies server-side CQL filters to the WMS layer:

```text
AC only:      anschlussart='AC'
DC only:      anschlussart='DC'
AC and DC:    anschlussart='AC' OR anschlussart='DC'
None:         1=0
```

For performance, AC stations are hidden below zoom level 9. The user's AC preference is preserved and restored when returning to a supported zoom level.

## Project structure

```text
ev-charging-map/
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

## Diagnostics

Check service status:

```powershell
docker compose ps
```

Inspect recent logs:

```powershell
docker compose logs --tail=100 postgis
docker compose logs --tail=100 geoserver
```

Build the frontend:

```powershell
cd web
npm run build
```

## Local development credentials

The credentials in `docker-compose.yml` are intended only for local demonstration and development. They must not be reused in a production environment.

## Project context

This application was developed as an academic geospatial-processing project and later extended into a reproducible, portfolio-ready WebGIS system.

It demonstrates:

- spatial database design,
- geospatial service publication,
- OGC web standards,
- responsive frontend engineering,
- automated environment configuration.

## Author

Developed by [Ahmet Kislali](https://github.com/Simurg41).

## License

No explicit open-source license has been assigned.

The repository is published for portfolio and educational presentation purposes.
