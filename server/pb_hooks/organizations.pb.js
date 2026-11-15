/// <reference path="../pb_data/types.d.ts" />

// The user who creates an organization becomes its first admin (ADR-0017).
onRecordCreateExecute((e) => {
  e.next();
  const userId = e.record.getString("updated_by");
  if (!userId) return;
  require(`${__hooks}/lib/members.js`).addAdmin(
    e.app, "org_memberships", "organization", e.record.id, userId,
  );
}, "organizations");
