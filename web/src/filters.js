import { AC_MIN_ZOOM } from "./config.js";

/**
 * Server-side AC/DC filtering via GeoServer CQL_FILTER, plus the
 * zoom rule that hides AC below AC_MIN_ZOOM without losing the user's
 * AC preference (the checkbox stays checked, only disabled).
 *
 * @param {import("ol/Map").default} map
 * @param {import("ol/source/TileWMS").default} evSource
 * @param {object} refs  { acInput, dcInput, acNote, zoomValue, modeValue }
 */
export function initFilters(map, evSource, refs) {
  const { acInput, dcInput, acNote, zoomValue, modeValue } = refs;

  const describeMode = (acActive, dcActive, belowMin, acPref) => {
    if (acActive && dcActive) return "AC + DC";
    if (acActive) return "AC only";
    if (dcActive) return belowMin && acPref ? "DC only (zoom < 9)" : "DC only";
    return "No charging layer";
  };

  const apply = () => {
    const zoom = map.getView().getZoom() ?? 0;
    const belowMin = zoom < AC_MIN_ZOOM;

    const acPref = acInput?.checked ?? true;
    const dcPref = dcInput?.checked ?? true;

    const acActive = !belowMin && acPref;
    const dcActive = dcPref;

    // Build the CQL filter from the active charging types.
    const parts = [];
    if (acActive) parts.push("anschlussart='AC'");
    if (dcActive) parts.push("anschlussart='DC'");
    evSource.updateParams({ CQL_FILTER: parts.length ? parts.join(" OR ") : "1=0" });
    evSource.refresh();

    // Reflect the zoom rule in the AC control without looking like an error.
    if (acInput) acInput.disabled = belowMin;
    if (acNote) acNote.hidden = !belowMin;

    // Update the read-only map information.
    if (zoomValue) zoomValue.textContent = zoom.toFixed(1);
    if (modeValue) modeValue.textContent = describeMode(acActive, dcActive, belowMin, acPref);
  };

  acInput?.addEventListener("change", apply);
  dcInput?.addEventListener("change", apply);
  map.getView().on("change:resolution", apply);

  apply();
  return { apply };
}
