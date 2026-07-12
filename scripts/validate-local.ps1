<#
.SYNOPSIS
  Validate the restored pipeline through GeoServer (WMS, WFS, CQL, GetMap,
  GetFeatureInfo). Throws on the first hard failure.
#>
[CmdletBinding()]
param(
  [string]$GeoServer = "http://127.0.0.1:8080/geoserver",
  [string]$AdminUser = "admin",
  [string]$AdminPass = "geoserver",
  [string]$Workspace = "ev",
  [string]$Layer     = "ladepunkte",
  [string]$StyleName = "ev-charging-points",
  [string]$Container = "postgis",
  [string]$Database = "gisdb",
  [string]$DbUser = "gisuser"
)

$ErrorActionPreference = "Stop"
$qn = "$Workspace`:$Layer"
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${AdminUser}:${AdminPass}"))
$authHeaders = @{ Authorization = "Basic $b64" }
$results = @()

function Add-Result { param($Name, $Ok, $Detail) $script:results += [pscustomobject]@{ Check=$Name; Ok=$Ok; Detail=$Detail } }

# 1) WMS GetCapabilities exposes the layer
$caps = Invoke-WebRequest -Uri "$GeoServer/$Workspace/wms?service=WMS&version=1.3.0&request=GetCapabilities" -UseBasicParsing
$capsOk = $caps.Content -match [regex]::Escape($Layer)
Add-Result "WMS GetCapabilities exposes $qn" $capsOk ("HTTP {0}" -f $caps.StatusCode)

# 2) WFS GetFeature returns one feature with geometry + required properties
$wfs = Invoke-RestMethod -Uri "$GeoServer/$Workspace/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=$qn&maxFeatures=1&outputFormat=application/json"
$feat = $wfs.features | Select-Object -First 1
$required = @("name","betreiber","adresse","ort","plz","anschlussart","anschlussleistung_kw","anzahl_ladepunkte","datasource","last_update")
$missing = @()
if ($feat) { $props = $feat.properties.PSObject.Properties.Name; $missing = $required | Where-Object { $_ -notin $props } }
$wfsOk = ($null -ne $feat) -and ($null -ne $feat.geometry) -and ($missing.Count -eq 0)
$wfsDetail = if (-not $feat) { "no feature returned" }
             elseif ($missing.Count -gt 0) { "missing props: " + ($missing -join ',') }
             else { "geometry + all required props present" }
Add-Result "WFS returns feature + geometry + required props" $wfsOk $wfsDetail

# 3) CQL filters for AC and DC
foreach ($art in @("AC","DC")) {
  $u = "$GeoServer/$Workspace/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=$qn&maxFeatures=1&outputFormat=application/json&CQL_FILTER=anschlussart='$art'"
  $r = Invoke-RestMethod -Uri $u
  $ok = ($r.features.Count -ge 1)
  Add-Result "CQL anschlussart='$art' returns a feature" $ok ("features={0}" -f $r.features.Count)
}

# 3b) Combined AC+DC and empty (1=0) CQL still render as PNG (no service error)
foreach ($case in @(@{n="AC + DC"; f="anschlussart='AC' OR anschlussart='DC'"}, @{n="1=0 (empty)"; f="1=0"})) {
  $u = "$GeoServer/$Workspace/wms?service=WMS&version=1.1.1&request=GetMap&layers=$qn&bbox=5,47,15,55&width=400&height=400&srs=EPSG:4326&format=image/png&CQL_FILTER=$([uri]::EscapeDataString($case.f))"
  $ct = [string](Invoke-WebRequest -Uri $u -UseBasicParsing).Headers["Content-Type"]
  Add-Result ("WMS GetMap CQL {0} returns image/png" -f $case.n) ($ct -like "image/png*") "Content-Type=$ct"
}

# 4) WMS GetMap returns an image (not an XML ServiceException)
$mapUrl = "$GeoServer/$Workspace/wms?service=WMS&version=1.1.1&request=GetMap&layers=$qn&bbox=5,47,15,55&width=400&height=400&srs=EPSG:4326&format=image/png"
$map = Invoke-WebRequest -Uri $mapUrl -UseBasicParsing
$mapCt = [string]$map.Headers["Content-Type"]
Add-Result "WMS GetMap returns image/png" ($mapCt -like "image/png*") "Content-Type=$mapCt"

# 4b) Layer default style is the custom marker style
$layerInfo = Invoke-RestMethod -Uri "$GeoServer/rest/layers/$qn.json" -Headers $authHeaders -Method Get
$defStyle = [string]$layerInfo.layer.defaultStyle.name
Add-Result "Default style of $qn is $StyleName" ($defStyle -match [regex]::Escape($StyleName)) "defaultStyle=$defStyle"

# 5) GetFeatureInfo (text/plain) over a real station coordinate
$coord = docker exec $Container psql -U $DbUser -d $Database -tAc "SELECT ST_X(geom)||' '||ST_Y(geom) FROM public.ladepunkte WHERE geom IS NOT NULL LIMIT 1;"
$coord = ($coord | Out-String).Trim()
$inv = [Globalization.CultureInfo]::InvariantCulture
$lon = [double]::Parse(($coord -split '\s+')[0], $inv)
$lat = [double]::Parse(($coord -split '\s+')[1], $inv)
$d = 0.02
# Format with InvariantCulture: a German locale would otherwise emit comma
# decimals and corrupt the comma-separated WMS bbox.
$fmt = { param($v) ($v).ToString("0.######", $inv) }
$bbox = @((& $fmt ($lon - $d)), (& $fmt ($lat - $d)), (& $fmt ($lon + $d)), (& $fmt ($lat + $d))) -join ","
$gfiUrl = "$GeoServer/$Workspace/wms?service=WMS&version=1.1.1&request=GetFeatureInfo&layers=$qn&query_layers=$qn&bbox=$bbox&width=101&height=101&srs=EPSG:4326&info_format=text/plain&x=50&y=50&buffer=30&feature_count=5"
$gfi = Invoke-WebRequest -Uri $gfiUrl -UseBasicParsing
$gfiOk = ($gfi.Content -match "anschlussart") -and ($gfi.Content -notmatch "no features were found")
Add-Result "GetFeatureInfo (text/plain) returns station fields" $gfiOk ("len={0}" -f $gfi.Content.Length)

# ---- Report ----
Write-Host ""
Write-Host "==> Validation results:" -ForegroundColor Cyan
$results | ForEach-Object {
  $tag = if ($_.Ok) { "[ OK ]" } else { "[FAIL]" }
  $color = if ($_.Ok) { "Green" } else { "Red" }
  Write-Host ("  {0} {1}  ({2})" -f $tag, $_.Check, $_.Detail) -ForegroundColor $color
}

if ($results | Where-Object { -not $_.Ok }) { throw "One or more validation checks failed." }
Write-Host "==> All GeoServer validations passed." -ForegroundColor Green
