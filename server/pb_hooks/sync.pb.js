/// <reference path="../pb_data/types.d.ts" />

// Sync fields of ADR-0004 for the synced collections (organizations,
// org_memberships, bands, memberships, songs, attachments, setlists, overlays, arrangements, user_settings, annotations): every
// saved record gets the next server revision, write requests record
// `updated_by`. Clients cannot set either field.

onRecordCreateRequest(
  (e) => require(`${__hooks}/lib/sync.js`).handleWriteRequest(e),
  "organizations", "org_memberships", "bands", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations",
);

onRecordUpdateRequest(
  (e) => require(`${__hooks}/lib/sync.js`).handleWriteRequest(e),
  "organizations", "org_memberships", "bands", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations",
);

onRecordCreateExecute((e) => {
  e.record.set("revision", require(`${__hooks}/lib/sync.js`).nextRevision(e.app));
  e.next();
}, "organizations", "org_memberships", "bands", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations");

onRecordUpdateExecute((e) => {
  e.record.set("revision", require(`${__hooks}/lib/sync.js`).nextRevision(e.app));
  e.next();
}, "organizations", "org_memberships", "bands", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations");

// Records of synced collections are never hard-deleted through the API
// (deleteRule = null); a superuser deleting one in the admin UI would leave
// other devices with a stale copy, so it is refused here as well. Bands are
// deleted with DELETE, which `bands.pb.js` turns into a soft delete
// (ADR-0044).
onRecordDeleteRequest((e) => {
  throw new BadRequestError("Set 'deleted' instead of deleting synced records.");
}, "organizations", "org_memberships", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations");
