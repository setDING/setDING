/// <reference path="../pb_data/types.d.ts" />

// Minimum client version (ADR-0029); the logic is in lib/compat.js.
// Global middlewares run after the auth token is loaded, so superusers are
// recognized.
routerUse((e) => require(`${__hooks}/lib/compat.js`).requireClientVersion(e));
