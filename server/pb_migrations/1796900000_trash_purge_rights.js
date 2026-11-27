/// <reference path="../pb_data/types.d.ts" />

// Deleting permanently from the trash (ADR-0043, #866): a client purges a
// deleted song or set by setting `purged`. The right is the right to delete
// it: a band leader may edit their own songs but not delete them
// (ADR-0023), so they may not purge them either. Set managers may already
// change every field of a set.
const DELETED = "@request.body.deleted:changed = false";
const PURGED = `${DELETED} && @request.body.purged:changed = false`;

/// [rule] with the first [from] replaced by [to]; throws if [rule] does not
/// contain [from], so a migration never silently leaves a rule unchanged
/// (issue #1201).
function replaceInRule(rule, from, to) {
  const i = rule === null ? -1 : rule.indexOf(from);
  if (i < 0) throw new Error(`Rule does not contain: ${from}`);
  return rule.slice(0, i) + to + rule.slice(i + from.length);
}

migrate(
  (app) => {
    const songs = app.findCollectionByNameOrId("songs");
    songs.updateRule = replaceInRule(songs.updateRule, DELETED, PURGED);
    app.save(songs);
  },
  (app) => {
    const songs = app.findCollectionByNameOrId("songs");
    songs.updateRule = replaceInRule(songs.updateRule, PURGED, DELETED);
    app.save(songs);
  },
);
