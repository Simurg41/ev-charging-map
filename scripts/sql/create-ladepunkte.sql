-- Idempotent schema for the EV charging-station layer.
-- Safe to run repeatedly: nothing here drops or truncates existing data.

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS public.ladepunkte (
  id                    SERIAL PRIMARY KEY,
  source_id             TEXT,                 -- Bundesnetzagentur "Ladeeinrichtungs-ID" (used for de-duplication)
  name                  TEXT,
  betreiber             TEXT,
  adresse               TEXT,
  ort                   TEXT,
  plz                   TEXT,
  anschlussleistung_kw  NUMERIC,
  anzahl_ladepunkte     INTEGER,
  anschlussart          TEXT,                 -- normalised to 'AC' / 'DC'
  steckertypen          TEXT,
  kostenlos             BOOLEAN,
  datasource            TEXT,
  last_update           TIMESTAMP,
  geom                  GEOMETRY(Point, 4326)
);

-- Spatial index for fast WMS/WFS bbox queries.
CREATE INDEX IF NOT EXISTS ladepunkte_geom_gix
  ON public.ladepunkte USING GIST (geom);

-- Stable key so a repeated import does not create duplicate rows.
CREATE UNIQUE INDEX IF NOT EXISTS ladepunkte_source_id_uidx
  ON public.ladepunkte (source_id);
