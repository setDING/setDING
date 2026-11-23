/// <reference path="../pb_data/types.d.ts" />

// Song review status and mistake reports (ADR-0060, issue #987).
//
// songs: `review_state` ("" = approved, `to_review`), `review_reason` and
// who set them when (`reviewed_by`, `reviewed_at`, set by the server only,
// pb_hooks/song_reports.pb.js). They are written by whoever may edit the
// song (the existing update rule) and are last writer wins: a request that
// changes only them needs no base revision and keeps the last editor
// (pb_hooks/lib/songs.js), like the language version fields of ADR-0053.
//
// song_reports: mistake reports of a song. Everyone of the organization
// reports for themselves; members read only their own reports, librarians,
// organization admins, band leaders and set planners all of the
// organization. The author changes their report (or withdraws it) while it
// is open; whoever may edit the song resolves it. `author`, `resolved_by` and
// `resolved_at` are set by the server. Reports follow their song into the
// trash and out of it (pb_hooks/songs.pb.js) and are purged with it
// (pb_hooks/lib/trash.js). A screenshot is added once, also after the
// create, and never replaced.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const orgs = app.findCollectionByNameOrId("organizations");
    const songs = app.findCollectionByNameOrId("songs");

    songs.fields.add(new SelectField({ name: "review_state", maxSelect: 1, values: ["to_review"] }));
    songs.fields.add(new TextField({ name: "review_reason", max: 200 }));
    songs.fields.add(
      new RelationField({ name: "reviewed_by", collectionId: users.id, maxSelect: 1, cascadeDelete: false }),
    );
    songs.fields.add(new DateField({ name: "reviewed_at" }));
    songs.addIndex("idx_songs_review_state", false, "organization, review_state", "review_state != ''");
    app.save(songs);

    // --- rule building blocks (see 1795300000_roles.js) ---------------------
    let alias = 0;
    const AUTH = `@request.auth.collectionName = "users"`;
    const orgRole = (roles) => {
      const m = `@collection.org_memberships:sr${++alias}`;
      const role = roles.map((r) => `${m}.role ?= "${r}"`).join(" || ");
      return (
        `(${m}.organization ?= organization && ${m}.user ?= @request.auth.id` +
        ` && ${m}.deleted ?= false && (${role}))`
      );
    };
    const bandRoleInOrg = (roles) => {
      const m = `@collection.memberships:sr${++alias}`;
      const role = roles.map((r) => `${m}.role ?= "${r}"`).join(" || ");
      return (
        `(${m}.user ?= @request.auth.id && ${m}.deleted ?= false && (${role})` +
        ` && ${m}.band.organization ?= organization && ${m}.band.deleted ?= false)`
      );
    };
    const orgMember = () => orgRole(["admin", "librarian", "member"]);
    const librarian = () => orgRole(["admin", "librarian"]);
    // Whoever may edit the song (ADR-0023): librarians and organization
    // admins, band leaders their own songs.
    const approver = () =>
      `(${librarian()} || (song.created_by = @request.auth.id && song.updated_by = @request.auth.id` +
      ` && ${bandRoleInOrg(["admin"])}))`;
    const author = "author = @request.auth.id";

    const reports = new Collection({
      type: "base",
      name: "song_reports",
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
        { name: "song", type: "relation", collectionId: songs.id, required: true, maxSelect: 1, cascadeDelete: true },
        { name: "organization", type: "relation", collectionId: orgs.id, required: true, maxSelect: 1, cascadeDelete: true },
        // Empty once the author deleted their account (ADR-0052).
        { name: "author", type: "relation", collectionId: users.id, maxSelect: 1, cascadeDelete: false },
        {
          name: "category",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["chords", "lyrics", "key", "sequence", "tempo", "formatting", "sheet_music", "other"],
        },
        { name: "comment", type: "text", max: 1000 },
        // Where in the song: section, source line, live page, PDF page.
        { name: "location", type: "json", maxSize: 2000 },
        {
          name: "screenshot",
          type: "file",
          maxSelect: 1,
          maxSize: 1024 * 1024,
          mimeTypes: ["image/webp", "image/jpeg", "image/png"],
          protected: true,
        },
        { name: "status", type: "select", required: true, maxSelect: 1, values: ["open", "resolved", "withdrawn"] },
        { name: "resolution", type: "text", max: 1000 },
        { name: "resolved_by", type: "relation", collectionId: users.id, maxSelect: 1, cascadeDelete: false },
        { name: "resolved_at", type: "date" },
        { name: "revision", type: "number", onlyInt: true, min: 0 },
        { name: "updated_by", type: "relation", collectionId: users.id, maxSelect: 1, cascadeDelete: false },
        { name: "deleted", type: "bool" },
        { name: "purged", type: "bool" },
        { name: "created", type: "autodate", onCreate: true, onUpdate: false },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      indexes: [
        "CREATE INDEX idx_song_reports_org_revision ON song_reports (organization, revision)",
        "CREATE INDEX idx_song_reports_song ON song_reports (song)",
      ],
    });

    reports.listRule =
      `${AUTH} && ${orgMember()} && (organization.deleted = false || ${orgRole(["admin"])})` +
      ` && (${author} || ${librarian()} || ${bandRoleInOrg(["admin", "planner"])})`;
    reports.viewRule = reports.listRule;
    reports.createRule =
      `${AUTH} && ${orgMember()} && organization.deleted = false` +
      ` && song.organization = organization && song.deleted = false` +
      ` && (@request.body.author:isset = false || @request.body.author = @request.auth.id)` +
      ` && (@request.body.status:isset = false || @request.body.status = "open")` +
      ` && @request.body.resolution:isset = false && @request.body.resolved_by:isset = false` +
      ` && @request.body.resolved_at:isset = false && @request.body.deleted:isset = false` +
      ` && @request.body.purged:isset = false`;
    const authorFieldsKept =
      `@request.body.category:changed = false && @request.body.comment:changed = false` +
      ` && @request.body.location:changed = false && @request.body.screenshot:isset = false`;
    reports.updateRule =
      `${AUTH} && ${orgMember()} && organization.deleted = false && song.deleted = false` +
      ` && @request.body.song:changed = false && @request.body.organization:changed = false` +
      ` && @request.body.author:changed = false && @request.body.deleted:changed = false` +
      ` && @request.body.purged:changed = false` +
      ` && @request.body.resolved_by:isset = false && @request.body.resolved_at:isset = false` +
      ` && (${author} || ${approver()})` +
      ` && ((${authorFieldsKept}) || (${author} && status = "open"))` +
      ` && (@request.body.resolution:changed = false || ${approver()})` +
      ` && (@request.body.status:changed = false` +
      ` || (@request.body.status = "withdrawn" && ${author} && status = "open")` +
      ` || ((@request.body.status = "open" || @request.body.status = "resolved") && ${approver()}))`;
    reports.deleteRule = null;
    app.save(reports);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId("song_reports"));
    const songs = app.findCollectionByNameOrId("songs");
    songs.removeIndex("idx_songs_review_state");
    for (const name of ["review_state", "review_reason", "reviewed_by", "reviewed_at"]) {
      songs.fields.removeByName(name);
    }
    app.save(songs);
  },
);
