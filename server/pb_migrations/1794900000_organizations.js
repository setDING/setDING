/// <reference path="../pb_data/types.d.ts" />

// Organizations with a shared song library (ADR-0017).
//
// Adds `organizations` and `org_memberships`, puts every band into an
// organization, and moves songs, attachments and invitations from the band to
// the organization. The rules replace those of the initial schema
// (ADR-0015, ADR-0005).
//
// Requires empty bands, songs, attachments and invites (true when it was
// written) and is not reversible: restore a backup instead.

migrate(
  (app) => {
    for (const name of ["bands", "songs", "attachments", "invites"]) {
      if (app.countRecords(name) > 0) {
        throw new Error(
          `Migration needs an empty "${name}" collection (ADR-0017); migrate the data by hand.`,
        );
      }
    }

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
    const relation = (name, collection, required = true) => ({
      name,
      type: "relation",
      collectionId: collection.id,
      required,
      maxSelect: 1,
      cascadeDelete: true,
    });

    // --- Rule building blocks (see the initial schema) -------------------------
    let alias = 0;
    const AUTH = `@request.auth.collectionName = "users"`;
    const orgRole = (org, role) => {
      const m = `@collection.org_memberships:o${++alias}`;
      let rule =
        `${m}.organization ?= ${org} && ${m}.user ?= @request.auth.id` +
        ` && ${m}.deleted ?= false`;
      if (role) rule += ` && ${m}.role ?= "${role}"`;
      return `(${rule})`;
    };
    const orgMember = (org) => orgRole(org);
    const orgAdmin = (org) => orgRole(org, "admin");
    const bandRole = (band, role) => {
      const m = `@collection.memberships:b${++alias}`;
      let rule =
        `${m}.band ?= ${band} && ${m}.user ?= @request.auth.id` +
        ` && ${m}.deleted ?= false`;
      if (role) rule += ` && ${m}.role ?= "${role}"`;
      return `(${rule})`;
    };
    const bandMember = (band) => bandRole(band);
    const bandAdmin = (band) => bandRole(band, "admin");
    // Edits the organization's songs: organization admins, admins of any of
    // its bands, members of a band that allows song editing (ADR-0017).
    const songEditor = (org) => {
      const a = `@collection.memberships:e${++alias}`;
      const m = `@collection.memberships:e${++alias}`;
      const bandAdminInOrg =
        `(${a}.user ?= @request.auth.id && ${a}.deleted ?= false` +
        ` && ${a}.role ?= "admin" && ${a}.band.organization ?= ${org}` +
        ` && ${a}.band.deleted ?= false)`;
      const editingMemberInOrg =
        `(${m}.user ?= @request.auth.id && ${m}.deleted ?= false` +
        ` && ${m}.band.organization ?= ${org} && ${m}.band.deleted ?= false` +
        ` && ${m}.band.members_can_edit_songs ?= true)`;
      return `(${orgAdmin(org)} || ${bandAdminInOrg} || ${editingMemberInOrg})`;
    };

    // --- organizations and org_memberships -----------------------------------------
    const organizations = new Collection({
      type: "base",
      name: "organizations",
      fields: [
        UUID,
        { name: "name", type: "text", required: true, max: 200 },
        ...syncFields(),
      ],
      indexes: [
        "CREATE INDEX idx_organizations_revision ON organizations (revision)",
      ],
    });
    app.save(organizations);

    const orgMemberships = new Collection({
      type: "base",
      name: "org_memberships",
      fields: [
        UUID,
        relation("user", users),
        relation("organization", organizations),
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
        "CREATE UNIQUE INDEX idx_org_memberships_user_org ON org_memberships (user, organization)",
        "CREATE INDEX idx_org_memberships_org_revision ON org_memberships (organization, revision)",
      ],
    });
    app.save(orgMemberships);

    organizations.listRule = `${AUTH} && ${orgMember("id")}`;
    organizations.viewRule = organizations.listRule;
    // The creator becomes the first admin (pb_hooks/organizations.pb.js).
    organizations.createRule = AUTH;
    organizations.updateRule = `${AUTH} && ${orgAdmin("id")}`;
    organizations.deleteRule = null;
    app.save(organizations);

    // People are added by hooks only (organization creation, invitations #16).
    orgMemberships.listRule =
      `${AUTH} && (user = @request.auth.id || ${orgMember("organization")})`;
    orgMemberships.viewRule = orgMemberships.listRule;
    orgMemberships.createRule = null;
    orgMemberships.updateRule =
      `${AUTH} && @request.body.user:changed = false` +
      ` && @request.body.organization:changed = false && (` +
      `${orgAdmin("organization")} || (user = @request.auth.id && deleted = false` +
      ` && @request.body.role:changed = false && @request.body.deleted = true))`;
    orgMemberships.deleteRule = null;
    app.save(orgMemberships);

    // --- bands and band memberships ------------------------------------------------
    const bands = app.findCollectionByNameOrId("bands");
    bands.fields.add(new RelationField(relation("organization", organizations)));
    bands.addIndex("idx_bands_organization", false, "organization", "");
    bands.listRule =
      `${AUTH} && (${bandMember("id")} || ${orgAdmin("organization")})`;
    bands.viewRule = bands.listRule;
    // Without an organization, pb_hooks/bands.pb.js creates one (the rule is
    // checked before the hook runs).
    bands.createRule =
      `${AUTH} && (@request.body.organization:isset = false || @request.body.organization = ""` +
      ` || ${orgAdmin("organization")})`;
    bands.updateRule =
      `${AUTH} && @request.body.organization:changed = false` +
      ` && (${bandAdmin("id")} || ${orgAdmin("organization")})`;
    app.save(bands);

    // Band members must be members of the organization
    // (pb_hooks/memberships.pb.js).
    const memberships = app.findCollectionByNameOrId("memberships");
    memberships.listRule =
      `${AUTH} && (user = @request.auth.id || ${bandMember("band")}` +
      ` || ${orgAdmin("band.organization")})`;
    memberships.viewRule = memberships.listRule;
    memberships.createRule =
      `${AUTH} && (${bandAdmin("band")} || ${orgAdmin("band.organization")})`;
    memberships.updateRule =
      `${AUTH} && @request.body.user:changed = false && @request.body.band:changed = false && (` +
      `${bandAdmin("band")} || ${orgAdmin("band.organization")}` +
      ` || (user = @request.auth.id && deleted = false` +
      ` && @request.body.role:changed = false && @request.body.deleted = true))`;
    app.save(memberships);

    // --- setlists: per band ------------------------------------------------------
    const setlists = app.findCollectionByNameOrId("setlists");
    setlists.listRule =
      `${AUTH} && (${bandMember("band")} || ${orgAdmin("band.organization")})`;
    setlists.viewRule = setlists.listRule;
    setlists.createRule =
      `${AUTH} && (${bandAdmin("band")} || ${orgAdmin("band.organization")})`;
    setlists.updateRule =
      `${AUTH} && @request.body.band:changed = false` +
      ` && (${bandAdmin("band")} || ${orgAdmin("band.organization")})`;
    app.save(setlists);

    // --- songs, attachments, invites: per organization ------------------------------
    for (const name of ["invites", "attachments", "songs"]) {
      app.delete(app.findCollectionByNameOrId(name));
    }

    const songs = new Collection({
      type: "base",
      name: "songs",
      fields: [
        UUID,
        relation("organization", organizations),
        { name: "title", type: "text", required: true, max: 500 },
        { name: "chordpro", type: "text", max: 1000000 },
        ...syncFields(),
      ],
      indexes: [
        "CREATE INDEX idx_songs_organization_revision ON songs (organization, revision)",
      ],
    });
    songs.listRule = `${AUTH} && ${orgMember("organization")}`;
    songs.viewRule = songs.listRule;
    songs.createRule = `${AUTH} && ${songEditor("organization")}`;
    songs.updateRule =
      `${AUTH} && ${songEditor("organization")}` +
      ` && @request.body.organization:changed = false` +
      ` && (@request.body.deleted:changed = false || ${orgAdmin("organization")})`;
    songs.deleteRule = null;
    app.save(songs);

    const attachments = new Collection({
      type: "base",
      name: "attachments",
      fields: [
        UUID,
        relation("organization", organizations),
        relation("song", songs),
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
        "CREATE INDEX idx_attachments_organization_revision ON attachments (organization, revision)",
        "CREATE INDEX idx_attachments_song ON attachments (song)",
      ],
    });
    attachments.listRule = `${AUTH} && ${orgMember("organization")}`;
    attachments.viewRule = attachments.listRule;
    attachments.createRule =
      `${AUTH} && song.organization = organization && ${songEditor("organization")}`;
    attachments.updateRule =
      `${AUTH} && ${songEditor("organization")}` +
      ` && @request.body.organization:changed = false && @request.body.song:changed = false` +
      ` && (@request.body.deleted:changed = false || ${orgAdmin("organization")})`;
    attachments.deleteRule = null;
    app.save(attachments);

    const invites = new Collection({
      type: "base",
      name: "invites",
      fields: [
        UUID,
        relation("organization", organizations),
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
        "CREATE INDEX idx_invites_organization ON invites (organization)",
      ],
    });
    invites.listRule = `${AUTH} && ${orgAdmin("organization")}`;
    invites.viewRule = invites.listRule;
    invites.createRule = null;
    invites.updateRule = null;
    invites.deleteRule = null;
    app.save(invites);

    // --- users: people of the own organizations -------------------------------------
    users.listRule =
      `id = @request.auth.id || (` +
      `@collection.org_memberships:mine.user ?= @request.auth.id` +
      ` && @collection.org_memberships:mine.deleted ?= false` +
      ` && @collection.org_memberships:theirs.user ?= id` +
      ` && @collection.org_memberships:theirs.deleted ?= false` +
      ` && @collection.org_memberships:theirs.organization ?= @collection.org_memberships:mine.organization)`;
    users.viewRule = users.listRule;
    app.save(users);
  },
  () => {
    throw new Error("1794900000_organizations is not reversible; restore a backup.");
  },
);
