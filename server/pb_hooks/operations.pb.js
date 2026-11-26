/// <reference path="../pb_data/types.d.ts" />

// Configuration check, automatic backups and the health check for running
// the server without an installer (ADR-0063); the logic is in
// lib/operations.js.

// Only `serve` needs the configuration; console commands (superuser upsert,
// founder-invite, healthcheck) keep working without it.
onBootstrap((e) => {
  const ops = require(`${__hooks}/lib/operations.js`);
  if (ops.serving()) ops.checkConfiguration();
  e.next();
  if (ops.serving()) {
    ops.applyBackupSettings(e.app);
    ops.applyLogSettings(e.app);
  }
});

//   pocketbase healthcheck [url]      default http://127.0.0.1:8090
// Exit code 0 when the server answers /api/health, 1 otherwise (Docker
// HEALTHCHECK, monitoring).
$app.rootCmd.addCommand(new Command({
  use: "healthcheck [url]",
  short: "Checks that the setDING server answers its health endpoint",
  silenceUsage: true,
  runE: (cmd, args) => {
    console.log(require(`${__hooks}/lib/operations.js`).healthcheck((args || [])[0]));
  },
}));
