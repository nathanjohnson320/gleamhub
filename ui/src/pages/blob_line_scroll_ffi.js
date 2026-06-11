export function scroll_to_line_after_paint(line) {
  const id = "L" + line;
  let attempts = 0;
  const maxAttempts = 60;

  function tryScroll() {
    attempts += 1;
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ block: "center", behavior: "instant" });
      return;
    }
    if (attempts < maxAttempts) {
      requestAnimationFrame(tryScroll);
    }
  }

  requestAnimationFrame(tryScroll);
}
