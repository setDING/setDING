/// <reference path="../../pb_data/types.d.ts" />

// Web client (ADR-0018): a Flutter web build served by PocketBase from its
// public directory. Settings (docs/operations/server.md, "Web client"):
// - REALCHORD_WEB_URL: public URL of the web client, e.g.
//   https://app.realchord.app (a tunnel hostname pointing to this server);
// - REALCHORD_PUBLIC_DIR: the public directory (--publicDir) with the build.

/// Public URL of the web client without a trailing slash, or "".
function webUrl() {
  return ($os.getenv("REALCHORD_WEB_URL") || "").trim().replace(/\/+$/, "");
}

/// The web client's index.html, or null if no web build is installed.
function index() {
  const dir = ($os.getenv("REALCHORD_PUBLIC_DIR") || "").trim();
  if (!dir) return null;
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

/// Headers for the web client's files (everything but the API and the admin
/// UI):
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
    h.set("Cross-Origin-Opener-Policy", "same-origin");
    h.set("Cross-Origin-Embedder-Policy", "credentialless");
    h.set("Cache-Control", "no-cache");
  }
  return e.next();
}

module.exports = { webUrl, index, available, isWebHost, webHeaders };
