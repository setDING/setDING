/// <reference path="../pb_data/types.d.ts" />

// Registration mode set by the server operator (ADR-0024).
//
// Founder invitations are invitations without an organization: redeeming
// one creates the organization `founder_name` with the person as its admin.
// They are single-use (`used_by`). Rate limits protect sign-up, sign-in and
// the invitation routes; the operator can tune them in the admin UI.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const invites = app.findCollectionByNameOrId("invites");
    invites.fields.getByName("organization").required = false;
    invites.fields.add(new TextField({ name: "founder_name", max: 200 }));
    invites.fields.add(
      new RelationField({
        name: "used_by",
        collectionId: users.id,
        maxSelect: 1,
        cascadeDelete: false,
      }),
    );
    app.save(invites);

    const settings = app.settings();
    const ours = [
      { label: "users:create", audience: "", duration: 60, maxRequests: 5 },
      { label: "*:auth", audience: "", duration: 60, maxRequests: 20 },
      { label: "/api/realchord/invites/", audience: "", duration: 60, maxRequests: 30 },
      { label: "/invite/", audience: "", duration: 60, maxRequests: 30 },
    ];
    const labels = ours.map((r) => r.label);
    const rules = [];
    for (const rule of settings.rateLimits.rules || []) {
      if (labels.indexOf(rule.label) < 0) rules.push(rule);
    }
    settings.rateLimits.rules = ours.concat(rules);
    settings.rateLimits.enabled = true;
    app.save(settings);
  },
  (app) => {
    const invites = app.findCollectionByNameOrId("invites");
    invites.fields.removeByName("founder_name");
    invites.fields.removeByName("used_by");
    invites.fields.getByName("organization").required = true;
    app.save(invites);
  },
);
