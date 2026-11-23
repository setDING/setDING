/// <reference path="../pb_data/types.d.ts" />

// Lineup per set and substitutes (ADR-0061, issue #1007); the logic is in
// lib/lineup.js.

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/lineup.js`).validate(e);
  e.next();
}, "setlists");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/lineup.js`).validate(e);
  e.next();
}, "setlists");

routerAdd("GET", "/api/setding/lineup", (e) =>
  require(`${__hooks}/lib/lineup.js`).substituteSets(e), $apis.requireAuth("users"));

routerAdd("GET", "/api/setding/lineup/{set}/emails", (e) =>
  require(`${__hooks}/lib/lineup.js`).lineupEmails(e), $apis.requireAuth("users"));
