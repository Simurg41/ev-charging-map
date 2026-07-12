<#
.SYNOPSIS
  Restore the public.ladepunkte table and import Bundesnetzagentur data.

.DESCRIPTION
  Idempotent. Creates the schema if missing, then imports bnetza_min.csv only
  when the table has no valid rows. Re-running does not duplicate data.

.PARAMETER ResetData
  Explicitly TRUNCATE public.ladepunkte before importing. Disabled by default.
  This only empties the application table; it never drops the database or
  removes Docker volumes.
#>
[CmdletBinding()]
param(
  [switch]$ResetData,
  [string]$Container = "postgis",
  [string]$Database = "gisdb",
  [string]$DbUser = "gisuser"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$sqlDir   = Join-Path $PSScriptRoot "sql"
$csvPath  = Join-Path $repoRoot "bnetza_min.csv"

function Invoke-PsqlScalar {
  param([string]$Sql)
  $out = docker exec $Container psql -U $DbUser -d $Database -tAc $Sql
  if ($LASTEXITCODE -ne 0) { throw "psql query failed: $Sql" }
  return ($out | Out-String).Trim()
}

function Invoke-PsqlFile {
  param([string]$ContainerPath)
  docker exec $Container psql -U $DbUser -d $Database -v ON_ERROR_STOP=1 -f $ContainerPath
  if ($LASTEXITCODE -ne 0) { throw "psql file failed: $ContainerPath" }
}

Write-Host "==> Ensuring schema (public.ladepunkte)..." -ForegroundColor Cyan
docker cp (Join-Path $sqlDir "create-ladepunkte.sql") "${Container}:/tmp/create-ladepunkte.sql" | Out-Null
Invoke-PsqlFile "/tmp/create-ladepunkte.sql"

if ($ResetData) {
  Write-Host "==> -ResetData set: truncating public.ladepunkte..." -ForegroundColor Yellow
  Invoke-PsqlScalar "TRUNCATE public.ladepunkte RESTART IDENTITY;" | Out-Null
}

$validRows = [int](Invoke-PsqlScalar "SELECT count(*) FROM public.ladepunkte WHERE geom IS NOT NULL AND ST_IsValid(geom);")

if ($validRows -gt 0) {
  Write-Host "==> Table already has $validRows valid rows. Skipping import (use -ResetData to reimport)." -ForegroundColor Green
} else {
  if (-not (Test-Path $csvPath)) { throw "CSV not found: $csvPath" }
  Write-Host "==> Importing bnetza_min.csv ..." -ForegroundColor Cyan
  docker cp $csvPath "${Container}:/tmp/bnetza_min.csv" | Out-Null
  docker cp (Join-Path $sqlDir "import-bnetza.sql") "${Container}:/tmp/import-bnetza.sql" | Out-Null
  Invoke-PsqlFile "/tmp/import-bnetza.sql"
  # Remove the copied CSV from the container; keep it out of any image layer.
  docker exec $Container sh -c "rm -f /tmp/bnetza_min.csv" | Out-Null
}

Write-Host ""
Write-Host "==> Database validation:" -ForegroundColor Cyan
$total   = Invoke-PsqlScalar "SELECT count(*) FROM public.ladepunkte;"
$missing = Invoke-PsqlScalar "SELECT count(*) FROM public.ladepunkte WHERE geom IS NULL;"
$srid    = Invoke-PsqlScalar "SELECT string_agg(DISTINCT ST_SRID(geom)::text, ',') FROM public.ladepunkte WHERE geom IS NOT NULL;"
$gtype   = Invoke-PsqlScalar "SELECT string_agg(DISTINCT GeometryType(geom), ',') FROM public.ladepunkte WHERE geom IS NOT NULL;"
$extent  = Invoke-PsqlScalar "SELECT ST_Extent(geom)::text FROM public.ladepunkte WHERE geom IS NOT NULL;"

Write-Host "    total rows        : $total"
Write-Host "    missing geometry  : $missing"
Write-Host "    SRID              : $srid"
Write-Host "    geometry type     : $gtype"
Write-Host "    extent            : $extent"
Write-Host "    AC/DC distribution:"
docker exec $Container psql -U $DbUser -d $Database -c "SELECT COALESCE(anschlussart,'(null)') AS anschlussart, count(*) FROM public.ladepunkte GROUP BY anschlussart ORDER BY anschlussart;"

if ([int]$total -le 0) { throw "Import produced 0 rows." }
if ($srid -ne "4326") { throw "Unexpected SRID: '$srid' (expected 4326)." }
Write-Host "==> Database OK." -ForegroundColor Green
