/// <reference path="../../pb_data/types.d.ts" />

// Web client (ADR-0018): a Flutter web build served by PocketBase from its
// public directory. Settings (docs/operations/server.md, "Web client"):
// - SETDING_WEB_URL: public URL of the web client, e.g.
//   https://app.setding.app (a tunnel hostname pointing to this server);
// - SETDING_PUBLIC_DIR: the public directory (--publicDir) with the build;
//   default pb_public next to the hooks, as in the server bundle (ADR-0063).

/// Public URL of the web client without a trailing slash, or "".
function webUrl() {
  return ($os.getenv("SETDING_WEB_URL") || "").trim().replace(/\/+$/, "");
}

/// The web client's index.html, or null if no web build is installed.
function index() {
  const dir = ($os.getenv("SETDING_PUBLIC_DIR") || "").trim() || `${__hooks}/../pb_public`;
  try {
    return toString($os.readFile(dir + "/index.html"));
  } catch (_) {
    return null;
  }
}

/// Whether the web client can be offered: configured and installed.
function available() {
  return webUrl() !== "" && index() !== null;
}

/// Whether the request is for the web client's hostname.
function isWebHost(e) {
  const url = webUrl();
  if (!url) return false;
  const host = url.replace(/^[a-z]+:\/\//i, "").split("/")[0].toLowerCase();
  return (e.request.host || "").toLowerCase() === host;
}

/// Content Security Policy of the web client (#1196). What the Flutter web
/// build needs, all from this server (tool/build-web.sh, no CDN):
/// - scripts only from this origin (index.html has no inline script) and
///   'wasm-unsafe-eval' for WebAssembly: CanvasKit, sqlite3 (drift), pdfium
///   (pdfrx), SoLoud and zxing;
/// - workers from this origin (drift, SoLoud, zxing, the service worker) and
///   blob: (pdfrx starts its pdfium worker from a blob URL);
/// - inline styles: the Flutter engine and index.html's splash set them;
/// - images, fonts and media from this origin, data: and blob: (decoded
///   attachments, PDF pages);
/// - connections to this origin (the API and its realtime SSE: the web
///   client calls the API on the hostname it was loaded from, ADR-0018),
///   blob: and data:, and fonts.gstatic.com, where Flutter loads the Noto
///   fallback fonts for characters the bundled fonts lack;
/// - never framed (frame-ancestors 'none'), no plugins, base and form
///   targets only this origin.
const CSP = [
  "default-src 'self'",
  "script-src 'self' 'wasm-unsafe-eval'",
  "worker-src 'self' blob:",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  "font-src 'self' data: https://fonts.gstatic.com",
  "media-src 'self' data: blob:",
  "connect-src 'self' data: blob: https://fonts.gstatic.com",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'none'",
].join("; ");

/// Security headers of every page and file outside the API (#1196); the
/// invitation landing page sets its own, stricter policy.
function securityHeaders(h, csp) {
  h.set("Content-Security-Policy", csp);
  h.set("X-Content-Type-Options", "nosniff");
  // Invitation tokens are in URL paths (/invite/<token>).
  h.set("Referrer-Policy", "no-referrer");
}

/// Headers for the web client's files (everything but the API and the admin
/// UI):
/// - the security headers above (#1196);
/// - cross-origin isolation, so browsers give its database OPFS instead of
///   the IndexedDB fallback (ADR-0018); "credentialless" keeps cross-origin
///   resources without CORP headers working, browsers without it fall back
///   to IndexedDB;
/// - "no-cache": Flutter web files keep their names between builds, so
///   browsers and Cloudflare must revalidate them (304 when unchanged)
///   instead of keeping an old build for hours after a deploy (#121).
function webHeaders(e) {
  const path = e.request.url.path || "";
  if (!path.startsWith("/api/") && !path.startsWith("/_/")) {
    const h = e.response.header();
    securityHeaders(h, CSP);
    h.set("Cross-Origin-Opener-Policy", "same-origin");
    h.set("Cross-Origin-Embedder-Policy", "credentialless");
    h.set("Cache-Control", "no-cache");
  }
  return e.next();
}

module.exports = { webUrl, index, available, isWebHost, securityHeaders, webHeaders };
