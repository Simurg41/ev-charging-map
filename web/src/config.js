/**
 * Application configuration constants.
 * Kept in one place so the GeoServer integration and map defaults
 * are easy to audit and change.
 */

// GeoServer WMS endpoint (served through the Vite dev proxy -> :8080).
export const GEOSERVER_WMS_URL = "/geoserver/ev/wms";

// Workspace-qualified layer name. Do not change without updating GeoServer.
export const LAYER_NAME = "ev:ladepunkte";

// Map defaults for the Bremen region [longitude, latitude].
export const BREMEN_CENTER = [8.8, 53.08];
export const DEFAULT_ZOOM = 9;

// Below this zoom AC stations are hidden for performance reasons.
export const AC_MIN_ZOOM = 9;

// Zoom applied when centring on the user's geolocation.
export const GEOLOCATION_ZOOM = 13;

// Debounce for the desktop hover tooltip GetFeatureInfo request.
export const HOVER_DEBOUNCE_MS = 150;

// Attribution shown in the panel; not a fabricated statistic.
export const DATA_SOURCE = "Bundesnetzagentur";

// Connection status states used by the header badge.
export const STATUS = {
  CONNECTING: "connecting",
  ONLINE: "online",
  ISSUE: "issue",
};
