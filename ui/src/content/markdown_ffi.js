import DOMPurify from "dompurify";

export function render(markdown) {
  if (typeof marked === "undefined") {
    return "<p>Markdown renderer not loaded.</p>";
  }
  const html = marked.parse(markdown, { async: false });
  return DOMPurify.sanitize(html);
}
