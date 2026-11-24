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
const DEFAULT_HEALTH_URL = "http://127.0.0.1:8090";

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

/// Refuses to serve without the required configuration, with a message that
/// names what is missing.
function checkConfiguration() {
  const missing = missingVariables();
  if (missing.length > 0) {
    throw new Error(
      `setDING cannot start: missing environment variable(s) ${missing.join(", ")}. ` +
        "Set them in the service's environment (see the self-hosting documentation).",
    );
  }
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
  checkConfiguration,
  applyBackupSettings,
  healthcheck,
};
