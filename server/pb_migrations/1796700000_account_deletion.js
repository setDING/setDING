/// <reference path="../pb_data/types.d.ts" />

// Deleting the own account (ADR-0052, issue #780). Users may delete their own
// record again; `pb_hooks/users.pb.js` checks the password, refuses the last
// admin of an organization and soft-deletes the memberships before the
// record goes. The `user` of a membership no longer cascades: the hook keeps
// the soft-deleted membership as a tombstone without a person, so other
// devices learn about it through sync. A rate limit keeps the route from
// being used to guess passwords.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.deleteRule = "id = @request.auth.id";
    app.save(users);

    for (const name of ["memberships", "org_memberships"]) {
      const collection = app.findCollectionByNameOrId(name);
      const user = collection.fields.getByName("user");
      user.cascadeDelete = false;
      user.required = false;
      app.save(collection);
    }

    const settings = app.settings();
    const rules = (settings.rateLimits.rules || []).filter(
      (r) => r.label !== "users:delete",
    );
    rules.unshift({ label: "users:delete", audience: "", duration: 60, maxRequests: 5 });
    settings.rateLimits.rules = rules;
    app.save(settings);
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.deleteRule = null;
    app.save(users);
    for (const name of ["memberships", "org_memberships"]) {
      const collection = app.findCollectionByNameOrId(name);
      const user = collection.fields.getByName("user");
      user.cascadeDelete = true;
      user.required = true;
      app.save(collection);
    }
    const settings = app.settings();
    settings.rateLimits.rules = (settings.rateLimits.rules || []).filter(
      (r) => r.label !== "users:delete",
    );
    app.save(settings);
  },
);
