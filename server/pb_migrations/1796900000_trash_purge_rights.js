/// <reference path="../pb_data/types.d.ts" />

// Deleting permanently from the trash (ADR-0043, #866): a client purges a
// deleted song or set by setting `purged`. The right is the right to delete
// it: a band leader may edit their own songs but not delete them
// (ADR-0023), so they may not purge them either. Set managers may already
// change every field of a set.
const DELETED = "@request.body.deleted:changed = false";
const PURGED = `${DELETED} && @request.body.purged:changed = false`;

migrate(
  (app) => {
    const songs = app.findCollectionByNameOrId("songs");
    if (!songs.updateRule.includes(DELETED)) {
      throw new Error("Unexpected update rule of songs.");
    }
    songs.updateRule = songs.updateRule.replace(DELETED, PURGED);
    app.save(songs);
  },
  (app) => {
    const songs = app.findCollectionByNameOrId("songs");
    songs.updateRule = songs.updateRule.replace(PURGED, DELETED);
    app.save(songs);
  },
);
