/// <reference path="../pb_data/types.d.ts" />

// Trash (ADR-0043): deleted songs, sets and attachments can be restored for
// 30 days. `deleted_at` is when the record was deleted (sent by the client,
// which may have deleted it offline), `purged` marks a record whose content
// and file the daily purge removed; it stays as a tombstone for the delta
// sync. A purged attachment has no file any more, so `file` is optional.
// Records deleted before this migration count as deleted now.
migrate(
  (app) => {
    for (const name of ["songs", "setlists", "attachments"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.fields.add(new DateField({ name: "deleted_at" }));
      collection.fields.add(new BoolField({ name: "purged" }));
      if (name === "attachments") {
        collection.fields.getByName("file").required = false;
      }
      app.save(collection);
      app
        .db()
        .newQuery(
          `UPDATE ${name} SET deleted_at = strftime('%Y-%m-%d %H:%M:%fZ', 'now') WHERE deleted = TRUE`,
        )
        .execute();
    }
  },
  (app) => {
    for (const name of ["songs", "setlists", "attachments"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.fields.removeByName("deleted_at");
      collection.fields.removeByName("purged");
      if (name === "attachments") {
        collection.fields.getByName("file").required = true;
      }
      app.save(collection);
    }
  },
);
