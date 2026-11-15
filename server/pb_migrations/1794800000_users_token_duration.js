/// <reference path="../pb_data/types.d.ts" />

// Auth tokens of users are valid for 30 days instead of PocketBase's default of
// 5 days (ADR-0016). The app refreshes the token whenever it starts online, so
// a member who is offline for a few weeks (rehearsals, gigs without network)
// does not have to sign in again.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.authToken.duration = 30 * 24 * 60 * 60;
    app.save(users);
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.authToken.duration = 5 * 24 * 60 * 60;
    app.save(users);
  },
);
