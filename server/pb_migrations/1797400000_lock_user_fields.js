/// <reference path="../pb_data/types.d.ts" />

// PocketBase's default fields of `users` that setDING does not use are
// removed or locked (issue #1197, deny by default):
//
// - `avatar` is removed: no client uses it, and it was a public file field
//   (`protected: false`, SVG allowed) every user could fill.
// - `emailVisibility` is a system field of auth collections and cannot be
//   removed. With it set, members of the same organization would get the
//   address through the users listRule; the addresses of the lineup come
//   from the server route of ADR-0061 instead. Users can no longer set it
//   (create and update rules) and it is cleared on every account.
// - `name` stays: it is the display name for older app versions and is
//   maintained by the server only (lib/names.js, ADR-0062).
const LOCKED = `(@request.body.emailVisibility:isset = false || @request.body.emailVisibility = false)`;

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.fields.removeByName("avatar");
    users.createRule = LOCKED;
    users.updateRule = `id = @request.auth.id && ${LOCKED}`;
    app.save(users);
    app.db().newQuery("UPDATE users SET emailVisibility = FALSE").execute();
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    // PocketBase's default field, with its original id.
    users.fields.add(
      new FileField({
        id: "file376926767",
        name: "avatar",
        maxSelect: 1,
        maxSize: 0,
        mimeTypes: ["image/jpeg", "image/png", "image/svg+xml", "image/gif", "image/webp"],
        protected: false,
      }),
    );
    users.createRule = "";
    users.updateRule = "id = @request.auth.id";
    app.save(users);
  },
);
