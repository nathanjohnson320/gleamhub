let hashListenerAdded = false;

function parse_line_hash(hash) {
  const m = /^#L(\d+)(?:-L(\d+))?$/i.exec(hash || "");
  if (!m) return null;
  const start = parseInt(m[1], 10);
  const end = m[2] ? parseInt(m[2], 10) : start;
  return {
    start: Math.min(start, end),
    end: Math.max(start, end),
  };
}

export function apply_blob_line_hash() {
  const panel = document.querySelector(".repo-blob-panel");
  if (!panel) return;

  panel.querySelectorAll(".repo-line-highlight").forEach((row) => {
    row.classList.remove("repo-line-highlight");
  });

  const range = parse_line_hash(window.location.hash);
  if (!range) return;

  for (let n = range.start; n <= range.end; n += 1) {
    const row = document.getElementById(`L${n}`);
    if (row) row.classList.add("repo-line-highlight");
  }

  const anchor = document.getElementById(`L${range.start}`);
  if (anchor) {
    anchor.scrollIntoView({ block: "center", behavior: "instant" });
  }
}

export function init_blob_lines() {
  requestAnimationFrame(() => {
    apply_blob_line_hash();
  });
  if (!hashListenerAdded) {
    hashListenerAdded = true;
    window.addEventListener("hashchange", apply_blob_line_hash);
  }
}
