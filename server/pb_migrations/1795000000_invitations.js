/// <reference path="../pb_data/types.d.ts" />

// Invitations into organizations (ADR-0005, ADR-0017, issue #16).
//
// Links are created and redeemed through the routes in
// pb_hooks/invites.pb.js (only the hash of a token is stored). Admins may
// revoke a link through the records API; `org_memberships.invite` records
// which link a person joined with.
migrate(
  (app) => {
    const invites = app.findCollectionByNameOrId("invites");
    const orgMemberships = app.findCollectionByNameOrId("org_memberships");

    orgMemberships.fields.add(
      new RelationField({
        name: "invite",
        collectionId: invites.id,
        maxSelect: 1,
        cascadeDelete: false,
      }),
    );
    app.save(orgMemberships);

    const m = "@collection.org_memberships:inviteadmin";
    const orgAdmin =
      `(${m}.organization ?= organization && ${m}.user ?= @request.auth.id` +
      ` && ${m}.deleted ?= false && ${m}.role ?= "admin")`;
    invites.updateRule =
      `@request.auth.collectionName = "users" && ${orgAdmin}` +
      ` && @request.body.organization:isset = false && @request.body.token_hash:isset = false` +
      ` && @request.body.expires:isset = false && @request.body.created_by:isset = false`;
    app.save(invites);
  },
  (app) => {
    const invites = app.findCollectionByNameOrId("invites");
    invites.updateRule = null;
    app.save(invites);
    const orgMemberships = app.findCollectionByNameOrId("org_memberships");
    orgMemberships.fields.removeByName("invite");
    app.save(orgMemberships);
  },
);
