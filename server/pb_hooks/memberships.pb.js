/// <reference path="../pb_data/types.d.ts" />

// Band memberships (ADR-0005, ADR-0017): only members of the band's
// organization can be band members, and a band keeps at least one admin.
// A leader who loses the lead also loses the open invitations they created
// for the band (issue #1193).

onRecordCreate((e) => {
  require(`${__hooks}/lib/members.js`).requireOrgMember(e);
  e.next();
}, "memberships");

onRecordUpdate((e) => {
  const members = require(`${__hooks}/lib/members.js`);
  members.keepLastAdmin(e, "memberships", "band");
  members.requireOrgMember(e);
  const invites = require(`${__hooks}/lib/invites.js`);
  const lost = invites.lostAdmin(e.record);
  e.next();
  if (lost) {
    invites.revokeLostRights(e.app, e.record.getString("user"), { band: e.record.getString("band") });
  }
}, "memberships");
