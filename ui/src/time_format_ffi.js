export function format_commit_time(unixSecondsStr) {
  const seconds = parseInt(unixSecondsStr, 10);
  if (!Number.isFinite(seconds)) return unixSecondsStr;

  const date = new Date(seconds * 1000);
  const now = Date.now();
  const diffSec = Math.round((now - date.getTime()) / 1000);

  if (diffSec < 60) return "just now";
  if (diffSec < 3600) {
    const m = Math.floor(diffSec / 60);
    return m === 1 ? "1 minute ago" : `${m} minutes ago`;
  }
  if (diffSec < 86400) {
    const h = Math.floor(diffSec / 3600);
    return h === 1 ? "1 hour ago" : `${h} hours ago`;
  }
  if (diffSec < 86400 * 30) {
    const d = Math.floor(diffSec / 86400);
    return d === 1 ? "1 day ago" : `${d} days ago`;
  }

  return date.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}
