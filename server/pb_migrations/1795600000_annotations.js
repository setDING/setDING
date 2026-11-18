/// <reference path="../pb_data/types.d.ts" />

// Personal freehand annotations (ADR-0032).
//
// One record per user, song and target (the ChordPro text, or one PDF
// attachment); `data` maps stroke IDs to strokes, or to a tombstone
// (`{"deleted": true, "t": <ms>}`) for an erased stroke. Updates are merged
// per stroke ID by the hook in annotations.pb.js, so two devices that drew
// offline keep all strokes. Private like overlays (ADR-0020): only the user
// may read and change them, and only for songs of their organizations.
// Removals of the whole record are soft deletes (with the song or the
// attachment).
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const songs = app.findCollectionByNameOrId("songs");
    const attachments = app.findCollectionByNameOrId("attachments");
    const AUTH = `@request.auth.collectionName = "users"`;
    const m = "@collection.org_memberships:annotationorg";
    const orgMember =
      `(${m}.organization ?= song.organization && ${m}.user ?= @request.auth.id` +
      ` && ${m}.deleted ?= false)`;

    const annotations = new Collection({
      type: "base",
      name: "annotations",
      fields: [
        {
          name: "id",
          type: "text",
          primaryKey: true,
          required: true,
          system: true,
          min: 36,
          max: 36,
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
          autogeneratePattern:
            "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}",
        },
        {
          name: "user",
          type: "relation",
          collectionId: users.id,
          required: true,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: "song",
          type: "relation",
          collectionId: songs.id,
          required: true,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          // Empty for the ChordPro text.
          name: "attachment",
          type: "relation",
          collectionId: attachments.id,
          required: false,
          maxSelect: 1,
          cascadeDelete: true,
        },
        // 1 MB of strokes per user, song and target (ADR-0032).
        { name: "data", type: "json", maxSize: 1000000 },
        { name: "revision", type: "number", onlyInt: true, min: 0 },
        {
          name: "updated_by",
          type: "relation",
          collectionId: users.id,
          maxSelect: 1,
          cascadeDelete: false,
        },
        { name: "deleted", type: "bool" },
        { name: "created", type: "autodate", onCreate: true, onUpdate: false },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_annotations_user_song_attachment ON annotations (user, song, attachment)",
        "CREATE INDEX idx_annotations_user_revision ON annotations (user, revision)",
      ],
    });
    annotations.listRule = `${AUTH} && user = @request.auth.id && ${orgMember}`;
    annotations.viewRule = annotations.listRule;
    annotations.createRule =
      `${annotations.listRule}` +
      ` && (@request.body.attachment:isset = false || @request.body.attachment = ""` +
      ` || @request.body.attachment.song = @request.body.song)`;
    annotations.updateRule =
      `${annotations.listRule}` +
      ` && @request.body.user:changed = false && @request.body.song:changed = false` +
      ` && @request.body.attachment:changed = false`;
    annotations.deleteRule = null;
    app.save(annotations);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId("annotations"));
  },
);
