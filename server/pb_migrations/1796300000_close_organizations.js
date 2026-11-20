/// <reference path="../pb_data/types.d.ts" />

// Closing organizations (ADR-0044, issue #629): any organization admin
// closes the organization with DELETE on the records API; the hook in
// `pb_hooks/organizations.pb.js` turns it into a soft delete with a cascade,
// kept 30 days in the trash (ADR-0043), then purged for good.
//
// - organizations: DELETE for active organization admins; an update of a
//   closed organization is only its restore (`deleted` back to false, by
//   its admins, not purged); `deleted_at` and `purged` are set by the
//   server only.
// - Reading a closed organization's content (bands, sets, arrangements,
//   band memberships, songs, attachments, invitations, the people) is left
//   to its admins; members keep the organization record and their own
//   membership, so their devices learn about the closing.
// - Nothing can be written into a closed organization.
const LOCK = " && @request.body.deleted:changed = false";

const ORG_UPDATE =
  " && @request.body.deleted_at:isset = false && @request.body.purged:isset = false" +
  " && ((deleted = false && @request.body.deleted:changed = false)" +
  " || (deleted = true && purged = false && @request.body.deleted = false))";

let alias = 0;
/// Active organization admin of the organization [org] (a field path).
function orgAdmin(org) {
  const m = `@collection.org_memberships:closed${++alias}`;
  return (
    `(${m}.organization ?= ${org} && ${m}.user ?= @request.auth.id` +
    ` && ${m}.deleted ?= false && ${m}.role ?= "admin")`
  );
}

/// Read access to content of the organization [org]: open, or its admin.
function readable(org) {
  return ` && (${org}.deleted = false || ${orgAdmin(org)})`;
}

const READ = {
  bands: "organization",
  setlists: "band.organization",
  arrangements: "band.organization",
  memberships: "band.organization",
  songs: "organization",
  attachments: "organization",
  invites: "organization",
};

const WRITE = {
  songs: " && organization.deleted = false",
  attachments: " && organization.deleted = false",
  bands: null, // create and update differ, see below
  org_memberships: " && organization.deleted = false",
  overlays: " && song.organization.deleted = false",
  annotations: " && song.organization.deleted = false",
  invites: " && organization.deleted = false",
};

const BAND_CREATE = ' && (organization = "" || organization.deleted = false)';
const BAND_UPDATE = " && organization.deleted = false";

/// Rule changes as [collection, rule name, suffix], applied by appending
/// and reverted by removing the suffix.
function changes() {
  alias = 0;
  const list = [];
  for (const [name, org] of Object.entries(READ)) {
    const suffix = readable(org);
    list.push([name, "listRule", suffix], [name, "viewRule", suffix]);
  }
  const people = ` && (user = @request.auth.id || organization.deleted = false || ${orgAdmin("organization")})`;
  list.push(["org_memberships", "listRule", people], ["org_memberships", "viewRule", people]);
  for (const [name, suffix] of Object.entries(WRITE)) {
    if (name === "bands") {
      list.push([name, "createRule", BAND_CREATE], [name, "updateRule", BAND_UPDATE]);
      continue;
    }
    if (name !== "org_memberships" && name !== "invites") {
      list.push([name, "createRule", suffix]);
    }
    list.push([name, "updateRule", suffix]);
  }
  return list;
}

migrate(
  (app) => {
    const orgs = app.findCollectionByNameOrId("organizations");
    orgs.fields.add(new DateField({ name: "deleted_at" }));
    orgs.fields.add(new BoolField({ name: "purged" }));
    orgs.updateRule = orgs.updateRule.replace(LOCK, ORG_UPDATE);
    orgs.deleteRule =
      `@request.auth.collectionName = "users" && deleted = false && ${orgAdmin("id")}`;
    app.save(orgs);

    for (const [name, rule, suffix] of changes()) {
      const collection = app.findCollectionByNameOrId(name);
      if (collection[rule] === null) continue;
      collection[rule] += suffix;
      app.save(collection);
    }
  },
  (app) => {
    for (const [name, rule, suffix] of changes()) {
      const collection = app.findCollectionByNameOrId(name);
      if (collection[rule] === null) continue;
      collection[rule] = collection[rule].replace(suffix, "");
      app.save(collection);
    }

    const orgs = app.findCollectionByNameOrId("organizations");
    orgs.fields.removeByName("deleted_at");
    orgs.fields.removeByName("purged");
    orgs.updateRule = orgs.updateRule.replace(ORG_UPDATE, LOCK);
    orgs.deleteRule = null;
    app.save(orgs);
  },
);
