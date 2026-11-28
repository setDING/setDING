/// <reference path="../pb_data/types.d.ts" />

// Mistake reports of songs (ADR-0060). The access rules decide who may do
// what (pb_migrations/1797000000_song_review.js); these hooks keep the
// server-maintained fields: the author is the person who reports, a new
// report is open, and `resolved_by` / `resolved_at` name who resolved it
// and when. A screenshot is added once (also after the create, when it was
// uploaded later from a device that reported offline) and never replaced.

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/storage.js`).dropOversizedScreenshot(e);
  const sync = require(`${__hooks}/lib/sync.js`);
  const userId = sync.requestUserId(e);
  if (userId) e.record.set("author", userId);
  if (e.record.getString("status") === "") e.record.set("status", "open");
  if (userId) {
    e.record.set("status", "open");
    e.record.set("resolution", "");
    e.record.set("resolved_by", "");
    e.record.set("resolved_at", "");
    e.record.set("deleted", false);
    e.record.set("purged", false);
  }
  e.next();
}, "song_reports");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/storage.js`).dropOversizedScreenshot(e);
  const original = e.record.original();
  const status = e.record.getString("status");
  if (status !== original.getString("status")) {
    const resolved = status === "resolved";
    e.record.set("resolved_by", resolved ? require(`${__hooks}/lib/sync.js`).requestUserId(e) : "");
    e.record.set("resolved_at", resolved ? new DateTime() : "");
  } else {
    e.record.set("resolved_by", original.getString("resolved_by"));
    e.record.set("resolved_at", original.getString("resolved_at"));
  }
  e.next();
}, "song_reports");

onRecordUpdate((e) => {
  const original = e.record.original();
  const purging = e.record.getBool("purged") && !original.getBool("purged");
  const before = original.getString("screenshot");
  if (!purging && before !== "" && e.record.getString("screenshot") !== before) {
    throw new BadRequestError("Screenshots cannot be replaced.", {
      screenshot: new ValidationError("immutable", "Screenshots cannot be replaced."),
    });
  }
  e.next();
}, "song_reports");
