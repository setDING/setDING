/// <reference path="../pb_data/types.d.ts" />

// Conflict detection for songs (ADR-0004): a client sends the revision its
// change is based on in `revision`. If the server has moved on, the update is
// refused with 409 and the client shows both versions; songs are never
// silently overwritten. Sets use last writer wins and are not checked.
onRecordUpdateRequest((e) => {
  const isUser = e.auth && e.auth.collection().name === "users";
  const base = e.requestInfo().body["revision"];
  if (base === undefined || base === null || base === "") {
    if (isUser) {
      throw new BadRequestError("Missing base revision.", {
        revision: new ValidationError("missing_base_revision", "Send the revision the change is based on."),
      });
    }
  } else if (Number(base) !== e.record.original().getInt("revision")) {
    throw new ApiError(409, "The song was changed on the server.", {
      revision: new ValidationError("conflict", "The song was changed on the server."),
    });
  }
  e.next();
}, "songs");

// Deleting a song removes the personal adjustments of all users
// (ADR-0020), the arrangements of all bands (ADR-0025) and the freehand
// annotations of all users (ADR-0032) for it: soft
// deletes, so the delta pull carries them to the devices. Restoring the song
// (undo, #267) restores the ones its deletion removed: those deleted since
// the song's deletion, i.e. with a higher revision. Ones deleted before stay
// deleted.
onRecordUpdateExecute((e) => {
  const wasDeleted = e.record.original().getBool("deleted");
  const deleting = e.record.getBool("deleted") && !wasDeleted;
  const restoring = !e.record.getBool("deleted") && wasDeleted;
  const deletedAt = e.record.original().getInt("revision");
  e.next();
  if (!deleting && !restoring) return;
  for (const collection of ["overlays", "arrangements", "annotations"]) {
    const records = e.app.findRecordsByFilter(
      collection,
      deleting ? "song = {:song} && deleted = false" : "song = {:song} && deleted = true && revision > {:since}",
      "",
      0,
      0,
      { song: e.record.id, since: deletedAt },
    );
    for (const record of records) {
      record.set("deleted", deleting);
      e.app.save(record);
    }
  }
}, "songs");

// The creator of a song (ADR-0023): band leaders may edit the songs they
// created as long as nobody else has changed them.
onRecordCreateRequest((e) => {
  const userId = require(`${__hooks}/lib/sync.js`).requestUserId(e);
  if (userId) e.record.set("created_by", userId);
  e.next();
}, "songs");
