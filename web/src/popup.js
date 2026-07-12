import Overlay from "ol/Overlay";

import { el, cleanValue, parseFeatureInfoText, isEmptyFeatureInfo } from "./utils.js";

/**
 * Station popup: a single OpenLayers overlay with three render states
 * (loading / details / error). Content is built from DOM nodes and
 * textContent, so server attributes are never injected as HTML.
 */
export function initPopup(map, evSource) {
  const element = el("div", { class: "popup", attrs: { role: "dialog", "aria-label": "Ladepunkt-Details" } });
  // Attach to the stopEvent container so popup clicks never reach the map.
  map.getOverlayContainerStopEvent().appendChild(element);

  const overlay = new Overlay({
    element,
    positioning: "bottom-center",
    stopEvent: true,
    offset: [0, -14],
  });
  map.addOverlay(overlay);

  for (const event of ["pointerdown", "click", "dblclick"]) {
    element.addEventListener(event, (e) => e.stopPropagation());
  }

  const hide = () => overlay.setPosition(undefined);
  const isOpen = () => overlay.getPosition() !== undefined;

  const closeButton = () =>
    el("button", {
      class: "popup__close",
      text: "✕",
      attrs: { type: "button", "aria-label": "Popup schließen" },
      on: { click: hide },
    });

  const setContent = (coordinate, body) => {
    element.replaceChildren(closeButton(), body);
    overlay.setPosition(coordinate);
  };

  const renderLoading = (coordinate) => {
    const body = el("div", { class: "popup__state" }, [
      el("span", { class: "popup__spinner", attrs: { "aria-hidden": "true" } }),
      el("span", { text: "Ladepunkt wird geladen …" }),
    ]);
    setContent(coordinate, body);
  };

  const renderError = (coordinate) => {
    const body = el("div", { class: "popup__state popup__state--error" }, [
      el("strong", { text: "Ladepunkt konnte nicht geladen werden." }),
      el("span", { class: "popup__hint", text: "Bitte erneut auf die Station klicken." }),
    ]);
    setContent(coordinate, body);
  };

  const metaRow = (label, value) => {
    const v = cleanValue(value);
    if (!v) return null;
    return el("div", { class: "popup__row" }, [
      el("dt", { class: "popup__label", text: label }),
      el("dd", { class: "popup__value", text: v }),
    ]);
  };

  const renderDetails = (coordinate, attrs) => {
    const type = cleanValue(attrs.anschlussart).toUpperCase();
    const isDc = type === "DC";
    const kw = cleanValue(attrs.anschlussleistung_kw);

    const badge = type
      ? el("span", {
          class: `badge ${isDc ? "badge--dc" : "badge--ac"}`,
          text: isDc ? "DC · Schnellladen" : "AC · Normalladen",
        })
      : null;

    const header = el("div", { class: "popup__header" }, [
      el("h2", { class: "popup__title", text: cleanValue(attrs.name) || "EV Ladepunkt" }),
    ]);
    if (badge) header.append(badge);

    const location = [cleanValue(attrs.ort), cleanValue(attrs.plz)].filter(Boolean).join(" · ");

    const meta = el("dl", { class: "popup__meta" }, [
      metaRow("Betreiber", attrs.betreiber),
      metaRow("Adresse", attrs.adresse),
      metaRow("Ort / PLZ", location),
      metaRow("Leistung", kw ? `${kw} kW` : ""),
      metaRow("Ladepunkte", attrs.anzahl_ladepunkte),
    ].filter(Boolean));

    const footer = el("dl", { class: "popup__meta popup__footer" }, [
      metaRow("Quelle", cleanValue(attrs.datasource) || "Bundesnetzagentur"),
      metaRow("Letztes Update", attrs.last_update),
    ].filter(Boolean));

    setContent(coordinate, el("div", { class: "popup__body" }, [header, meta, footer]));
  };

  // --- Click -> GetFeatureInfo, with request cancellation ---
  let controller = null;

  map.on("singleclick", async (evt) => {
    // Ignore clicks that land on the popup itself.
    const target = evt.originalEvent?.target;
    if (target && element.contains(target)) return;

    // Cancel any in-flight request; only the latest click renders.
    controller?.abort();
    controller = new AbortController();
    const { signal } = controller;

    renderLoading(evt.coordinate);

    const view = map.getView();
    const url = evSource.getFeatureInfoUrl(evt.coordinate, view.getResolution(), view.getProjection(), {
      INFO_FORMAT: "text/plain",
      FEATURE_COUNT: 5,
    });

    if (!url) {
      hide();
      return;
    }

    try {
      const response = await fetch(url, { signal });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const text = await response.text();
      if (signal.aborted) return;

      if (isEmptyFeatureInfo(text)) {
        // Clicking empty map should close quietly, not report an error.
        hide();
        return;
      }

      const attrs = parseFeatureInfoText(text);
      if (Object.keys(attrs).length === 0) {
        hide();
        return;
      }

      renderDetails(evt.coordinate, attrs);
    } catch (err) {
      if (err.name === "AbortError") return;
      renderError(evt.coordinate);
    }
  });

  // Close the popup on map movement and Escape.
  map.on("movestart", hide);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && isOpen()) hide();
  });

  return { hide };
}
