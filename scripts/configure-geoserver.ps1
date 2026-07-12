<#
.SYNOPSIS
  Create/verify the GeoServer workspace, PostGIS datastore, and layer.

.DESCRIPTION
  Idempotent: existing resources are verified (and the datastore host is
  corrected if wrong) instead of duplicated. Never fails merely because a
  resource already exists.

  The datastore connects to the database using the Docker service name
  'postgis' — from inside the GeoServer container, 'localhost' would point
  at GeoServer itself.
#>
[CmdletBinding()]
param(
  [string]$GeoServer = "http://127.0.0.1:8080/geoserver",
  [string]$AdminUser = "admin",
  [string]$AdminPass = "geoserver",
  [string]$Workspace = "ev",
  [string]$Datastore = "postgis",
  [string]$Layer     = "ladepunkte"
)

$ErrorActionPreference = "Stop"
$rest = "$GeoServer/rest"
$b64  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${AdminUser}:${AdminPass}"))
$headers = @{ Authorization = "Basic $b64" }

function Get-HttpStatus {
  param([string]$Url)
  try {
    $r = Invoke-WebRequest -Uri $Url -Headers $headers -Method Get -UseBasicParsing
    return [int]$r.StatusCode
  } catch {
    if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode.value__ }
    return -1
  }
}

function Wait-GeoServer {
  param([int]$TimeoutSec = 180)
  Write-Host "==> Waiting for GeoServer REST API..." -ForegroundColor Cyan
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if ((Get-HttpStatus "$rest/about/version.json") -eq 200) {
      Write-Host "    GeoServer is ready." -ForegroundColor Green
      return
    }
    Start-Sleep -Seconds 3
  }
  throw "GeoServer REST API did not become ready within $TimeoutSec s."
}

Wait-GeoServer

# ---- Workspace ----
if ((Get-HttpStatus "$rest/workspaces/$Workspace.json") -eq 200) {
  Write-Host "==> Workspace '$Workspace' already exists." -ForegroundColor Green
} else {
  Write-Host "==> Creating workspace '$Workspace'..." -ForegroundColor Cyan
  $body = (@{ workspace = @{ name = $Workspace } } | ConvertTo-Json)
  Invoke-RestMethod -Uri "$rest/workspaces" -Headers $headers -Method Post -ContentType "application/json" -Body $body | Out-Null
}

# ---- PostGIS datastore ----
$dsConnection = @{
  dataStore = @{
    name = $Datastore
    connectionParameters = @{
      entry = @(
        @{ "@key" = "host";     "`$" = "postgis" },
        @{ "@key" = "port";     "`$" = "5432" },
        @{ "@key" = "database"; "`$" = "gisdb" },
        @{ "@key" = "schema";   "`$" = "public" },
        @{ "@key" = "user";     "`$" = "gisuser" },
        @{ "@key" = "passwd";   "`$" = "gispass" },
        @{ "@key" = "dbtype";   "`$" = "postgis" }
      )
    }
  }
}
$dsBody = $dsConnection | ConvertTo-Json -Depth 6

$dsUrl = "$rest/workspaces/$Workspace/datastores/$Datastore.json"
if ((Get-HttpStatus $dsUrl) -eq 200) {
  $existing = Invoke-RestMethod -Uri $dsUrl -Headers $headers -Method Get
  $hostEntry = $existing.dataStore.connectionParameters.entry | Where-Object { $_.'@key' -eq 'host' }
  if ($hostEntry.'$' -ne 'postgis') {
    Write-Host "==> Datastore host is '$($hostEntry.'$')'; correcting to 'postgis'..." -ForegroundColor Yellow
    Invoke-RestMethod -Uri $dsUrl -Headers $headers -Method Put -ContentType "application/json" -Body $dsBody | Out-Null
  } else {
    Write-Host "==> Datastore '$Datastore' already exists (host=postgis)." -ForegroundColor Green
  }
} else {
  Write-Host "==> Creating PostGIS datastore '$Datastore'..." -ForegroundColor Cyan
  Invoke-RestMethod -Uri "$rest/workspaces/$Workspace/datastores" -Headers $headers -Method Post -ContentType "application/json" -Body $dsBody | Out-Null
}

# ---- Feature type / layer ----
$ftUrl = "$rest/workspaces/$Workspace/datastores/$Datastore/featuretypes/$Layer.json"
$ftBody = (@{
  featureType = @{
    name       = $Layer
    nativeName = $Layer
    srs        = "EPSG:4326"
    enabled    = $true
    advertised = $true
  }
} | ConvertTo-Json -Depth 5)

if ((Get-HttpStatus $ftUrl) -eq 200) {
  Write-Host "==> Layer '$Workspace`:$Layer' already exists; recalculating bounds..." -ForegroundColor Green
  Invoke-RestMethod -Uri "$ftUrl`?recalculate=nativebbox,latlonbbox" -Headers $headers -Method Put -ContentType "application/json" -Body $ftBody | Out-Null
} else {
  Write-Host "==> Publishing layer '$Workspace`:$Layer'..." -ForegroundColor Cyan
  Invoke-RestMethod -Uri "$rest/workspaces/$Workspace/datastores/$Datastore/featuretypes?recalculate=nativebbox,latlonbbox" -Headers $headers -Method Post -ContentType "application/json" -Body $ftBody | Out-Null
}

Write-Host "==> GeoServer configuration complete." -ForegroundColor Green

# ---- Marker styling (workspace SLD + default style assignment) ----
& (Join-Path $PSScriptRoot "configure-geoserver-style.ps1") `
  -GeoServer $GeoServer -AdminUser $AdminUser -AdminPass $AdminPass `
  -Workspace $Workspace -Layer $Layer
