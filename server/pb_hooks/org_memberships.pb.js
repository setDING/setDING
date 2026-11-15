/// <reference path="../pb_data/types.d.ts" />

// Every organization keeps at least one admin; a person who leaves or is
// removed from an organization also leaves its bands (ADR-0017).
onRecordUpdate((e) => {
  require(`${__hooks}/lib/members.js`).keepLastAdmin(e, "org_memberships", "organization");
  const left = !e.record.original().getBool("deleted") && e.record.getBool("deleted");
  e.next();
  if (!left) return;
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
}, "org_memberships");
