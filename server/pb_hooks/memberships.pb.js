/// <reference path="../pb_data/types.d.ts" />

// Band memberships (ADR-0005, ADR-0017): only members of the band's
// organization can be band members, and a band keeps at least one admin.

onRecordCreate((e) => {
  require(`${__hooks}/lib/members.js`).requireOrgMember(e);
  e.next();
}, "memberships");

onRecordUpdate((e) => {
  const members = require(`${__hooks}/lib/members.js`);
  members.keepLastAdmin(e, "memberships", "band");
  members.requireOrgMember(e);
  e.next();
}, "memberships");
