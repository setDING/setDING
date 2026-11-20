/// <reference path="../pb_data/types.d.ts" />

// Deleting bands (ADR-0044, issue #628): organization admins delete a band
// with DELETE on the records API; the hook in `pb_hooks/bands.pb.js` turns
// it into a soft delete with a cascade, kept 30 days in the trash
// (ADR-0043). `deleted_at` and `purged` are set by the server only.
//
// - bands: DELETE for active organization admins of the band's
//   organization; an update of a deleted band is only its restore
//   (`deleted` back to false, organization admins, not purged); `deleted`
//   cannot be set to true by PATCH (#627).
// - setlists, arrangements, memberships: no writes into a deleted band.
const LOCK = " && @request.body.deleted:changed = false";

const ORG_ADMIN =
  '(@collection.org_memberships:bandadmin.organization ?= organization' +
  " && @collection.org_memberships:bandadmin.user ?= @request.auth.id" +
  " && @collection.org_memberships:bandadmin.deleted ?= false" +
  ' && @collection.org_memberships:bandadmin.role ?= "admin")';

const BAND_UPDATE =
  " && @request.body.deleted_at:isset = false && @request.body.purged:isset = false" +
  " && ((deleted = false && @request.body.deleted:changed = false)" +
  ` || (deleted = true && purged = false && @request.body.deleted = false && ${ORG_ADMIN}))`;

const LIVE_BAND = " && band.deleted = false";

migrate(
  (app) => {
    const bands = app.findCollectionByNameOrId("bands");
    bands.fields.add(new DateField({ name: "deleted_at" }));
    bands.fields.add(new BoolField({ name: "purged" }));
    bands.updateRule = bands.updateRule.replace(LOCK, BAND_UPDATE);
    bands.deleteRule =
      `@request.auth.collectionName = "users" && deleted = false && ${ORG_ADMIN}`;
    app.save(bands);

    for (const name of ["setlists", "arrangements", "memberships"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.createRule += LIVE_BAND;
      collection.updateRule += LIVE_BAND;
      app.save(collection);
    }
  },
  (app) => {
    const bands = app.findCollectionByNameOrId("bands");
    bands.fields.removeByName("deleted_at");
    bands.fields.removeByName("purged");
    bands.updateRule = bands.updateRule.replace(BAND_UPDATE, LOCK);
    bands.deleteRule = null;
    app.save(bands);

    for (const name of ["setlists", "arrangements", "memberships"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.createRule = collection.createRule.replace(LIVE_BAND, "");
      collection.updateRule = collection.updateRule.replace(LIVE_BAND, "");
      app.save(collection);
    }
  },
);
