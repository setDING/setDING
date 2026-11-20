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

// Closing an organization (ADR-0044): DELETE on the records API (any of
// its admins, `deleteRule`; superusers in the admin UI too) is a soft
// delete that keeps it 30 days in the trash; it answers 204 like a delete.
onRecordDeleteRequest((e) => {
  if (!e.record.getBool("deleted")) {
    e.record.set("deleted", true);
    e.record.set("deleted_at", new DateTime());
    e.record.set("updated_by", require(`${__hooks}/lib/sync.js`).requestUserId(e));
    e.app.runInTransaction((txApp) => txApp.save(e.record));
  }
  return e.noContent(204);
}, "organizations");

// The cascade of closing and restoring an organization (ADR-0044), in the
// transaction that saves it. A purged organization cannot be restored.
onRecordUpdateExecute((e) => {
  const original = e.record.original();
  const wasDeleted = original.getBool("deleted");
  const closing = e.record.getBool("deleted") && !wasDeleted;
  const restoring = !e.record.getBool("deleted") && wasDeleted;
  if (restoring && original.getBool("purged")) {
    throw new BadRequestError("The organization was purged from the trash.", {
      deleted: new ValidationError("purged", "The organization was purged from the trash and cannot be restored."),
    });
  }
  if (closing && e.record.getString("deleted_at") === "") {
    e.record.set("deleted_at", new DateTime());
  }
  if (restoring) e.record.set("deleted_at", "");
  e.next();
  const orgs = require(`${__hooks}/lib/organizations.js`);
  if (closing) orgs.cascadeClose(e.app, e.record);
  if (restoring) orgs.cascadeRestore(e.app, e.record, original.getString("deleted_at"));
}, "organizations");
