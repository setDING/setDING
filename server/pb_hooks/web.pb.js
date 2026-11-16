/// <reference path="../pb_data/types.d.ts" />

// Web client (ADR-0018); the logic is in lib/web.js. The build itself is
// served by PocketBase from its public directory (pb_public).

// Cross-origin isolation headers for the web client's pages.
routerUse((e) => require(`${__hooks}/lib/web.js`).isolationHeaders(e));
