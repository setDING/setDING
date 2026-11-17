/// <reference path="../../pb_data/types.d.ts" />

// Minimum client version (ADR-0029): clients send their version in the
// X-Setding-Version header; the server answers outdated clients with
// HTTP 426, so the app can ask the person to update instead of syncing with
// a server it no longer understands (ADR-0028).

/// The lowest app version that works with this server. Raise it in the PR
/// that makes an incompatible change (a major release, ADR-0028), and deploy
/// the server only after the GitHub Release with that version is published
/// (docs/development/releases.md).
const MIN_CLIENT_VERSION = "0.0.0";

const HEADER = "X-Setding-Version";

/// [major, minor, patch, prerelease identifiers] of a SemVer string; the
/// build metadata (+…) is ignored. Null if it is not a version.
function parse(version) {
  const m = /^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/.exec(
    String(version || "").trim(),
  );
  if (!m) return null;
  return [Number(m[1]), Number(m[2]), Number(m[3]), m[4] ? m[4].split(".") : []];
}

/// Negative, zero or positive like a comparator, by SemVer precedence:
/// 1.0.0-beta.1 < 1.0.0 < 1.0.1. Versions that cannot be parsed count as
/// 0.0.0.
function compare(a, b) {
  const x = parse(a) || [0, 0, 0, []];
  const y = parse(b) || [0, 0, 0, []];
  for (let i = 0; i < 3; i++) {
    if (x[i] !== y[i]) return x[i] < y[i] ? -1 : 1;
  }
  const p = x[3];
  const q = y[3];
  // A version without prerelease ranks above one with.
  if (p.length === 0 || q.length === 0) return q.length - p.length;
  for (let i = 0; i < Math.min(p.length, q.length); i++) {
    const pn = /^\d+$/.test(p[i]);
    const qn = /^\d+$/.test(q[i]);
    if (pn && qn) {
      const d = Number(p[i]) - Number(q[i]);
      if (d !== 0) return d < 0 ? -1 : 1;
    } else if (pn !== qn) {
      return pn ? -1 : 1;
    } else if (p[i] !== q[i]) {
      return p[i] < q[i] ? -1 : 1;
    }
  }
  return p.length - q.length;
}

/// The minimum client version in effect: MIN_CLIENT_VERSION, or
/// SETDING_MIN_CLIENT_VERSION if that is higher (for tests, or to lock out
/// clients by hand).
function minClientVersion() {
  const fromEnv = ($os.getenv("SETDING_MIN_CLIENT_VERSION") || "").trim();
  if (parse(fromEnv) && compare(fromEnv, MIN_CLIENT_VERSION) > 0) return fromEnv;
  return MIN_CLIENT_VERSION;
}

/// The setDING version this server was deployed from, stamped by
/// tool/server/deploy.sh into pb_hooks/setding-version.txt: x.y.z for a
/// release (make server-release), x.y.z-dev+<commit> otherwise; null when
/// not deployed that way (local backend, tests).
function serverVersion() {
  try {
    const v = toString($os.readFile(`${__hooks}/setding-version.txt`)).trim();
    return v || null;
  } catch (_) {
    return null;
  }
}

/// Whether the request path is checked: the collections API and setDING's
/// own routes, except the config route the app reads before signing in and
/// the superusers' collection (the admin UI signs in there). Health,
/// realtime and file downloads stay open: they change nothing, and a sync
/// after a realtime event is checked anyway.
function checked(path) {
  if (path === "/api/setding/config") return false;
  if (path.startsWith("/api/collections/_superusers/")) return false;
  return path.startsWith("/api/collections/") || path.startsWith("/api/setding/");
}

/// Middleware: answers 426 to clients older than the minimum version. A
/// request without the header counts as version 0.0.0 (apps before
/// ADR-0029, scripts); superusers (admin UI, operator) are never refused.
function requireClientVersion(e) {
  const path = e.request.url.path || "";
  if (!checked(path)) return e.next();
  if (e.auth && e.auth.collection().name === "_superusers") return e.next();
  const min = minClientVersion();
  const client = e.request.header.get(HEADER) || "0.0.0";
  if (compare(client, min) >= 0) return e.next();
  return e.json(426, {
    status: 426,
    message: "Please update setDING.",
    data: { minClientVersion: min, clientVersion: client },
  });
}

module.exports = {
  MIN_CLIENT_VERSION,
  HEADER,
  parse,
  compare,
  minClientVersion,
  serverVersion,
  requireClientVersion,
};
