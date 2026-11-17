/// <reference path="../pb_data/types.d.ts" />

// Personal settings per user, synced with the account (ADR-0027).
//
// One record per user; `data` holds the personal settings (layer 4a) as a
// JSON object keyed by setting name. Updates are merged per key by the hook
// in user_settings.pb.js, so devices send only the keys they changed.
// Private: only the user may read and change their settings, not even
// organization admins. Device settings never reach the server.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const AUTH = `@request.auth.collectionName = "users"`;

    const settings = new Collection({
      type: "base",
      name: "user_settings",
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
        "CREATE UNIQUE INDEX idx_user_settings_user ON user_settings (user)",
        "CREATE INDEX idx_user_settings_user_revision ON user_settings (user, revision)",
      ],
    });
    settings.listRule = `${AUTH} && user = @request.auth.id`;
    settings.viewRule = settings.listRule;
    settings.createRule = settings.listRule;
    settings.updateRule =
      `${settings.listRule} && @request.body.user:changed = false`;
    settings.deleteRule = null;
    app.save(settings);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId("user_settings"));
  },
);
