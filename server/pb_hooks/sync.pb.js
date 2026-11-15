/// <reference path="../pb_data/types.d.ts" />

// Sync fields of ADR-0004 for the synced collections (bands, memberships, songs, attachments, setlists):
// every saved record gets the next server revision, write requests record
// `updated_by`. Clients cannot set either field.

onRecordCreateRequest(
  (e) => require(`${__hooks}/lib/sync.js`).handleWriteRequest(e),
  "bands", "memberships", "songs", "attachments", "setlists",
);

onRecordUpdateRequest(
  (e) => require(`${__hooks}/lib/sync.js`).handleWriteRequest(e),
  "bands", "memberships", "songs", "attachments", "setlists",
);

onRecordCreateExecute((e) => {
  e.record.set("revision", require(`${__hooks}/lib/sync.js`).nextRevision(e.app));
  e.next();
}, "bands", "memberships", "songs", "attachments", "setlists");

onRecordUpdateExecute((e) => {
  e.record.set("revision", require(`${__hooks}/lib/sync.js`).nextRevision(e.app));
  e.next();
}, "bands", "memberships", "songs", "attachments", "setlists");

// Records of synced collections are never hard-deleted through the API
// (deleteRule = null); a superuser deleting one in the admin UI would leave
// other devices with a stale copy, so it is refused here as well.
onRecordDeleteRequest((e) => {
  throw new BadRequestError("Set 'deleted' instead of deleting synced records.");
}, "bands", "memberships", "songs", "attachments", "setlists");
