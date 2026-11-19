/// <reference path="../pb_data/types.d.ts" />

// Showing an active invitation link again (ADR-0005, issue #579): besides
// its hash, the server stores the token encrypted with the key
// `SETDING_INVITE_KEY` from `pocketbase.env` (pb_hooks/lib/invites.js).
// Hidden like the hash, and never set through the records API.
migrate(
  (app) => {
    const invites = app.findCollectionByNameOrId("invites");
    invites.fields.add(new TextField({ name: "token_enc", hidden: true }));
    invites.updateRule += " && @request.body.token_enc:isset = false";
    app.save(invites);
  },
  (app) => {
    const invites = app.findCollectionByNameOrId("invites");
    invites.fields.removeByName("token_enc");
    invites.updateRule = invites.updateRule.replace(
      " && @request.body.token_enc:isset = false",
      "",
    );
    app.save(invites);
  },
);
