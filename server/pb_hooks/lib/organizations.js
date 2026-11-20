// Closing and restoring organizations (ADR-0044). PocketBase runs every
// hook handler in its own context, so handlers load this module with
// require().

/// Soft-deletes the content of [org] when it is closed, with the
/// organization's `deleted_at`: its bands (whose own cascade takes their
/// sets, arrangements and memberships), its songs (whose cascade takes
/// everyone's personal adjustments, arrangements and annotations) and its
/// attachments; revokes its invitations. Organization memberships stay, so
/// its admins can restore it. Runs in the transaction that saves it.
function cascadeClose(app, org) {
  const at = org.getString("deleted_at");
  const by = org.getString("updated_by");
  for (const collection of ["bands", "songs", "attachments"]) {
    for (const record of find(app, collection, "organization = {:org} && deleted = false", org.id)) {
      record.set("deleted", true);
      record.set("deleted_at", at);
      record.set("updated_by", by);
      app.save(record);
    }
  }
  for (const invite of find(app, "invites", "organization = {:org} && revoked = false", org.id)) {
    invite.set("revoked", true);
    app.save(invite);
  }
}

/// Restores what closing [org] removed: the bands, songs and attachments
/// with the closing's `deleted_at` that were not purged; their own hooks
/// restore what went with them. Records deleted before stay deleted;
/// invitations stay revoked.
function cascadeRestore(app, org, deletedAt) {
  const by = org.getString("updated_by");
  for (const collection of ["bands", "songs", "attachments"]) {
    const records = app.findRecordsByFilter(
      collection,
      "organization = {:org} && deleted = true && purged = false && deleted_at = {:at}",
      "",
      0,
      0,
      { org: org.id, at: deletedAt },
    );
    for (const record of records) {
      record.set("deleted", false);
      record.set("deleted_at", "");
      record.set("updated_by", by);
      app.save(record);
    }
  }
}

/// Purges a closed organization for good (ADR-0044): every record of it is
/// hard-deleted, attachment files with their records; the organization
/// stays as a tombstone without a name (`purged`), so devices that were
/// offline still learn about the closing. User accounts stay.
function purge(app, org) {
  app.runInTransaction((txApp) => {
    const byOrg = { org: org.id };
    const steps = [
      ["overlays", "song.organization = {:org}"],
      ["annotations", "song.organization = {:org}"],
      ["arrangements", "band.organization = {:org} || song.organization = {:org}"],
      ["attachments", "organization = {:org}"],
      ["setlists", "band.organization = {:org}"],
      ["memberships", "band.organization = {:org}"],
      ["invites", "organization = {:org}"],
      ["bands", "organization = {:org}"],
      ["songs", "organization = {:org}"],
      ["org_memberships", "organization = {:org}"],
    ];
    for (const [collection, filter] of steps) {
      for (const record of txApp.findRecordsByFilter(collection, filter, "", 0, 0, byOrg)) {
        txApp.delete(record);
      }
    }
    org.set("name", "");
    org.set("purged", true);
    txApp.saveNoValidate(org);
  });
}

function find(app, collection, filter, orgId) {
  return app.findRecordsByFilter(collection, filter, "", 0, 0, { org: orgId });
}

module.exports = { cascadeClose, cascadeRestore, purge };
