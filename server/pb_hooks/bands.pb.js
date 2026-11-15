/// <reference path="../pb_data/types.d.ts" />

// The user who creates a band becomes its first admin (ADR-0005). The
// membership is saved in the same transaction as the band.
onRecordCreateExecute((e) => {
  e.next();
  const userId = e.record.getString("updated_by");
  if (!userId) return;
  const membership = new Record(e.app.findCollectionByNameOrId("memberships"));
  membership.set("user", userId);
  membership.set("band", e.record.id);
  membership.set("role", "admin");
  membership.set("updated_by", userId);
  e.app.save(membership);
}, "bands");
