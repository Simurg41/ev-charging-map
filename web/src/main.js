import "ol/ol.css";
import "./style.css";

import { createMap, watchConnection } from "./map.js";
import { initPopup } from "./popup.js";
import { initTooltip } from "./tooltip.js";
import { initFilters } from "./filters.js";
import { initUI } from "./ui.js";

// Compose the dashboard: build the map, then attach behaviour modules.
const { map, evSource, evLayer } = createMap("map");

const ui = initUI(map, evLayer);
initPopup(map, evSource);
initTooltip(map, evSource);
initFilters(map, evSource, ui.filterRefs);

// Drive the header status badge from real WMS tile-loading events.
watchConnection(evSource, ui.setStatus);
