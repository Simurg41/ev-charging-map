import { el, prefersReducedMotion } from "./utils.js";
import {
  BREMEN_CENTER,
  DEFAULT_ZOOM,
  GEOLOCATION_ZOOM,
  STATUS,
} from "./config.js";
import { fromLonLat } from "ol/proj";

const STATUS_LABEL = {
  [STATUS.CONNECTING]: "Connecting",
  [STATUS.ONLINE]: "System online",
  [STATUS.ISSUE]: "Connection issue",
};

/**
 * Wires up all chrome around the map: status badge, toasts, the mobile
 * filter drawer, and the map action buttons. Returns the DOM references
 * that filters.js needs and a setStatus() callback for the connection watcher.
 */
export function initUI(map, evLayer) {
  const byId = (id) => document.getElementById(id);

  /* ---------- Toasts (aria-live, de-duplicated) ---------- */
  const toastHost = byId("toasts");
  const activeMessages = new Set();

  const toast = (message) => {
    if (!toastHost || activeMessages.has(message)) return;
    activeMessages.add(message);

    const node = el("div", { class: "toast", text: message });
    toastHost.appendChild(node);

    const remove = () => {
      node.remove();
      activeMessages.delete(message);
    };
    // Auto-dismiss; the fade-out is handled in CSS via the removing class.
    setTimeout(() => {
      node.classList.add("toast--leaving");
      setTimeout(remove, 250);
    }, 4000);
  };

  /* ---------- Connection status badge ---------- */
  const badge = byId("status-badge");
  let previous = STATUS.CONNECTING;

  const setStatus = (status) => {
    if (badge) {
      badge.dataset.status = status;
      const label = badge.querySelector(".status__label");
      if (label) label.textContent = STATUS_LABEL[status] ?? "";
    }
    if (status === STATUS.ISSUE) {
      toast("Verbindung zum Kartendienst gestört. Erneuter Versuch läuft …");
    } else if (status === STATUS.ONLINE && previous === STATUS.ISSUE) {
      toast("Verbindung wiederhergestellt.");
    }
    previous = status;
  };

  /* ---------- Mobile filter drawer ---------- */
  const panel = byId("panel");
  const openBtn = byId("filters-open");
  const closeBtn = byId("panel-close");

  const openPanel = () => {
    panel?.classList.add("panel--open");
    openBtn?.setAttribute("aria-expanded", "true");
    closeBtn?.focus();
  };
  const closePanel = () => {
    panel?.classList.remove("panel--open");
    openBtn?.setAttribute("aria-expanded", "false");
    openBtn?.focus();
  };
  openBtn?.addEventListener("click", openPanel);
  closeBtn?.addEventListener("click", closePanel);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && panel?.classList.contains("panel--open")) closePanel();
  });

  /* ---------- Map actions ---------- */
  const view = map.getView();

  const resetBtn = byId("action-reset");
  resetBtn?.addEventListener("click", () => {
    const target = { center: fromLonLat(BREMEN_CENTER), zoom: DEFAULT_ZOOM };
    if (prefersReducedMotion()) {
      view.setCenter(target.center);
      view.setZoom(target.zoom);
    } else {
      view.animate({ ...target, duration: 500 });
    }
    toast("Ansicht auf Bremen zurückgesetzt.");
  });

  const locateBtn = byId("action-locate");
  locateBtn?.addEventListener("click", () => {
    if (!("geolocation" in navigator)) {
      toast("Standortbestimmung wird nicht unterstützt.");
      return;
    }
    // Prevent repeated clicks while a request is running.
    locateBtn.disabled = true;
    toast("Standort wird ermittelt …");

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        locateBtn.disabled = false;
        const center = fromLonLat([pos.coords.longitude, pos.coords.latitude]);
        if (prefersReducedMotion()) {
          view.setCenter(center);
          view.setZoom(GEOLOCATION_ZOOM);
        } else {
          view.animate({ center, zoom: GEOLOCATION_ZOOM, duration: 500 });
        }
      },
      (err) => {
        locateBtn.disabled = false;
        const denied = err.code === err.PERMISSION_DENIED;
        toast(denied ? "Standortfreigabe verweigert." : "Standort konnte nicht ermittelt werden.");
      },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  });

  const layerBtn = byId("action-layer");
  layerBtn?.addEventListener("click", () => {
    const visible = !evLayer.getVisible();
    evLayer.setVisible(visible);
    layerBtn.setAttribute("aria-pressed", String(visible));
    const label = layerBtn.querySelector(".action__text");
    if (label) label.textContent = visible ? "Hide stations" : "Show stations";
    toast(visible ? "Ladepunkte eingeblendet." : "Ladepunkte ausgeblendet.");
  });

  return {
    setStatus,
    toast,
    filterRefs: {
      acInput: byId("filter-ac"),
      dcInput: byId("filter-dc"),
      acNote: byId("ac-note"),
      zoomValue: byId("info-zoom"),
      modeValue: byId("info-mode"),
    },
  };
}
