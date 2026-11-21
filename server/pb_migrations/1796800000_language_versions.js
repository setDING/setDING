/// <reference path="../pb_data/types.d.ts" />

// Language versions of a song (ADR-0053, issue #804).
//
// `work_id` is the shared ID of all language versions of a work (empty = no
// other versions), `language` the language set by hand (empty = detected on
// the device). Both are written like the other fields of a song, by whoever
// may edit it (no new rule), and are last writer wins per field: a request
// that changes only them needs no base revision (pb_hooks/songs.pb.js).
//
// `content_revision` is the revision of the last change of everything else
// (text, title, deletion). The conflict check compares the base revision of
// a change with it instead of `revision`, so linking a song never makes a
// text change of someone else a conflict. Maintained by the server only.
migrate(
  (app) => {
    const songs = app.findCollectionByNameOrId("songs");
    songs.fields.add(
      new TextField({
        name: "work_id",
        max: 36,
        pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
      }),
    );
    songs.fields.add(
      new TextField({ name: "language", max: 8, pattern: "^(de|gsw|en|fr|it|es|pt|nl|other)$" }),
    );
    songs.fields.add(new NumberField({ name: "content_revision", onlyInt: true, min: 0 }));
    songs.addIndex("idx_songs_work_id", false, "work_id", "work_id != ''");
    app.save(songs);
    app.db().newQuery("UPDATE songs SET content_revision = revision").execute();
  },
  (app) => {
    const songs = app.findCollectionByNameOrId("songs");
    songs.removeIndex("idx_songs_work_id");
    songs.fields.removeByName("work_id");
    songs.fields.removeByName("language");
    songs.fields.removeByName("content_revision");
    app.save(songs);
  },
);
