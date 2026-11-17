/// <reference path="../pb_data/types.d.ts" />

// Initial setDING data model (ADR-0004, ADR-0005, ADR-0009, ADR-0015).
//
// Synced collections (bands, memberships, songs, attachments, setlists) share the
// sync fields of ADR-0004: a client-generated UUID `id`, a server-assigned
// `revision` (pb_hooks/sync.pb.js), `updated_by`, the soft-delete flag `deleted`
// and the autodate fields `created` and `updated`. Records are never hard-deleted
// through the API; clients set `deleted` instead.
//
// Access rules enforce the permissions of ADR-0005 on the server. They are
// tested in server/test/.

migrate(
  (app) => {
    const UUID = {
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
    };

    const users = app.findCollectionByNameOrId("users");

    const syncFields = () => [
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
    ];

    // --- Rule building blocks -------------------------------------------------
    // Each use of a membership condition gets its own join alias, so that the
    // conditions of one block always refer to the same membership row.
    let alias = 0;
    const membership = (band, role) => {
      const m = `@collection.memberships:m${++alias}`;
      let rule =
        `${m}.band ?= ${band} && ${m}.user ?= @request.auth.id` +
        ` && ${m}.deleted ?= false`;
      if (role) rule += ` && ${m}.role ?= "${role}"`;
      return `(${rule})`;
    };
    const AUTH = `@request.auth.collectionName = "users"`;
    const member = (band) => membership(band);
    const admin = (band) => membership(band, "admin");
    // Admins always; members only if the band allows it (ADR-0005).
    const editor = (band, bandRel) =>
      `(${admin(band)} || (${member(band)} && ${bandRel}.members_can_edit_songs = true))`;
    // Soft delete (and undelete) is reserved for admins.
    const deleteByAdmin = (band) =>
      `(@request.body.deleted:changed = false || ${admin(band)})`;

    // --- Revision counter -------------------------------------------------------
    // One server-wide counter; pb_hooks/sync.pb.js increments it in the
    // transaction that saves the record (ADR-0004, delta sync).
    app
      .db()
      .newQuery(
        "CREATE TABLE setding_sync (" +
          "id INTEGER PRIMARY KEY CHECK (id = 1), " +
          "revision INTEGER NOT NULL)",
      )
      .execute();
    app
      .db()
      .newQuery("INSERT INTO setding_sync (id, revision) VALUES (1, 0)")
      .execute();

    // --- bands ----------------------------------------------------------------
    const bands = new Collection({
      type: "base",
      name: "bands",
      fields: [
        UUID,
        { name: "name", type: "text", required: true, max: 200 },
        { name: "members_can_edit_songs", type: "bool" },
        ...syncFields(),
      ],
      indexes: ["CREATE INDEX idx_bands_revision ON bands (revision)"],
    });
    app.save(bands);

    // --- memberships ------------------------------------------------------------
    const memberships = new Collection({
      type: "base",
      name: "memberships",
      fields: [
        UUID,
        {
          name: "user",
          type: "relation",
          collectionId: users.id,
          required: true,
          maxSelect: 1,
          cascadeDelete: true,
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
          name: "role",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["admin", "member"],
        },
        ...syncFields(),
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_memberships_user_band ON memberships (user, band)",
        "CREATE INDEX idx_memberships_band_revision ON memberships (band, revision)",
      ],
    });
    app.save(memberships);

    // Rules that reference memberships can only be set once it exists.
    bands.listRule = `${AUTH} && ${member("id")}`;
    bands.viewRule = bands.listRule;
    // The creator becomes the band's first admin (pb_hooks/bands.pb.js).
    bands.createRule = AUTH;
    bands.updateRule = `${AUTH} && ${admin("id")}`;
    bands.deleteRule = null;
    app.save(bands);

    // Memberships are created by hooks only (band creation, invitations).
    // Admins change roles and remove members; members may leave a band.
    // The last admin of a band cannot be removed (pb_hooks/memberships.pb.js).
    memberships.listRule = `${AUTH} && (user = @request.auth.id || ${member("band")})`;
    memberships.viewRule = memberships.listRule;
    memberships.createRule = null;
    memberships.updateRule =
      `${AUTH} && @request.body.user:changed = false && @request.body.band:changed = false && (` +
      `${admin("band")} || (user = @request.auth.id && deleted = false` +
      ` && @request.body.role:changed = false && @request.body.deleted = true))`;
    memberships.deleteRule = null;
    app.save(memberships);

    // --- songs ------------------------------------------------------------------
    const songs = new Collection({
      type: "base",
      name: "songs",
      fields: [
        UUID,
        {
          name: "band",
          type: "relation",
          collectionId: bands.id,
          required: true,
          maxSelect: 1,
          cascadeDelete: true,
        },
        // Redundant copy of {title} for the admin UI and conflict dialogs; the
        // ChordPro text is the single source of truth (ADR-0003).
        { name: "title", type: "text", required: true, max: 500 },
        { name: "chordpro", type: "text", max: 1000000 },
        ...syncFields(),
      ],
      indexes: ["CREATE INDEX idx_songs_band_revision ON songs (band, revision)"],
    });
    songs.listRule = `${AUTH} && ${member("band")}`;
    songs.viewRule = songs.listRule;
    songs.createRule = `${AUTH} && ${editor("band", "band")}`;
    songs.updateRule =
      `${AUTH} && ${editor("band", "band")} && @request.body.band:changed = false` +
      ` && ${deleteByAdmin("band")}`;
    songs.deleteRule = null;
    app.save(songs);

    // --- attachments (PDF sheet music, ADR-0009) ----------------------------------
    // `band` is redundant to `song.band` so that delta sync can filter by band.
    // Files are immutable: a new file is a new attachment record
    // (pb_hooks/attachments.pb.js).
    const attachments = new Collection({
      type: "base",
      name: "attachments",
      fields: [
        UUID,
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
        { name: "name", type: "text", required: true, max: 500 },
        {
          name: "file",
          type: "file",
          required: true,
          maxSelect: 1,
          maxSize: 20 * 1024 * 1024,
          mimeTypes: ["application/pdf"],
          protected: true,
        },
        { name: "pages", type: "number", onlyInt: true, min: 0 },
        { name: "size_bytes", type: "number", onlyInt: true, min: 0 },
        ...syncFields(),
      ],
      indexes: [
        "CREATE INDEX idx_attachments_band_revision ON attachments (band, revision)",
        "CREATE INDEX idx_attachments_song ON attachments (song)",
      ],
    });
    attachments.listRule = `${AUTH} && ${member("band")}`;
    attachments.viewRule = attachments.listRule;
    attachments.createRule = `${AUTH} && song.band = band && ${editor("band", "band")}`;
    attachments.updateRule =
      `${AUTH} && ${editor("band", "band")} && @request.body.band:changed = false` +
      ` && @request.body.song:changed = false && ${deleteByAdmin("band")}`;
    attachments.deleteRule = null;
    app.save(attachments);

    // --- setlists ---------------------------------------------------------------
    // The ordered items of a set are stored as one JSON array, so that a set is
    // always synced as a whole (last writer wins, ADR-0004, ADR-0015).
    const setlists = new Collection({
      type: "base",
      name: "setlists",
      fields: [
        UUID,
        {
          name: "band",
          type: "relation",
          collectionId: bands.id,
          required: true,
          maxSelect: 1,
          cascadeDelete: true,
        },
        { name: "name", type: "text", required: true, max: 500 },
        { name: "gig_date", type: "date" },
        { name: "venue", type: "text", max: 500 },
        { name: "items", type: "json", maxSize: 1000000 },
        ...syncFields(),
      ],
      indexes: [
        "CREATE INDEX idx_setlists_band_revision ON setlists (band, revision)",
      ],
    });
    setlists.listRule = `${AUTH} && ${member("band")}`;
    setlists.viewRule = setlists.listRule;
    setlists.createRule = `${AUTH} && ${admin("band")}`;
    setlists.updateRule = `${AUTH} && ${admin("band")} && @request.body.band:changed = false`;
    setlists.deleteRule = null;
    app.save(setlists);

    // --- invites (ADR-0005) -------------------------------------------------------
    // Only the hash of the token is stored. Creating, revoking and redeeming
    // invitations is implemented with hooks in a later step (issue #16); until
    // then only admins can list the invitations of their band.
    const invites = new Collection({
      type: "base",
      name: "invites",
      fields: [
        UUID,
        {
          name: "band",
          type: "relation",
          collectionId: bands.id,
          required: true,
          maxSelect: 1,
          cascadeDelete: true,
        },
        { name: "token_hash", type: "text", required: true, hidden: true },
        { name: "expires", type: "date", required: true },
        { name: "revoked", type: "bool" },
        {
          name: "created_by",
          type: "relation",
          collectionId: users.id,
          maxSelect: 1,
          cascadeDelete: false,
        },
        { name: "created", type: "autodate", onCreate: true, onUpdate: false },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_invites_token_hash ON invites (token_hash)",
        "CREATE INDEX idx_invites_band ON invites (band)",
      ],
    });
    invites.listRule = `${AUTH} && ${admin("band")}`;
    invites.viewRule = invites.listRule;
    invites.createRule = null;
    invites.updateRule = null;
    invites.deleteRule = null;
    app.save(invites);

    // --- users ------------------------------------------------------------------
    // Users see their own account and the accounts of their bandmates (names in
    // the member list). Sign-up stays open (createRule of the default collection).
    users.listRule =
      `id = @request.auth.id || (` +
      `@collection.memberships:mine.user ?= @request.auth.id` +
      ` && @collection.memberships:mine.deleted ?= false` +
      ` && @collection.memberships:theirs.user ?= id` +
      ` && @collection.memberships:theirs.deleted ?= false` +
      ` && @collection.memberships:theirs.band ?= @collection.memberships:mine.band)`;
    users.viewRule = users.listRule;
    app.save(users);
  },
  (app) => {
    for (const name of [
      "invites",
      "setlists",
      "attachments",
      "songs",
      "memberships",
      "bands",
    ]) {
      app.delete(app.findCollectionByNameOrId(name));
    }
    app.db().newQuery("DROP TABLE setding_sync").execute();

    const users = app.findCollectionByNameOrId("users");
    users.listRule = "id = @request.auth.id";
    users.viewRule = "id = @request.auth.id";
    app.save(users);
  },
);
