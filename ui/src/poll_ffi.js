export function schedule(ms, f) {
  globalThis.setTimeout(f, ms);
}
