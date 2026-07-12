import { el, cleanValue, parseFeatureInfoText, isEmptyFeatureInfo, isCoarsePointer } from "./utils.js";
import { HOVER_DEBOUNCE_MS } from "./config.js";

/**
 * Lightweight desktop hover tooltip showing operator + charging mode.
 * Skipped entirely on coarse-pointer devices. Requests are debounced and
 * cancelled so a stale response can never appear at an old pointer position.
 */
export function initTooltip(map, evSource) {
  // No hover semantics on touch devices — do not issue requests.
  if (isCoarsePointer()) return;

  const element = el("div", { class: "tooltip", attrs: { role: "tooltip", "aria-hidden": "true" } });
  document.body.appendChild(element);

  let timer = null;
  let controller = null;

  const hide = () => {
    element.classList.remove("tooltip--visible");
    element.setAttribute("aria-hidden", "true");
  };

  const cancelPending = () => {
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }
    controller?.abort();
    controller = null;
  };

  const position = (pageX, pageY) => {
    // Clamp within the viewport so the tooltip never overflows off-screen.
    const margin = 12;
    const rect = element.getBoundingClientRect();
    const maxLeft = window.scrollX + document.documentElement.clientWidth - rect.width - margin;
    const maxTop = window.scrollY + document.documentElement.clientHeight - rect.height - margin;
    element.style.left = `${Math.min(pageX + margin, maxLeft)}px`;
    element.style.top = `${Math.min(pageY + margin, maxTop)}px`;
  };

  map.on("pointermove", (evt) => {
    if (evt.dragging) {
      cancelPending();
      hide();
      return;
    }

    cancelPending();
    const { pageX, pageY } = evt.originalEvent;

    timer = setTimeout(async () => {
      controller = new AbortController();
      const { signal } = controller;

      const view = map.getView();
      const url = evSource.getFeatureInfoUrl(evt.coordinate, view.getResolution(), view.getProjection(), {
        INFO_FORMAT: "text/plain",
        FEATURE_COUNT: 1,
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
          hide();
          return;
        }

        const attrs = parseFeatureInfoText(text);
        if (Object.keys(attrs).length === 0) {
          hide();
          return;
        }

        const isDc = cleanValue(attrs.anschlussart).toUpperCase() === "DC";
        element.replaceChildren(
          el("span", { class: "tooltip__operator", text: cleanValue(attrs.betreiber) || "Unbekannter Betreiber" }),
          el("span", {
            class: `tooltip__mode tooltip__mode--${isDc ? "dc" : "ac"}`,
            text: isDc ? "DC · Schnellladen" : "AC · Normalladen",
          }),
        );
        element.classList.add("tooltip--visible");
        element.setAttribute("aria-hidden", "false");
        position(pageX, pageY);
      } catch (err) {
        if (err.name !== "AbortError") hide();
      }
    }, HOVER_DEBOUNCE_MS);
  });

  // Cancel and hide as soon as the map begins moving.
  map.on("movestart", () => {
    cancelPending();
    hide();
  });
}
