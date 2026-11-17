/// <reference path="../pb_data/types.d.ts" />

// Finer-grained roles (ADR-0023).
//
// Organization roles admin > librarian > member, band roles admin (shown as
// leader) > planner > member. Organization admins may do everything.
// Librarians and organization admins maintain the song library; band leaders
// create songs and edit their own (`created_by`) as long as nobody else has
// changed them (`updated_by`). Set planners manage the band's sets. Band
// leaders invite people into their band (`invites.band`).
//
// Members who could edit songs through the band setting
// `members_can_edit_songs` become librarians of the band's organization; the
// setting is removed. Not reversible: restore a backup instead.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const bands = app.findCollectionByNameOrId("bands");

    // --- rule building blocks (see 1794900000_organizations.js) -------------------
    let alias = 0;
    const AUTH = `@request.auth.collectionName = "users"`;
    const orgRole = (org, role) => {
      const m = `@collection.org_memberships:r${++alias}`;
      return (
        `(${m}.organization ?= ${org} && ${m}.user ?= @request.auth.id` +
        ` && ${m}.deleted ?= false && ${m}.role ?= "${role}")`
      );
    };
    const orgAdmin = (org) => orgRole(org, "admin");
    const librarian = (org) => `(${orgRole(org, "admin")} || ${orgRole(org, "librarian")})`;
    const bandRole = (band, role) => {
      const m = `@collection.memberships:r${++alias}`;
      return (
        `(${m}.band ?= ${band} && ${m}.user ?= @request.auth.id` +
        ` && ${m}.deleted ?= false && ${m}.role ?= "${role}")`
      );
    };
    // Leader of any band of the organization.
    const leaderInOrg = (org) => {
      const a = `@collection.memberships:r${++alias}`;
      return (
        `(${a}.user ?= @request.auth.id && ${a}.deleted ?= false` +
        ` && ${a}.role ?= "admin" && ${a}.band.organization ?= ${org}` +
        ` && ${a}.band.deleted ?= false)`
      );
    };
    // A song the requesting leader created and edited last.
    const ownSong = (prefix) =>
      `(${prefix}created_by = @request.auth.id && ${prefix}updated_by = @request.auth.id)`;

    // --- roles -----------------------------------------------------------------------
    const orgMemberships = app.findCollectionByNameOrId("org_memberships");
    orgMemberships.fields.getByName("role").values = ["admin", "librarian", "member"];
    app.save(orgMemberships);
    const memberships = app.findCollectionByNameOrId("memberships");
    memberships.fields.getByName("role").values = ["admin", "planner", "member"];
    app.save(memberships);

    // --- members_can_edit_songs → librarian ----------------------------------------
    const nextRevision = () => {
      const row = new DynamicModel({ revision: 0 });
      app.db()
        .newQuery("UPDATE realchord_sync SET revision = revision + 1 WHERE id = 1 RETURNING revision")
        .one(row);
      return row.revision;
    };
    const relaxed = app.findRecordsByFilter(
      "bands", "members_can_edit_songs = true && deleted = false", "", 0, 0,
    );
    for (const band of relaxed) {
      const editors = app.findRecordsByFilter(
        "memberships", "band = {:band} && deleted = false", "", 0, 0, { band: band.id },
      );
      for (const m of editors) {
        let org;
        try {
          org = app.findFirstRecordByFilter(
            "org_memberships",
            "user = {:user} && organization = {:org} && deleted = false",
            { user: m.getString("user"), org: band.getString("organization") },
          );
        } catch (_) {
          continue;
        }
        if (org.getString("role") !== "member") continue;
        org.set("role", "librarian");
        org.set("revision", nextRevision());
        app.saveNoValidate(org);
      }
    }

    // --- songs and attachments ------------------------------------------------------
    const songs = app.findCollectionByNameOrId("songs");
    songs.fields.add(
      new RelationField({
        name: "created_by",
        collectionId: users.id,
        maxSelect: 1,
        cascadeDelete: false,
      }),
    );
    songs.createRule =
      `${AUTH} && (${librarian("organization")} || ${leaderInOrg("organization")})`;
    songs.updateRule =
      `${AUTH} && @request.body.organization:changed = false` +
      ` && @request.body.created_by:changed = false` +
      ` && (${librarian("organization")}` +
      ` || (${ownSong("")} && ${leaderInOrg("organization")}` +
      ` && @request.body.deleted:changed = false))`;
    app.save(songs);

    const attachments = app.findCollectionByNameOrId("attachments");
    attachments.createRule =
      `${AUTH} && song.organization = organization && (${librarian("organization")}` +
      ` || (${ownSong("song.")} && ${leaderInOrg("organization")}))`;
    attachments.updateRule =
      `${AUTH} && @request.body.organization:changed = false && @request.body.song:changed = false` +
      ` && (${librarian("organization")}` +
      ` || (${ownSong("song.")} && ${leaderInOrg("organization")}` +
      ` && @request.body.deleted:changed = false))`;
    app.save(attachments);

    // --- sets: band leaders and set planners -----------------------------------------
    const setlists = app.findCollectionByNameOrId("setlists");
    const setManager = (band) =>
      `(${bandRole(band, "admin")} || ${bandRole(band, "planner")} || ${orgAdmin(`${band}.organization`)})`;
    setlists.createRule = `${AUTH} && ${setManager("band")}`;
    setlists.updateRule = `${AUTH} && @request.body.band:changed = false && ${setManager("band")}`;
    app.save(setlists);

    // --- invitations into a band -------------------------------------------------------
    const invites = app.findCollectionByNameOrId("invites");
    invites.fields.add(
      new RelationField({
        name: "band",
        collectionId: bands.id,
        maxSelect: 1,
        cascadeDelete: false,
      }),
    );
    // Organization admins see all links of the organization, band leaders
    // those of their bands. Created and redeemed through the routes
    // (pb_hooks/invites.pb.js).
    const inviteManager =
      `(${orgAdmin("organization")} || (band != "" && ${bandRole("band", "admin")}))`;
    invites.listRule = `${AUTH} && organization != "" && ${inviteManager}`;
    invites.viewRule = invites.listRule;
    invites.updateRule =
      `${AUTH} && organization != "" && ${inviteManager}` +
      ` && @request.body.organization:isset = false && @request.body.band:isset = false` +
      ` && @request.body.token_hash:isset = false && @request.body.expires:isset = false` +
      ` && @request.body.created_by:isset = false && @request.body.founder_name:isset = false` +
      ` && @request.body.used_by:isset = false`;
    app.save(invites);

    // --- the band setting is gone ------------------------------------------------------
    bands.fields.removeByName("members_can_edit_songs");
    app.save(bands);
  },
  () => {
    throw new Error("1795300000_roles is not reversible; restore a backup.");
  },
);
