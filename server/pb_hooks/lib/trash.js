// Trash of ADR-0043. PocketBase runs every hook handler in its own context,
// so handlers load this module with require().

/// Days a deleted song, set or attachment can be restored.
const RETENTION_DAYS = 30;

/// Collections whose deleted records a user may purge at once by setting
/// `purged` (#866). Attachments are purged with their song.
const PURGEABLE = ["songs", "setlists"];

/// Keeps `deleted_at` and `purged` consistent for a write request of a user:
/// `deleted_at` is taken from the client when the record is deleted (it may
/// have been deleted offline; not in the future, now if missing), cleared on
/// restore and otherwise kept. `purged` sent on a deleted song or set
/// (deleted before or with this request) deletes it permanently (#866): its
/// content is cleared like by the daily purge; the update rules allow it to
/// those who may delete the record. Otherwise clients cannot set `purged`,
/// and a purged record cannot be restored. Superusers (operators, tests) are
/// not changed. Returns true if the request purges the record.
function handleTrashRequest(e) {
  if (!(e.auth && e.auth.collection().name === "users")) return false;
  const original = e.record.original();
  const isNew = e.record.isNew();
  const wasDeleted = !isNew && original.getBool("deleted");
  const wasPurged = !isNew && original.getBool("purged");
  const deleted = e.record.getBool("deleted");
  if (wasPurged && !deleted) {
    throw new BadRequestError("The record was purged from the trash.", {
      deleted: new ValidationError("purged", "The record was purged from the trash and cannot be restored."),
    });
  }
  const purging =
    !isNew &&
    !wasPurged &&
    deleted &&
    e.record.getBool("purged") &&
    PURGEABLE.includes(e.record.collection().name);
  e.record.set("purged", wasPurged || purging);
  if (!deleted) {
    e.record.set("deleted_at", "");
  } else if (wasDeleted) {
    e.record.set("deleted_at", original.getString("deleted_at"));
  } else {
    const now = new DateTime();
    const sent = e.record.getDateTime("deleted_at");
    if (sent.isZero() || sent.after(now)) e.record.set("deleted_at", now);
  }
  if (purging) clearContent(e.record);
  return purging;
}

/// Clears what a purged record no longer keeps: the song text, the set
/// items, the attachment file.
function clearContent(record) {
  const name = record.collection().name;
  if (name === "songs") record.set("chordpro", "");
  if (name === "setlists") record.set("items", []);
  if (name === "attachments") record.set("file", "");
}

/// Purges records deleted more than [RETENTION_DAYS] ago: song text, set
/// items and attachment files are removed, the record stays as a tombstone
/// (`purged`) with a new revision, so devices still learn about it. Returns
/// the number of purged records.
function purgeTrash(app) {
  const cutoff = new DateTime().addDate(0, 0, -RETENTION_DAYS);
  let purged = 0;
  // Closed organizations first (ADR-0044): purged for good, with all their
  // records.
  const orgs = app.findRecordsByFilter(
    "organizations",
    "deleted = true && purged = false && deleted_at != '' && deleted_at < {:cutoff}",
    "",
    0,
    0,
    { cutoff: cutoff.string() },
  );
  for (const org of orgs) {
    require(`${__hooks}/lib/organizations.js`).purge(app, org);
    purged++;
  }
  // Bands next (ADR-0044): their sets carry the band's `deleted_at` and
  // are purged below.
  const bands = app.findRecordsByFilter(
    "bands",
    "deleted = true && purged = false && deleted_at != '' && deleted_at < {:cutoff}",
    "",
    0,
    0,
    { cutoff: cutoff.string() },
  );
  for (const band of bands) {
    require(`${__hooks}/lib/bands.js`).purge(app, band);
    purged++;
  }
  for (const name of ["attachments", "setlists", "songs"]) {
    const records = app.findRecordsByFilter(
      name,
      "deleted = true && purged = false && deleted_at != '' && deleted_at < {:cutoff}",
      "",
      0,
      0,
      { cutoff: cutoff.string() },
    );
    for (const record of records) {
      record.set("purged", true);
      clearContent(record);
      app.runInTransaction((txApp) => txApp.save(record));
      purged++;
      if (name === "songs") purged += purgeAttachmentsOf(app, record);
    }
  }
  return purged;
}

/// Attachments of a purged song: a song's deletion does not delete them on
/// the server (the client keeps them with the song), so they are purged with
/// it.
function purgeAttachmentsOf(app, song) {
  const records = app.findRecordsByFilter(
    "attachments",
    "song = {:song} && purged = false",
    "",
    0,
    0,
    { song: song.id },
  );
  for (const record of records) {
    record.set("deleted", true);
    if (record.getString("deleted_at") === "") {
      record.set("deleted_at", song.getString("deleted_at"));
    }
    record.set("purged", true);
    record.set("file", "");
    app.runInTransaction((txApp) => txApp.save(record));
  }
  return records.length;
}

/// Purges one deleted band or closed organization at once (operators,
/// ADR-0044). Returns the number of purged records (0 when it was purged
/// before).
function purgeNow(app, collection, id) {
  if (collection === "organizations") return purgeOrganizationNow(app, id);
  if (collection !== "bands") {
    throw new BadRequestError("Only bands and organizations can be purged at once.");
  }
  let band = null;
  try {
    band = app.findRecordById("bands", String(id || ""));
  } catch (_) {
    throw new NotFoundError("Unknown band.");
  }
  if (!band.getBool("deleted")) {
    throw new BadRequestError("Only deleted bands can be purged.");
  }
  if (band.getBool("purged")) return 0;
  require(`${__hooks}/lib/bands.js`).purge(app, band);
  let sets = 0;
  const records = app.findRecordsByFilter(
    "setlists",
    "band = {:band} && deleted = true && purged = false && deleted_at = {:at}",
    "",
    0,
    0,
    { band: band.id, at: band.getString("deleted_at") },
  );
  for (const record of records) {
    record.set("purged", true);
    record.set("items", []);
    app.runInTransaction((txApp) => txApp.save(record));
    sets++;
  }
  return 1 + sets;
}

function purgeOrganizationNow(app, id) {
  let org = null;
  try {
    org = app.findRecordById("organizations", String(id || ""));
  } catch (_) {
    throw new NotFoundError("Unknown organization.");
  }
  if (!org.getBool("deleted")) {
    throw new BadRequestError("Only closed organizations can be purged.");
  }
  if (org.getBool("purged")) return 0;
  require(`${__hooks}/lib/organizations.js`).purge(app, org);
  return 1;
}

module.exports = { RETENTION_DAYS, handleTrashRequest, purgeTrash, purgeNow, purgeAttachmentsOf };
