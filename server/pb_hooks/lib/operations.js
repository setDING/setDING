/// <reference path="../../pb_data/types.d.ts" />

// Running the server without an installer (ADR-0063 §2, §4): required
// configuration, built-in backups and the health check, the same for the
// native bundle and the Docker image.

/// Environment variables the server does not start without.
const REQUIRED = [
  // Encrypts the stored invitation tokens (ADR-0005). Not generated here:
  // a key written into pb_data would end up in every backup.
  "SETDING_INVITE_KEY",
];

const DEFAULT_BACKUP_CRON = "0 3 * * *";
const DEFAULT_BACKUP_KEEP = 14;
// Request logs (with IP addresses) are kept this many days; the privacy policy
// on the website names this value (#1118).
const DEFAULT_LOG_DAYS = 7;
const DEFAULT_HEALTH_URL = "http://127.0.0.1:8090";
// The most file storage one organization may use (ADR-0070), in megabytes.
const DEFAULT_ORG_STORAGE_LIMIT_MB = 25;
const MB = 1024 * 1024;

// PocketBase's global flags that take a separate value (`--dir x`).
const VALUE_FLAGS = ["--dir", "--hooksDir", "--hooksPool", "--migrationsDir", "--publicDir", "--encryptionEnv", "--queryTimeout"];

/// The command PocketBase runs: the first argument that is neither a flag
/// nor a flag's value ("serve", "superuser", "founder-invite", …).
function command(args) {
  const rest = (args || []).slice(1);
  for (let i = 0; i < rest.length; i++) {
    const a = rest[i];
    if (!a.startsWith("-")) return a;
    if (VALUE_FLAGS.indexOf(a) >= 0) i++;
  }
  return "";
}

/// True when the process runs the web server (`pocketbase serve`), not a
/// console command such as `superuser upsert` or `founder-invite`.
function serving() {
  return command($os.args) === "serve";
}

/// The names of the required variables that are missing or empty.
function missingVariables() {
  return REQUIRED.filter((name) => !($os.getenv(name) || "").trim());
}

/// The backup schedule from SETDING_BACKUP_CRON and SETDING_BACKUP_KEEP:
/// `{cron, keep}`; `off` turns the automatic backups off (cron "").
function backupConfig() {
  const rawCron = ($os.getenv("SETDING_BACKUP_CRON") || "").trim();
  const cron = rawCron === "" ? DEFAULT_BACKUP_CRON : rawCron === "off" ? "" : rawCron;
  const rawKeep = ($os.getenv("SETDING_BACKUP_KEEP") || "").trim();
  let keep = DEFAULT_BACKUP_KEEP;
  if (rawKeep !== "") {
    if (!/^[1-9]\d*$/.test(rawKeep)) {
      throw new Error(`SETDING_BACKUP_KEEP must be a whole number of at least 1, not "${rawKeep}".`);
    }
    keep = Number(rawKeep);
  }
  return { cron, keep };
}

/// The storage limit per organization from SETDING_ORG_STORAGE_LIMIT_MB
/// (ADR-0070), in bytes: 25 MB by default; `null` (no limit) with `0` or
/// `off`. Throws on any other value that is not a whole number.
function orgStorageLimitBytes() {
  const raw = ($os.getenv("SETDING_ORG_STORAGE_LIMIT_MB") || "").trim();
  if (raw === "") return DEFAULT_ORG_STORAGE_LIMIT_MB * MB;
  if (raw === "0" || raw.toLowerCase() === "off") return null;
  if (!/^[1-9]\d*$/.test(raw)) {
    throw new Error(
      `SETDING_ORG_STORAGE_LIMIT_MB must be a whole number of megabytes, or 0 or "off" for no limit, not "${raw}".`,
    );
  }
  return Number(raw) * MB;
}

/// Refuses to serve without the required configuration, with a message that
/// names what is missing or invalid, and logs the effective storage limit.
function checkConfiguration() {
  const missing = missingVariables();
  if (missing.length > 0) {
    throw new Error(
      `setDING cannot start: missing environment variable(s) ${missing.join(", ")}. ` +
        "Set them in the service's environment (see the self-hosting documentation).",
    );
  }
  const limit = orgStorageLimitBytes();
  const text = limit === null ? "off" : `${limit / MB} MB`;
  console.log(`Storage limit per organization: ${text}`);
}

/// Applies the backup schedule to PocketBase's own automatic backups
/// (Settings → Backups). The environment wins over changes in the admin UI.
function applyBackupSettings(app) {
  const { cron, keep } = backupConfig();
  const settings = app.settings();
  if (settings.backups.cron === cron && settings.backups.cronMaxKeep === keep) return;
  settings.backups.cron = cron;
  settings.backups.cronMaxKeep = keep;
  try {
    app.save(settings);
  } catch (err) {
    throw new Error(`SETDING_BACKUP_CRON "${cron}" is not a valid cron expression: ${err}`);
  }
  app.logger().info(
    "Automatic backups",
    "cron",
    cron === "" ? "off" : cron,
    "keep",
    keep,
  );
}

/// The number of days PocketBase keeps its request logs, from SETDING_LOG_DAYS
/// (default 7); 0 keeps no logs.
function logDays() {
  const raw = ($os.getenv("SETDING_LOG_DAYS") || "").trim();
  if (raw === "") return DEFAULT_LOG_DAYS;
  if (!/^(0|[1-9]\d*)$/.test(raw)) {
    throw new Error(`SETDING_LOG_DAYS must be a whole number of at least 0, not "${raw}".`);
  }
  return Number(raw);
}

/// Applies the log retention to PocketBase's logs (Settings → Logs). The
/// environment wins over changes in the admin UI.
function applyLogSettings(app) {
  const days = logDays();
  const settings = app.settings();
  if (settings.logs.maxDays === days) return;
  settings.logs.maxDays = days;
  app.save(settings);
  app.logger().info("Request logs", "days", days);
}

/// The request headers PocketBase takes the client's IP address from, from
/// SETDING_TRUSTED_PROXY_HEADER (#1195): a header name or a comma-separated
/// list (e.g. "CF-Connecting-IP", "X-Forwarded-For"); "none" for a server
/// that is reached directly, without a proxy (no header trusted). `null`
/// when the variable is empty: the admin UI's setting stays as it is.
function trustedProxyHeaders() {
  const raw = ($os.getenv("SETDING_TRUSTED_PROXY_HEADER") || "").trim();
  if (raw === "") return null;
  if (raw.toLowerCase() === "none") return [];
  const headers = raw.split(",").map((h) => h.trim()).filter((h) => h !== "");
  for (const h of headers) {
    // RFC 9110 field-name token characters.
    if (!/^[A-Za-z0-9!#$%&'*+.^_`|~-]+$/.test(h)) {
      throw new Error(
        `SETDING_TRUSTED_PROXY_HEADER must name HTTP headers (e.g. CF-Connecting-IP) or be "none", not "${raw}".`,
      );
    }
  }
  return headers;
}

/// Applies the trusted proxy header to PocketBase (Settings → Trusted proxy),
/// which the per-IP rate limits depend on behind a reverse proxy or tunnel.
/// The environment wins over changes in the admin UI. Without the variable,
/// the admin UI's setting stays, and an empty one is reported at every start:
/// all clients would then share the proxy's rate-limit bucket.
function applyTrustedProxySettings(app) {
  const headers = trustedProxyHeaders();
  const settings = app.settings();
  const current = Array.from(settings.trustedProxy.headers || []);
  if (headers === null) {
    if (current.length === 0) {
      const message =
        "No trusted proxy header is configured: behind a reverse proxy or tunnel " +
        "every request seems to come from the proxy, and all clients share one " +
        "rate limit. Set SETDING_TRUSTED_PROXY_HEADER (e.g. CF-Connecting-IP or " +
        'X-Forwarded-For), or "none" when the server is reached directly.';
      console.warn(`WARNING: ${message}`);
      app.logger().warn(message);
    }
    return;
  }
  if (current.length === headers.length && current.every((h, i) => h === headers[i])) return;
  settings.trustedProxy.headers = headers;
  app.save(settings);
  app.logger().info("Trusted proxy", "headers", headers.length === 0 ? "none" : headers.join(", "));
}

/// Checks that the server at [url] (default http://127.0.0.1:8090) answers
/// its health endpoint; throws otherwise, so the command exits with 1.
function healthcheck(url) {
  const base = String(url || $os.getenv("SETDING_HEALTH_URL") || DEFAULT_HEALTH_URL).replace(/\/+$/, "");
  let status;
  try {
    status = $http.send({ url: `${base}/api/health`, method: "GET", timeout: 5 }).statusCode;
  } catch (err) {
    throw new Error(`unhealthy: ${base} does not answer (${err})`);
  }
  if (status !== 200) throw new Error(`unhealthy: ${base}/api/health answered ${status}`);
  return `healthy: ${base}`;
}

module.exports = {
  command,
  serving,
  missingVariables,
  backupConfig,
  orgStorageLimitBytes,
  checkConfiguration,
  applyBackupSettings,
  logDays,
  applyLogSettings,
  trustedProxyHeaders,
  applyTrustedProxySettings,
  healthcheck,
};
