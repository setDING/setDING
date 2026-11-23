/// <reference path="../pb_data/types.d.ts" />

// Lineup per set (ADR-0061, issue #1007): the people who play a set.
// `lineup_custom = false` (every existing set, every set of older apps) means
// the whole band and stores nobody in `lineup`; when somebody changes the
// lineup, `lineup_custom` is true and `lineup` holds the chosen people of the
// organization. The collection rules stay as they are: who may edit a set
// edits its lineup, and substitutes get their sets through the route
// `/api/setding/lineup` (pb_hooks/lineup.pb.js), not through the records API.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const setlists = app.findCollectionByNameOrId("setlists");
    setlists.fields.add(
      new RelationField({
        name: "lineup",
        collectionId: users.id,
        maxSelect: 200,
        cascadeDelete: false,
      }),
    );
    setlists.fields.add(new BoolField({ name: "lineup_custom" }));
    app.save(setlists);
  },
  (app) => {
    const setlists = app.findCollectionByNameOrId("setlists");
    setlists.fields.removeByName("lineup");
    setlists.fields.removeByName("lineup_custom");
    app.save(setlists);
  },
);
