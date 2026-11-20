/// <reference path="../pb_data/types.d.ts" />

// Every band belongs to an organization (ADR-0017). A band created without
// one gets a new organization of the same name with the creator as admin;
// both are saved in the same transaction as the band. On an invite-only
// server this is refused: organizations come from founder invitations
// (ADR-0024).
onRecordCreateRequest((e) => {
  e.app.runInTransaction((txApp) => {
    e.app = txApp;
    const userId = require(`${__hooks}/lib/sync.js`).requestUserId(e);
    if (userId && !e.record.getString("organization")) {
      // Not on an invite-only server (ADR-0024).
      require(`${__hooks}/lib/registration.js`).requireOrganizationCreation(e);
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

// Deleting a band (ADR-0044): DELETE on the records API (organization
// admins, `deleteRule`; superusers in the admin UI too) is a soft delete
// that keeps the band 30 days in the trash; it answers 204 like a delete.
onRecordDeleteRequest((e) => {
  if (!e.record.getBool("deleted")) {
    e.record.set("deleted", true);
    e.record.set("deleted_at", new DateTime());
    e.record.set("updated_by", require(`${__hooks}/lib/sync.js`).requestUserId(e));
    e.app.runInTransaction((txApp) => txApp.save(e.record));
  }
  return e.noContent(204);
}, "bands");

// The cascade of deleting and restoring a band (ADR-0044), in the
// transaction that saves it: deleting takes its sets, arrangements and
// memberships with it and revokes its invitations; restoring (`deleted`
// back to false, organization admins) brings back what went with it. A
// purged band cannot be restored.
onRecordUpdateExecute((e) => {
  const original = e.record.original();
  const wasDeleted = original.getBool("deleted");
  const deleting = e.record.getBool("deleted") && !wasDeleted;
  const restoring = !e.record.getBool("deleted") && wasDeleted;
  if (restoring && original.getBool("purged")) {
    throw new BadRequestError("The band was purged from the trash.", {
      deleted: new ValidationError("purged", "The band was purged from the trash and cannot be restored."),
    });
  }
  if (deleting && e.record.getString("deleted_at") === "") {
    e.record.set("deleted_at", new DateTime());
  }
  if (restoring) e.record.set("deleted_at", "");
  e.next();
  const bands = require(`${__hooks}/lib/bands.js`);
  if (deleting) bands.cascadeDelete(e.app, e.record);
  if (restoring) {
    bands.cascadeRestore(e.app, e.record, original.getInt("revision"), original.getString("deleted_at"));
  }
}, "bands");

// Set planners may change the band's threshold for songs not played for a
// while (ADR-0046, `stale_after_months`) and nothing else of the band; the
// update rule lets them in for this. Band leaders and organization admins are
// not limited here.
onRecordUpdateRequest((e) => {
  const userId = require(`${__hooks}/lib/sync.js`).requestUserId(e);
  if (userId) {
    const role = (collection, filter, params) => {
      try {
        return e.app
          .findFirstRecordByFilter(collection, filter, params)
          .getString("role");
      } catch (_) {
        return "";
      }
    };
    const bandRole = role(
      "memberships",
      "band = {:band} && user = {:user} && deleted = false",
      { band: e.record.id, user: userId },
    );
    const orgRole = role(
      "org_memberships",
      "organization = {:org} && user = {:user} && deleted = false",
      { org: e.record.original().getString("organization"), user: userId },
    );
    if (bandRole === "planner" && orgRole !== "admin") {
      const allowed = ["stale_after_months"];
      const sent = Object.keys(e.requestInfo().body || {});
      const other = sent.filter((key) => allowed.indexOf(key) < 0);
      if (other.length > 0) {
        throw new ForbiddenError(
          "Set planners may only change when songs count as not played for a while.",
        );
      }
    }
  }
  e.next();
}, "bands");
