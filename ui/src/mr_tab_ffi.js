let mrTabListenerAdded = false;

const VALID = new Set(["conversation", "checks", "commits", "changes"]);

export function read_mr_tab_hash() {
  const segment = (window.location.hash || "").replace(/^#/, "").toLowerCase();
  return VALID.has(segment) ? segment : "conversation";
}

export function set_mr_tab_hash(segment) {
  const name = VALID.has(segment) ? segment : "conversation";
  const url = new URL(window.location.href);
  url.hash = name;
  history.replaceState(null, "", url);
}

export function subscribe_mr_tab_hash(on_change) {
  if (mrTabListenerAdded) {
    return;
  }
  mrTabListenerAdded = true;
  window.addEventListener("hashchange", () => {
    on_change(read_mr_tab_hash());
  });
}
