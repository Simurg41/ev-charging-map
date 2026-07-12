/**
 * Small, dependency-free helpers shared across modules.
 */

/**
 * Create an element with attributes and children in one call.
 * Text is always assigned via textContent, so values are never
 * interpreted as HTML.
 *
 * @param {string} tag
 * @param {object} [options]  { class, text, attrs, on }
 * @param {Array<Node|string>} [children]
 */
export function el(tag, options = {}, children = []) {
  const node = document.createElement(tag);
  const { class: className, text, attrs, on } = options;

  if (className) node.className = className;
  if (text != null) node.textContent = text;

  if (attrs) {
    for (const [key, value] of Object.entries(attrs)) {
      if (value != null) node.setAttribute(key, value);
    }
  }

  if (on) {
    for (const [event, handler] of Object.entries(on)) {
      node.addEventListener(event, handler);
    }
  }

  for (const child of children) {
    node.append(child);
  }
  return node;
}

/** Normalise a raw GeoServer value; returns "" for empty / literal "null". */
export function cleanValue(value) {
  if (value == null) return "";
  const text = String(value).trim();
  if (text === "" || text.toLowerCase() === "null") return "";
  return text;
}

/**
 * Parse GeoServer's text/plain GetFeatureInfo response into a flat object.
 * Lines look like `key = value`; header / separator lines are ignored.
 */
export function parseFeatureInfoText(text) {
  const attrs = {};
  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("Results") || line.startsWith("---")) continue;

    const idx = line.indexOf("=");
    if (idx === -1) continue;

    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim();
    if (key) attrs[key] = value;
  }
  return attrs;
}

/** True when the WMS response reports no matching feature. */
export function isEmptyFeatureInfo(text) {
  return !text || text.includes("no features were found");
}

/** True on touch / stylus devices where hover is not meaningful. */
export function isCoarsePointer() {
  return window.matchMedia("(pointer: coarse)").matches;
}

/** True when the user asked the OS to minimise motion. */
export function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}
