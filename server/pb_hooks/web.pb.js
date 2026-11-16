/// <reference path="../pb_data/types.d.ts" />

// Web client (ADR-0018); the logic is in lib/web.js. The build itself is
// served by PocketBase from its public directory (pb_public).

// Isolation and cache headers for the web client's files.
routerUse((e) => require(`${__hooks}/lib/web.js`).webHeaders(e));
