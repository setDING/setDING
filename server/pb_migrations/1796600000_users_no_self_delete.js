/// <reference path="../pb_data/types.d.ts" />

// Users cannot delete their account through the API (issue #778). PocketBase's
// default `deleteRule` let them, and the delete hard-deleted their memberships
// through `cascadeDelete` (other devices never learn about it through sync)
// and could leave an organization without an admin. Account deletion gets its
// own flow (issue #780); until then only superusers delete accounts.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.deleteRule = null;
    app.save(users);
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.deleteRule = "id = @request.auth.id";
    app.save(users);
  },
);
