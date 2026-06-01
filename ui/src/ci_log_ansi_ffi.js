/** Convert terminal ANSI SGR sequences to inline-styled HTML (dark log background). */

const SGR_PATTERN = /\x1b\[([0-9;]*)m/g;

const FG = {
  30: "#94a3b8",
  31: "#f87171",
  32: "#4ade80",
  33: "#facc15",
  34: "#60a5fa",
  35: "#e879f9",
  36: "#22d3ee",
  37: "#f1f5f9",
  90: "#64748b",
  91: "#fca5a5",
  92: "#86efac",
  93: "#fde047",
  94: "#93c5fd",
  95: "#f0abfc",
  96: "#67e8f9",
  97: "#ffffff",
};

function escapeHtml(text) {
  const safe = text == null ? "" : String(text);
  return safe
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

/** Drop cursor/hide sequences; keep SGR color codes for the second pass. */
function stripNonSgrEscapes(text) {
  return text.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, (seq) => (seq.endsWith("m") ? seq : ""));
}

function styleFromCodes(codeString) {
  const parts = [];
  let bold = false;
  let dim = false;
  let color = null;

  const safe = codeString == null ? "" : String(codeString);
  const codes = safe === "" ? ["0"] : safe.split(";");

  for (const raw of codes) {
    if (raw == null || raw === "") continue;
    const code = Number.parseInt(raw, 10);
    if (Number.isNaN(code)) continue;

    switch (code) {
      case 0:
        bold = false;
        dim = false;
        color = null;
        break;
      case 1:
        bold = true;
        break;
      case 2:
        dim = true;
        break;
      case 22:
        bold = false;
        dim = false;
        break;
      default:
        if (code in FG) color = FG[code];
    }
  }

  if (bold) parts.push("font-weight:600");
  if (dim) parts.push("opacity:0.55");
  if (color) parts.push(`color:${color}`);

  return parts.join(";");
}

function wrap(html, style) {
  if (!style) return html;
  return `<span style="${style}">${html}</span>`;
}

function renderAnsi(text) {
  const input = stripNonSgrEscapes(text);
  const segments = input.split(SGR_PATTERN);
  let html = "";
  let style = "";

  for (let i = 0; i < segments.length; i++) {
    if (i % 2 === 0) {
      html += wrap(escapeHtml(segments[i] ?? ""), style);
    } else {
      style = styleFromCodes(segments[i]);
    }
  }

  return html;
}

export function ansi_to_html(text) {
  try {
    if (text == null) return "";
    return renderAnsi(String(text));
  } catch (_err) {
    return escapeHtml(text);
  }
}
