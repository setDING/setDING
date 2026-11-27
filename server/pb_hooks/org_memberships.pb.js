/// <reference path="../pb_data/types.d.ts" />

// Every organization keeps at least one admin; a person who leaves or is
// removed from an organization also leaves its bands (ADR-0017). An admin
// who loses the role also loses the open invitations they created there,
// except those of bands they still lead (issue #1193).
onRecordUpdate((e) => {
  require(`${__hooks}/lib/members.js`).keepLastAdmin(e, "org_memberships", "organization");
  const invites = require(`${__hooks}/lib/invites.js`);
  const lost = invites.lostAdmin(e.record);
  const left = !e.record.original().getBool("deleted") && e.record.getBool("deleted");
  e.next();
  if (left) {
    const bandMemberships = e.app.findRecordsByFilter(
      "memberships",
      "user = {:user} && band.organization = {:org} && deleted = false",
      "",
      0,
      0,
      { user: e.record.getString("user"), org: e.record.getString("organization") },
    );
    for (const m of bandMemberships) {
      m.set("deleted", true);
      e.app.saveNoValidate(m);
    }
  }
  if (lost) {
    invites.revokeLostRights(e.app, e.record.getString("user"), {
      organization: e.record.getString("organization"),
    });
  }
}, "org_memberships");
