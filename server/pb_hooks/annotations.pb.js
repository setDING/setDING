/// <reference path="../pb_data/types.d.ts" />

// Personal freehand annotations (ADR-0032): an update merges the sent strokes
// into the stored ones by stroke ID (last writer wins per stroke), so two
// devices that annotated the same song offline keep all strokes. Tombstones
// of erased strokes (`{"deleted": true, "t": <ms>}`) are pruned 90 days
// after the erase.

onRecordUpdateRequest((e) => {
  // Handlers run isolated: no top-level constants.
  const TOMBSTONE_DAYS = 90;
  const parse = (record) => {
    try {
      const value = JSON.parse(record.getString("data") || "{}");
      return value && typeof value === "object" && !Array.isArray(value)
        ? value
        : {};
    } catch (_) {
      return {};
    }
  };
  const merged = Object.assign({}, parse(e.record.original()), parse(e.record));
  const cutoff = Date.now() - TOMBSTONE_DAYS * 24 * 60 * 60 * 1000;
  for (const id of Object.keys(merged)) {
    const stroke = merged[id];
    if (stroke && stroke.deleted === true && Number(stroke.t || 0) < cutoff) {
      delete merged[id];
    }
  }
  e.record.set("data", merged);
  e.next();
}, "annotations");

// Deleting an attachment removes the annotations of all users on it; a
// restore (undo, #267) brings back the ones its deletion removed, as for
// songs (songs.pb.js).
onRecordUpdateExecute((e) => {
  const wasDeleted = e.record.original().getBool("deleted");
  const deleting = e.record.getBool("deleted") && !wasDeleted;
  const restoring = !e.record.getBool("deleted") && wasDeleted;
  const deletedAt = e.record.original().getInt("revision");
  e.next();
  if (!deleting && !restoring) return;
  const records = e.app.findRecordsByFilter(
    "annotations",
    deleting
      ? "attachment = {:attachment} && deleted = false"
      : "attachment = {:attachment} && deleted = true && revision > {:since}",
    "",
    0,
    0,
    { attachment: e.record.id, since: deletedAt },
  );
  for (const record of records) {
    record.set("deleted", deleting);
    e.app.save(record);
  }
}, "attachments");
