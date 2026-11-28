/// <reference path="../../pb_data/types.d.ts" />

// Storage limit per organization (ADR-0070). PocketBase runs every hook
// handler in its own context, so handlers load this module with require().

/// The organization's PDF attachments that are still on the disk (ADR-0070
/// §3): live ones, deleted ones in the trash and those of deleted songs.
/// `used` is all of them, `live` those of songs in the library.
function usage(app, orgId) {
  const result = new DynamicModel({ used: 0, live: 0 });
  app
    .db()
    .newQuery(
      "SELECT COALESCE(SUM(a.size_bytes), 0) AS used, " +
        "COALESCE(SUM(CASE WHEN a.deleted = FALSE AND COALESCE(s.deleted, FALSE) = FALSE " +
        "THEN a.size_bytes ELSE 0 END), 0) AS live " +
        "FROM attachments a LEFT JOIN songs s ON s.id = a.song " +
        "WHERE a.organization = {:org} AND a.purged = FALSE AND a.file != ''",
    )
    .bind({ org: orgId })
    .one(result);
  return { used: Number(result.used), live: Number(result.live) };
}

/// The files uploaded with the request for [field]; none when there are none.
function uploadedFiles(e, field) {
  try {
    return e.findUploadedFiles(field) || [];
  } catch (_) {
    return [];
  }
}

/// A new attachment (ADR-0070 §4, §5): `size_bytes` is set from the uploaded
/// file, whatever the client sent. For users (superusers are not limited),
/// the upload is refused with `storage_limit_reached` on `file` when it does
/// not fit into the organization's storage limit any more. Runs in the write
/// transaction of the insert (storage.pb.js), so the sum here and the insert
/// cannot interleave with another upload; the file is only written with the
/// insert, so a refused upload leaves none behind.
function checkUpload(e) {
  const files = uploadedFiles(e, "file");
  let size = 0;
  for (const file of files) size += Number(file.size);
  e.record.set("size_bytes", size);
  if (!(e.auth && e.auth.collection().name === "users")) return;
  if (size === 0) return;
  // A file over the maximum size gets PocketBase's own validation error.
  const maxSize = e.record.collection().fields.getByName("file").maxSize;
  if (maxSize > 0 && size > maxSize) return;
  const limit = require(`${__hooks}/lib/operations.js`).orgStorageLimitBytes();
  if (limit === null) return;
  const { used } = usage(e.app, e.record.getString("organization"));
  if (used + size > limit) {
    throw new BadRequestError("The organization's storage is full.", {
      file: new ValidationError(
        "storage_limit_reached",
        "The organization's storage is full. Purge deleted files from the trash or ask the operator.",
      ),
    });
  }
}

/// Whether [userId] may upload PDFs in [orgId] (ADR-0023): an organization
/// admin or librarian, or the leader of one of its bands.
function mayUpload(app, orgId, userId) {
  if (
    app.countRecords(
      "org_memberships",
      $dbx.hashExp({ organization: orgId, user: userId, deleted: false }),
      $dbx.in("role", "admin", "librarian"),
    ) > 0
  ) {
    return true;
  }
  const result = new DynamicModel({ n: 0 });
  app
    .db()
    .newQuery(
      "SELECT COUNT(*) AS n FROM memberships m JOIN bands b ON b.id = m.band " +
        "WHERE m.user = {:user} AND m.deleted = FALSE AND m.role = 'admin' " +
        "AND b.organization = {:org} AND b.deleted = FALSE",
    )
    .bind({ user: userId, org: orgId })
    .one(result);
  if (Number(result.n) === 0) return false;
  // A band leader is a band member only while in the organization.
  return (
    app.countRecords(
      "org_memberships",
      $dbx.hashExp({ organization: orgId, user: userId, deleted: false }),
    ) > 0
  );
}

/// GET /api/setding/organizations/{id}/storage (ADR-0070 §6): the storage
/// the organization uses and its limit, for those who may upload PDFs in it.
/// Everyone else gets 404, as if it did not exist; so does a closed
/// organization, where nobody uploads.
function storage(e) {
  const orgId = e.request.pathValue("id");
  let org = null;
  try {
    org = e.app.findRecordById("organizations", orgId);
  } catch (_) {
    org = null;
  }
  if (!org || org.getBool("deleted") || !mayUpload(e.app, orgId, e.auth.id)) {
    throw new NotFoundError("The requested resource wasn't found.");
  }
  const { used, live } = usage(e.app, orgId);
  return e.json(200, {
    used_bytes: used,
    limit_bytes: require(`${__hooks}/lib/operations.js`).orgStorageLimitBytes(),
    live_bytes: live,
    trash_bytes: used - live,
  });
}

/// A report screenshot over the maximum size (300 KB, ADR-0070 §2) is left
/// out instead of refusing the report: apps from before the limit scale
/// screenshots to 1 MB only, and reporting must not fail on the size.
function dropOversizedScreenshot(e) {
  if (!(e.auth && e.auth.collection().name === "users")) return;
  const maxSize = e.record.collection().fields.getByName("screenshot").maxSize;
  const files = uploadedFiles(e, "screenshot");
  if (maxSize <= 0 || !files.some((f) => Number(f.size) > maxSize)) return;
  e.record.set("screenshot", e.record.isNew() ? "" : e.record.original().getString("screenshot"));
}

module.exports = { usage, checkUpload, mayUpload, storage, dropOversizedScreenshot };
