/// <reference path="../pb_data/types.d.ts" />

// Song play history across the bands of an organization (ADR-0046, #662);
// the logic is in lib/plays.js.
routerAdd("GET", "/api/setding/plays/{organization}", (e) =>
  require(`${__hooks}/lib/plays.js`).plays(e), $apis.requireAuth("users"));
