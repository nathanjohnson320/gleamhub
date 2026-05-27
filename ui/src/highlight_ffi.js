export function highlight_code(code, language) {
  const hljs = globalThis.hljs;
  if (!hljs) {
    return escape_html(code);
  }
  if (language && hljs.getLanguage(language)) {
    return hljs.highlight(code, { language }).value;
  }
  return hljs.highlightAuto(code).value;
}

/// Line-numbered table: row ids L1, L2, … and hash links (#L10, #L10-L15).
export function highlight_code_table(code, language) {
  const hljs = globalThis.hljs;
  const lang =
    language && hljs?.getLanguage(language) ? language : null;
  const langClass = lang ? `language-${lang}` : "";
  const lines = code.split("\n");
  const rows = lines.map((line, index) => {
    const n = index + 1;
    let inner;
    if (!hljs) {
      inner = escape_html(line === "" ? " " : line);
    } else if (lang) {
      inner = hljs.highlight(line === "" ? " " : line, { language: lang }).value;
    } else {
      inner = hljs.highlightAuto(line === "" ? " " : line).value;
    }
    return (
      `<tr id="L${n}" class="repo-line">` +
      `<td class="repo-line-num">` +
      `<a class="repo-line-link" href="#L${n}" data-line="${n}" aria-label="Line ${n}">${n}</a>` +
      `</td>` +
      `<td class="repo-line-code"><code class="hljs ${langClass}">${inner}</code></td>` +
      `</tr>`
    );
  });
  return (
    '<table class="repo-blob-table"><tbody>' + rows.join("") + "</tbody></table>"
  );
}

function escape_html(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
