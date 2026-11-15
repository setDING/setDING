/// <reference path="../pb_data/types.d.ts" />

// Personal adjustments per user, synced with the account (ADR-0020).
//
// One record per user and song; `data` holds the fields of layer 3
// (ADR-0006) as JSON, so the overlay can grow (e.g. anchored notes) without
// a migration. Overlays are private: only their user may read and change
// them, and only for songs of the user's organizations. Removals are soft
// deletes like the other synced records (ADR-0015).
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const songs = app.findCollectionByNameOrId("songs");
    const AUTH = `@request.auth.collectionName = "users"`;
    const m = "@collection.org_memberships:overlayorg";
    const orgMember =
      `(${m}.organization ?= song.organization && ${m}.user ?= @request.auth.id` +
      ` && ${m}.deleted ?= false)`;

    const overlays = new Collection({
      type: "base",
      name: "overlays",
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
        { name: "data", type: "json", maxSize: 100000 },
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
        "CREATE UNIQUE INDEX idx_overlays_user_song ON overlays (user, song)",
        "CREATE INDEX idx_overlays_user_revision ON overlays (user, revision)",
      ],
    });
    overlays.listRule = `${AUTH} && user = @request.auth.id && ${orgMember}`;
    overlays.viewRule = overlays.listRule;
    overlays.createRule = overlays.listRule;
    overlays.updateRule =
      `${overlays.listRule}` +
      ` && @request.body.user:changed = false && @request.body.song:changed = false`;
    overlays.deleteRule = null;
    app.save(overlays);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId("overlays"));
  },
);
