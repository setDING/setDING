// Deleting and restoring bands (ADR-0044). PocketBase runs every hook
// handler in its own context, so handlers load this module with require().

/// Soft-deletes what belongs to [band] when it is deleted: its sets (with
/// the band's `deleted_at`, so the trash and the restore find them), its
/// band arrangements and memberships, and revokes its open invitations.
/// Runs inside the transaction that saves the band, after its new revision,
/// so everything it changes gets a higher revision than the band.
function cascadeDelete(app, band) {
  const by = band.getString("updated_by");
  const at = band.getString("deleted_at");
  for (const set of active(app, "setlists", band.id)) {
    set.set("deleted", true);
    set.set("deleted_at", at);
    set.set("updated_by", by);
    app.save(set);
  }
  for (const collection of ["arrangements", "memberships"]) {
    for (const record of active(app, collection, band.id)) {
      record.set("deleted", true);
      record.set("updated_by", by);
      app.save(record);
    }
  }
  const invites = app.findRecordsByFilter(
    "invites",
    "band = {:band} && revoked = false",
    "",
    0,
    0,
    { band: band.id },
  );
  for (const invite of invites) {
    invite.set("revoked", true);
    app.save(invite);
  }
}

/// Restores what the deletion of [band] removed: the sets deleted with it
/// (same `deleted_at`, not purged), and the arrangements and memberships
/// deleted after the band's deletion revision [deletedRevision] (nothing
/// can change them while the band is deleted). Memberships of people who
/// left the organization meanwhile stay deleted. Invitations stay revoked.
function cascadeRestore(app, band, deletedRevision, deletedAt) {
  const by = band.getString("updated_by");
  const sets = app.findRecordsByFilter(
    "setlists",
    "band = {:band} && deleted = true && purged = false && deleted_at = {:at}",
    "",
    0,
    0,
    { band: band.id, at: deletedAt },
  );
  for (const set of sets) {
    set.set("deleted", false);
    set.set("deleted_at", "");
    set.set("updated_by", by);
    app.save(set);
  }
  const members = require(`${__hooks}/lib/members.js`);
  for (const collection of ["arrangements", "memberships"]) {
    const records = app.findRecordsByFilter(
      collection,
      "band = {:band} && deleted = true && revision > {:since}",
      "",
      0,
      0,
      { band: band.id, since: deletedRevision },
    );
    for (const record of records) {
      if (collection === "memberships" && !members.isOrgMember(app, record)) continue;
      record.set("deleted", false);
      record.set("updated_by", by);
      app.save(record);
    }
  }
}

/// Purges a band deleted more than the trash's retention ago (ADR-0043):
/// marks it purged and hard-deletes its memberships and arrangements; its
/// sets carry the band's `deleted_at` and are purged by the trash itself.
function purge(app, band) {
  band.set("purged", true);
  app.runInTransaction((txApp) => {
    txApp.save(band);
    for (const collection of ["memberships", "arrangements"]) {
      const records = txApp.findRecordsByFilter(
        collection,
        "band = {:band}",
        "",
        0,
        0,
        { band: band.id },
      );
      for (const record of records) txApp.delete(record);
    }
  });
}

function active(app, collection, bandId) {
  return app.findRecordsByFilter(
    collection,
    "band = {:band} && deleted = false",
    "",
    0,
    0,
    { band: bandId },
  );
}

module.exports = { cascadeDelete, cascadeRestore, purge };
