import Map from "ol/Map";
import View from "ol/View";
import TileLayer from "ol/layer/Tile";
import TileWMS from "ol/source/TileWMS";
import OSM from "ol/source/OSM";
import { Zoom, Attribution } from "ol/control";
import { fromLonLat } from "ol/proj";

import {
  GEOSERVER_WMS_URL,
  LAYER_NAME,
  BREMEN_CENTER,
  DEFAULT_ZOOM,
  STATUS,
} from "./config.js";

/**
 * Build the OpenLayers map: OSM basemap + GeoServer WMS overlay.
 * Returns the pieces other modules need instead of using globals.
 */
export function createMap(target) {
  const evSource = new TileWMS({
    url: GEOSERVER_WMS_URL,
    params: {
      LAYERS: LAYER_NAME,
      TILED: true,
      // CQL_FILTER is set dynamically in filters.js.
    },
    serverType: "geoserver",
    crossOrigin: "anonymous",
  });

  const osmLayer = new TileLayer({ source: new OSM() });
  const evLayer = new TileLayer({ source: evSource });

  const map = new Map({
    target,
    layers: [osmLayer, evLayer],
    view: new View({
      center: fromLonLat(BREMEN_CENTER),
      zoom: DEFAULT_ZOOM,
    }),
    // Restyled explicitly so we control placement (see style.css).
    controls: [new Zoom(), new Attribution({ collapsible: false })],
  });

  return { map, evSource, evLayer, osmLayer };
}

/**
 * Derive a connection status from WMS tile-loading events and report
 * changes through `onChange(status)`. Recovers to ONLINE once tiles
 * load successfully again after an error.
 */
export function watchConnection(evSource, onChange) {
  let pending = 0;
  let everOnline = false;
  let hasError = false;
  let current = STATUS.CONNECTING;

  const emit = () => {
    let next;
    if (hasError) next = STATUS.ISSUE;
    else if (pending > 0 && !everOnline) next = STATUS.CONNECTING;
    else next = STATUS.ONLINE;

    if (next !== current) {
      current = next;
      onChange(next);
    }
  };

  evSource.on("tileloadstart", () => {
    pending += 1;
    emit();
  });

  evSource.on("tileloadend", () => {
    pending = Math.max(0, pending - 1);
    everOnline = true;
    hasError = false;
    emit();
  });

  evSource.on("tileloaderror", () => {
    pending = Math.max(0, pending - 1);
    hasError = true;
    emit();
  });

  onChange(current);
}
