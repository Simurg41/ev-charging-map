<#
.SYNOPSIS
  One-command local setup for the EV WebGIS on Windows.

.DESCRIPTION
  Restores everything that Docker named volumes would otherwise carry between
  machines: the PostGIS table + data and the GeoServer workspace/datastore/layer.
  Safe and idempotent — run it as many times as you like.

.EXAMPLE
  .\scripts\setup-local.ps1

.EXAMPLE
  .\scripts\setup-local.ps1 -ResetData   # force a clean re-import of the CSV
#>
[CmdletBinding()]
param(
  [switch]$ResetData
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Step { param($Msg) Write-Host "`n============================================================" -ForegroundColor DarkCyan; Write-Host " $Msg" -ForegroundColor Cyan; Write-Host "============================================================" -ForegroundColor DarkCyan }

# 1) Docker installed?
Step "1/7  Checking Docker"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Docker CLI not found. Install Docker Desktop." }
# Temporarily relax error handling: `docker info` writes to stderr, which
# Windows PowerShell would otherwise turn into a terminating error.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
docker info 1>$null 2>$null
$dockerRunning = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $prevEap
if (-not $dockerRunning) { throw "Docker Desktop is not running. Start it and retry." }
Write-Host "    Docker is available and running." -ForegroundColor Green

# 2) Start compose services
Step "2/7  Starting Docker Compose services"
docker compose up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed." }

# 3) Wait for PostGIS
Step "3/7  Waiting for PostGIS"
$deadline = (Get-Date).AddSeconds(120)
do {
  docker exec postgis pg_isready -U gisuser -d gisdb *> $null
  $ready = ($LASTEXITCODE -eq 0)
  if (-not $ready) { Start-Sleep -Seconds 2 }
} while (-not $ready -and (Get-Date) -lt $deadline)
if (-not $ready) { throw "PostGIS did not become ready in time." }
Write-Host "    PostGIS is accepting connections." -ForegroundColor Green

# 4) Schema + data import (idempotent)
Step "4/7  Restoring PostGIS schema and data"
& (Join-Path $PSScriptRoot "import-bnetza.ps1") -ResetData:$ResetData

# 5) GeoServer configuration (waits for readiness internally)
Step "5/7  Configuring GeoServer"
& (Join-Path $PSScriptRoot "configure-geoserver.ps1")

# 6) Validation
Step "6/7  Validating the pipeline"
& (Join-Path $PSScriptRoot "validate-local.ps1")

# 7) Done
Step "7/7  Done"
Write-Host @"

Local EV WebGIS setup completed.

GeoServer:
  http://127.0.0.1:8080/geoserver

WMS capabilities:
  http://127.0.0.1:8080/geoserver/ev/wms?service=WMS&version=1.3.0&request=GetCapabilities

Frontend:
  cd web
  npm install
  npm run dev
  http://localhost:5173
"@ -ForegroundColor Green
