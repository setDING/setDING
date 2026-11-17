/// <reference path="../pb_data/types.d.ts" />

// Band arrangements (ADR-0025): per band and song the band's key (as a
// transposition relative to the song), sequence and tempo, between the shared
// song and the set item. Band members and organization admins see them; band
// leaders, set planners and organization admins maintain them (ADR-0023).
// Synced per band with last writer wins; removals are soft deletes.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const bands = app.findCollectionByNameOrId("bands");
    const songs = app.findCollectionByNameOrId("songs");

    let alias = 0;
    const AUTH = `@request.auth.collectionName = "users"`;
    const bandRole = (role) => {
      const m = `@collection.memberships:a${++alias}`;
      let rule =
        `${m}.band ?= band && ${m}.user ?= @request.auth.id && ${m}.deleted ?= false`;
      if (role) rule += ` && ${m}.role ?= "${role}"`;
      return `(${rule})`;
    };
    const orgAdmin = () => {
      const m = `@collection.org_memberships:a${++alias}`;
      return (
        `(${m}.organization ?= band.organization && ${m}.user ?= @request.auth.id` +
        ` && ${m}.deleted ?= false && ${m}.role ?= "admin")`
      );
    };
    const manager = `(${bandRole("admin")} || ${bandRole("planner")} || ${orgAdmin()})`;

    const arrangements = new Collection({
      type: "base",
      name: "arrangements",
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
          name: "band",
          type: "relation",
          collectionId: bands.id,
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
        { name: "transpose", type: "number", onlyInt: true, min: -11, max: 11 },
        { name: "sequence", type: "text", max: 2000 },
        { name: "tempo", type: "number", onlyInt: true, min: 0, max: 400 },
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
        "CREATE UNIQUE INDEX idx_arrangements_band_song ON arrangements (band, song)",
        "CREATE INDEX idx_arrangements_band_revision ON arrangements (band, revision)",
      ],
    });
    arrangements.listRule = `${AUTH} && (${bandRole()} || ${orgAdmin()})`;
    arrangements.viewRule = arrangements.listRule;
    arrangements.createRule =
      `${AUTH} && song.organization = band.organization && ${manager}`;
    arrangements.updateRule =
      `${AUTH} && @request.body.band:changed = false && @request.body.song:changed = false` +
      ` && ${manager}`;
    arrangements.deleteRule = null;
    app.save(arrangements);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId("arrangements"));
  },
);
