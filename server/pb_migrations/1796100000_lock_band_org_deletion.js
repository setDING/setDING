/// <reference path="../pb_data/types.d.ts" />

// Bands and organizations cannot be deleted through the API (issue #627):
// the app offers neither action and ADR-0023's permission matrix does not
// grant it, but the update rules let band leaders and organization admins
// set `deleted`. Deleting a band and closing an organization become
// features of their own, with their rules decided then.
const LOCK = " && @request.body.deleted:changed = false";

migrate(
  (app) => {
    for (const name of ["bands", "organizations"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.updateRule += LOCK;
      app.save(collection);
    }
  },
  (app) => {
    for (const name of ["bands", "organizations"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.updateRule = collection.updateRule.replace(LOCK, "");
      app.save(collection);
    }
  },
);
