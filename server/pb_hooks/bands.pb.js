/// <reference path="../pb_data/types.d.ts" />

// Every band belongs to an organization (ADR-0017). A band created without
// one gets a new organization of the same name with the creator as admin;
// both are saved in the same transaction as the band.
onRecordCreateRequest((e) => {
  e.app.runInTransaction((txApp) => {
    e.app = txApp;
    const userId = require(`${__hooks}/lib/sync.js`).requestUserId(e);
    if (userId && !e.record.getString("organization")) {
      const org = new Record(txApp.findCollectionByNameOrId("organizations"));
      org.set("name", e.record.getString("name"));
      org.set("updated_by", userId);
      txApp.save(org);
      e.record.set("organization", org.id);
    }
    e.next();
  });
}, "bands");

// The user who creates a band becomes its first admin (ADR-0005).
onRecordCreateExecute((e) => {
  e.next();
  const userId = e.record.getString("updated_by");
  if (!userId) return;
  require(`${__hooks}/lib/members.js`).addAdmin(
    e.app, "memberships", "band", e.record.id, userId,
  );
}, "bands");
