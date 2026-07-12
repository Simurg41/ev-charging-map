-- Import prepared Bundesnetzagentur data (bnetza_min.csv) into public.ladepunkte.
-- Runs in a transaction, uses a staging table, normalises fields, and only
-- inserts rows with a valid WGS84 coordinate. Re-running is safe:
-- ON CONFLICT (source_id) DO NOTHING prevents duplicates.
--
-- Expects the CSV to already be copied to /tmp/bnetza_min.csv inside the
-- postgis container (comma-separated, UTF-8, one header row).

\set ON_ERROR_STOP on
SET client_encoding TO 'UTF8';

BEGIN;

-- Staging columns are matched positionally (\copy HEADER skips the header row),
-- so plain ASCII names avoid any umlaut/identifier issues.
CREATE TEMP TABLE ladepunkte_stage (
  src_id       TEXT,
  betreiber    TEXT,
  art          TEXT,
  anzahl       TEXT,
  leistung     TEXT,
  strasse      TEXT,
  hausnummer   TEXT,
  plz          TEXT,
  ort          TEXT,
  bundesland   TEXT,
  breitengrad  TEXT,   -- latitude
  laengengrad  TEXT    -- longitude
) ON COMMIT DROP;

\copy ladepunkte_stage FROM '/tmp/bnetza_min.csv' WITH (FORMAT csv, HEADER true)

WITH cleaned AS (
  SELECT
    NULLIF(btrim(src_id), '')                                   AS src_id,
    NULLIF(btrim(betreiber), '')                                AS betreiber,
    art,
    NULLIF(regexp_replace(btrim(anzahl), '[^0-9]', '', 'g'), '') AS anzahl_clean,
    NULLIF(replace(btrim(leistung), ',', '.'), '')              AS leistung_clean,
    NULLIF(btrim(concat_ws(' ', NULLIF(btrim(strasse), ''),
                                NULLIF(btrim(hausnummer), ''))), '') AS adresse,
    NULLIF(btrim(ort), '')                                      AS ort,
    NULLIF(btrim(plz), '')                                      AS plz,
    replace(btrim(breitengrad), ',', '.')                       AS lat_s,
    replace(btrim(laengengrad), ',', '.')                       AS lon_s
  FROM ladepunkte_stage
),
valid AS (
  SELECT
    c.*,
    lat_s::double precision AS lat,
    lon_s::double precision AS lon
  FROM cleaned c
  WHERE src_id IS NOT NULL
    AND lat_s ~ '^-?[0-9]+(\.[0-9]+)?$'
    AND lon_s ~ '^-?[0-9]+(\.[0-9]+)?$'
)
INSERT INTO public.ladepunkte
  (source_id, name, betreiber, adresse, ort, plz,
   anschlussleistung_kw, anzahl_ladepunkte, anschlussart,
   datasource, last_update, geom)
SELECT
  src_id,
  'Ladeeinrichtung ' || src_id,
  betreiber,
  adresse,
  ort,
  plz,
  leistung_clean::numeric,
  anzahl_clean::integer,
  CASE
    WHEN art ILIKE 'Schnell%'           THEN 'DC'
    WHEN art ILIKE 'Normal%'            THEN 'AC'
    WHEN upper(btrim(art)) = 'DC'       THEN 'DC'
    WHEN upper(btrim(art)) = 'AC'       THEN 'AC'
    ELSE NULL
  END,
  'Bundesnetzagentur',
  now(),
  ST_SetSRID(ST_MakePoint(lon, lat), 4326)
FROM valid
WHERE lat BETWEEN -90 AND 90
  AND lon BETWEEN -180 AND 180
ON CONFLICT (source_id) DO NOTHING;

COMMIT;
