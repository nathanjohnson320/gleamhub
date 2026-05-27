export function render(markdown) {
  if (typeof marked === "undefined") {
    return "<p>Markdown renderer not loaded.</p>";
  }
  return marked.parse(markdown, { async: false });
}
