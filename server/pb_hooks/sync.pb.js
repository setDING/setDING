/// <reference path="../pb_data/types.d.ts" />

// Sync fields of ADR-0004 for the synced collections (organizations,
// org_memberships, bands, memberships, songs, attachments, setlists, overlays, arrangements, user_settings, annotations, song_reports, contacts): every
// saved record gets the next server revision, write requests record
// `updated_by`. Clients cannot set either field.

onRecordCreateRequest(
  (e) => require(`${__hooks}/lib/sync.js`).handleWriteRequest(e),
  "organizations", "org_memberships", "bands", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations", "song_reports", "contacts",
);

onRecordUpdateRequest(
  (e) => require(`${__hooks}/lib/sync.js`).handleWriteRequest(e),
  "organizations", "org_memberships", "bands", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations", "song_reports", "contacts",
);

// Songs also keep the revision of their last content change (ADR-0053).
onRecordCreateExecute((e) => {
  const revision = require(`${__hooks}/lib/sync.js`).nextRevision(e.app);
  e.record.set("revision", revision);
  if (e.record.collection().name === "songs") e.record.set("content_revision", revision);
  e.next();
}, "organizations", "org_memberships", "bands", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations", "song_reports", "contacts");

onRecordUpdateExecute((e) => {
  const revision = require(`${__hooks}/lib/sync.js`).nextRevision(e.app);
  e.record.set("revision", revision);
  if (e.record.collection().name === "songs") {
    const songs = require(`${__hooks}/lib/songs.js`);
    e.record.set(
      "content_revision",
      songs.contentChanged(e.record) ? revision : e.record.original().getInt("content_revision"),
    );
  }
  e.next();
}, "organizations", "org_memberships", "bands", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations", "song_reports", "contacts");

// Records of synced collections are never hard-deleted through the API
// (deleteRule = null); a superuser deleting one in the admin UI would leave
// other devices with a stale copy, so it is refused here as well. Bands and
// organizations are deleted with DELETE, which `bands.pb.js` and
// `organizations.pb.js` turn into a soft delete (ADR-0044).
onRecordDeleteRequest((e) => {
  throw new BadRequestError("Set 'deleted' instead of deleting synced records.");
}, "org_memberships", "memberships", "songs", "attachments", "setlists", "overlays", "arrangements", "user_settings", "annotations", "song_reports", "contacts");
