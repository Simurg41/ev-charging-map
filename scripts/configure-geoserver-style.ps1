<#
.SYNOPSIS
  Install/update the workspace-scoped SLD style 'ev:ev-charging-points' and set
  it as the default style of ev:ladepunkte.

.DESCRIPTION
  Idempotent: creates the style if missing, otherwise updates its SLD in place
  (no duplicates). Only the default style assignment is changed on the layer —
  enabled/advertised/queryable state, CRS, and bounds are left untouched.
  Reads the SLD from geoserver/styles/ev-charging-points.sld (repo-relative).
#>
[CmdletBinding()]
param(
  [string]$GeoServer = "http://127.0.0.1:8080/geoserver",
  [string]$AdminUser = "admin",
  [string]$AdminPass = "geoserver",
  [string]$Workspace = "ev",
  [string]$Layer     = "ladepunkte",
  [string]$StyleName = "ev-charging-points"
)

$ErrorActionPreference = "Stop"
$rest = "$GeoServer/rest"
$b64  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${AdminUser}:${AdminPass}"))
$headers = @{ Authorization = "Basic $b64" }
$sldType = "application/vnd.ogc.sld+xml"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sldPath  = Join-Path $repoRoot "geoserver/styles/ev-charging-points.sld"
if (-not (Test-Path $sldPath)) { throw "SLD file not found: $sldPath" }
# Read as UTF-8 bytes so the body is transmitted exactly as written.
$sldBytes = [System.IO.File]::ReadAllBytes($sldPath)

function Get-HttpStatus {
  param([string]$Url)
  try { return [int](Invoke-WebRequest -Uri $Url -Headers $headers -Method Get -UseBasicParsing).StatusCode }
  catch { if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode.value__ } else { return -1 } }
}

function Wait-GeoServer {
  param([int]$TimeoutSec = 180)
  Write-Host "==> Waiting for GeoServer REST API..." -ForegroundColor Cyan
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if ((Get-HttpStatus "$rest/about/version.json") -eq 200) { Write-Host "    GeoServer is ready." -ForegroundColor Green; return }
    Start-Sleep -Seconds 3
  }
  throw "GeoServer REST API did not become ready within $TimeoutSec s."
}

Wait-GeoServer

# ---- 1) Create or update the workspace style ----
$styleUrl = "$rest/workspaces/$Workspace/styles/$StyleName"
try {
  if ((Get-HttpStatus "$styleUrl.json") -eq 200) {
    Write-Host "==> Updating existing style '$Workspace`:$StyleName'..." -ForegroundColor Cyan
    Invoke-RestMethod -Uri $styleUrl -Headers $headers -Method Put -ContentType $sldType -Body $sldBytes | Out-Null
  } else {
    Write-Host "==> Creating style '$Workspace`:$StyleName'..." -ForegroundColor Cyan
    Invoke-RestMethod -Uri "$rest/workspaces/$Workspace/styles?name=$StyleName" -Headers $headers -Method Post -ContentType $sldType -Body $sldBytes | Out-Null
  }
} catch {
  $resp = $_.Exception.Response
  $detail = ""
  if ($resp) { try { $detail = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd() } catch {} }
  throw "GeoServer rejected the SLD: $($_.Exception.Message)`n$detail"
}

# ---- 2) Assign it as the layer default style ----
Write-Host "==> Setting default style of '$Workspace`:$Layer' to '$Workspace`:$StyleName'..." -ForegroundColor Cyan
$layerBody = (@{
  layer = @{ defaultStyle = @{ name = $StyleName; workspace = $Workspace } }
} | ConvertTo-Json -Depth 5)
Invoke-RestMethod -Uri "$rest/layers/$Workspace`:$Layer" -Headers $headers -Method Put -ContentType "application/json" -Body $layerBody | Out-Null

# ---- 3) Verify assignment ----
$layerInfo = Invoke-RestMethod -Uri "$rest/layers/$Workspace`:$Layer.json" -Headers $headers -Method Get
$assigned = $layerInfo.layer.defaultStyle.name
if ($assigned -notmatch [regex]::Escape($StyleName)) {
  throw "Default style verification failed: layer reports '$assigned'."
}
Write-Host "    Default style is '$assigned'." -ForegroundColor Green

# ---- 4) WMS GetMap smoke test using the new default style (Bremen) ----
$inv = [Globalization.CultureInfo]::InvariantCulture
$bbox = "8.6,53.0,8.95,53.18"  # minLon,minLat,maxLon,maxLat around Bremen (WMS 1.1.1 axis order)
$mapUrl = "$GeoServer/$Workspace/wms?service=WMS&version=1.1.1&request=GetMap&layers=$Workspace`:$Layer&bbox=$bbox&width=512&height=384&srs=EPSG:4326&format=image/png"
$map = Invoke-WebRequest -Uri $mapUrl -UseBasicParsing
$ct = [string]$map.Headers["Content-Type"]
if ($ct -notlike "image/png*") { throw "WMS GetMap with new style did not return an image (Content-Type=$ct)." }
Write-Host "    WMS GetMap with new style returns image/png." -ForegroundColor Green

Write-Host "==> Style configuration complete." -ForegroundColor Green
