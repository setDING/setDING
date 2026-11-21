/// <reference path="../pb_data/types.d.ts" />

// Set archive (ADR-0043 §1b, issue #707): `origin` is the ID of the set an
// imported set was made from, so importing the same set archive again can
// offer to replace it. Written like the other fields of a set; no new rule.
migrate(
  (app) => {
    const setlists = app.findCollectionByNameOrId("setlists");
    setlists.fields.add(new TextField({ name: "origin", max: 64 }));
    app.save(setlists);
  },
  (app) => {
    const setlists = app.findCollectionByNameOrId("setlists");
    setlists.fields.removeByName("origin");
    app.save(setlists);
  },
);
