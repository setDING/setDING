/// <reference path="../pb_data/types.d.ts" />

// Storage limit per organization (ADR-0070, issue #1226):
//
// - A PDF attachment holds at most 1 MB (was 20 MB), a report screenshot at
//   most 300 KB (was 1 MB). Larger files that are already stored stay; the
//   limits apply to new uploads.
// - `size_bytes` of an attachment is set by the server from the uploaded
//   file (pb_hooks/lib/storage.js); existing records get the size of their
//   stored file here, so the usage of an organization can be summed up.
// - Organization admins and librarians may purge a single deleted attachment
//   at once (ADR-0043, lib/trash.js PURGEABLE). The right to purge is the
//   right to delete: band leaders may not delete attachments, so they may
//   not purge them either.
const MB = 1024 * 1024;
const PDF_MAX = 1 * MB;
const PDF_MAX_BEFORE = 20 * MB;
const SCREENSHOT_MAX = 300 * 1024;
const SCREENSHOT_MAX_BEFORE = 1 * MB;
const DELETED = "@request.body.deleted:changed = false))";
const PURGED = "@request.body.deleted:changed = false && @request.body.purged:changed = false))";

/// [rule] with the first [from] replaced by [to]; throws if [rule] does not
/// contain [from], so a migration never silently leaves a rule unchanged
/// (issue #1201).
function replaceInRule(rule, from, to) {
  const i = rule === null ? -1 : rule.indexOf(from);
  if (i < 0) throw new Error(`Rule does not contain: ${from}`);
  return rule.slice(0, i) + to + rule.slice(i + from.length);
}

/// Sets `size_bytes` of every attachment that has a file to the size of the
/// stored file, without touching anything else (no new revision: the value
/// only matters to the server).
function fillSizes(app) {
  const records = app.findRecordsByFilter("attachments", "file != ''", "", 0, 0);
  if (records.length === 0) return;
  const fs = app.newFilesystem();
  try {
    for (const record of records) {
      let size = null;
      try {
        size = fs.attributes(`${record.baseFilesPath()}/${record.getString("file")}`).size;
      } catch (_) {
        size = null; // The file is missing; the value stays.
      }
      if (size === null) continue;
      app
        .db()
        .newQuery("UPDATE attachments SET size_bytes = {:size} WHERE id = {:id}")
        .bind({ size: size, id: record.id })
        .execute();
    }
  } finally {
    fs.close();
  }
}

migrate(
  (app) => {
    const attachments = app.findCollectionByNameOrId("attachments");
    attachments.fields.getByName("file").maxSize = PDF_MAX;
    attachments.updateRule = replaceInRule(attachments.updateRule, DELETED, PURGED);
    app.save(attachments);
    const reports = app.findCollectionByNameOrId("song_reports");
    reports.fields.getByName("screenshot").maxSize = SCREENSHOT_MAX;
    app.save(reports);
    fillSizes(app);
  },
  (app) => {
    const attachments = app.findCollectionByNameOrId("attachments");
    attachments.fields.getByName("file").maxSize = PDF_MAX_BEFORE;
    attachments.updateRule = replaceInRule(attachments.updateRule, PURGED, DELETED);
    app.save(attachments);
    const reports = app.findCollectionByNameOrId("song_reports");
    reports.fields.getByName("screenshot").maxSize = SCREENSHOT_MAX_BEFORE;
    app.save(reports);
  },
);
