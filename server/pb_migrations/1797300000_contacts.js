/// <reference path="../pb_data/types.d.ts" />

// People without an account in a set's lineup (ADR-0064, issue #1097).
//
// contacts: people of an organization without a setDING account. Every
// member of the organization reads them; band leaders and set planners of
// any band of the organization and organization admins create and edit
// them, and only they see the mail address (pb_hooks/contacts.pb.js hides
// it from everybody else). Only organization admins delete them, softly:
// the hook clears the mail address and revokes the contact's invitations.
// `created_by` and `linked_user` are set by the server; a contact is linked
// to an account when its personal invitation is redeemed
// (pb_hooks/lib/invites.js), which also takes it out of the lineups.
//
// setlists.lineup_contacts: the contacts in a set's lineup, next to
// `lineup` (people with an account), checked by pb_hooks/lib/lineup.js.
//
// invites.contact: a personal invitation for a contact, used once.
/// [rule] with the first [from] replaced by [to]; throws if [rule] does not
/// contain [from], so a migration never silently leaves a rule unchanged
/// (issue #1201).
function replaceInRule(rule, from, to) {
  const i = rule === null ? -1 : rule.indexOf(from);
  if (i < 0) throw new Error(`Rule does not contain: ${from}`);
  return rule.slice(0, i) + to + rule.slice(i + from.length);
}

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    const orgs = app.findCollectionByNameOrId("organizations");

    // --- rule building blocks (see 1795300000_roles.js) ---------------------
    let alias = 0;
    const AUTH = `@request.auth.collectionName = "users"`;
    const orgRole = (roles) => {
      const m = `@collection.org_memberships:ct${++alias}`;
      const role = roles.map((r) => `${m}.role ?= "${r}"`).join(" || ");
      return (
        `(${m}.organization ?= organization && ${m}.user ?= @request.auth.id` +
        ` && ${m}.deleted ?= false && (${role}))`
      );
    };
    const bandRoleInOrg = (roles) => {
      const m = `@collection.memberships:ct${++alias}`;
      const role = roles.map((r) => `${m}.role ?= "${r}"`).join(" || ");
      return (
        `(${m}.user ?= @request.auth.id && ${m}.deleted ?= false && (${role})` +
        ` && ${m}.band.organization ?= organization && ${m}.band.deleted ?= false)`
      );
    };
    const orgMember = () => orgRole(["admin", "librarian", "member"]);
    const orgAdmin = () => orgRole(["admin"]);
    // Whoever may edit sets in some band of the organization (ADR-0023).
    const editor = () => `(${orgAdmin()} || (${orgMember()} && ${bandRoleInOrg(["admin", "planner"])}))`;

    const contacts = new Collection({
      type: "base",
      name: "contacts",
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
        { name: "organization", type: "relation", collectionId: orgs.id, required: true, maxSelect: 1, cascadeDelete: true },
        { name: "first_name", type: "text", required: true, max: 100 },
        { name: "last_name", type: "text", max: 100 },
        { name: "nickname", type: "text", max: 100 },
        { name: "email", type: "email" },
        // The account the contact became (ADR-0064 decision 5).
        { name: "linked_user", type: "relation", collectionId: users.id, maxSelect: 1, cascadeDelete: false },
        { name: "created_by", type: "relation", collectionId: users.id, maxSelect: 1, cascadeDelete: false },
        { name: "revision", type: "number", onlyInt: true, min: 0 },
        { name: "updated_by", type: "relation", collectionId: users.id, maxSelect: 1, cascadeDelete: false },
        { name: "deleted", type: "bool" },
        { name: "deleted_at", type: "date" },
        { name: "created", type: "autodate", onCreate: true, onUpdate: false },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      indexes: ["CREATE INDEX idx_contacts_org_revision ON contacts (organization, revision)"],
    });
    const serverFields =
      `@request.body.linked_user:isset = false && @request.body.created_by:isset = false` +
      ` && @request.body.deleted_at:isset = false`;
    contacts.listRule = `${AUTH} && ${orgMember()} && (organization.deleted = false || ${orgAdmin()})`;
    contacts.viewRule = contacts.listRule;
    contacts.createRule =
      `${AUTH} && organization.deleted = false && ${editor()} && ${serverFields}` +
      ` && @request.body.deleted:isset = false`;
    contacts.updateRule =
      `${AUTH} && organization.deleted = false && deleted = false && ${editor()} && ${serverFields}` +
      ` && @request.body.organization:changed = false` +
      ` && (@request.body.deleted:changed = false || (@request.body.deleted = true && ${orgAdmin()}))`;
    contacts.deleteRule = null;
    app.save(contacts);

    const setlists = app.findCollectionByNameOrId("setlists");
    setlists.fields.add(
      new RelationField({
        name: "lineup_contacts",
        collectionId: contacts.id,
        maxSelect: 200,
        cascadeDelete: false,
      }),
    );
    app.save(setlists);

    const invites = app.findCollectionByNameOrId("invites");
    invites.fields.add(
      new RelationField({ name: "contact", collectionId: contacts.id, maxSelect: 1, cascadeDelete: false }),
    );
    invites.updateRule += " && @request.body.contact:isset = false";
    app.save(invites);
  },
  (app) => {
    const invites = app.findCollectionByNameOrId("invites");
    invites.fields.removeByName("contact");
    invites.updateRule = replaceInRule(invites.updateRule, " && @request.body.contact:isset = false", "");
    app.save(invites);
    const setlists = app.findCollectionByNameOrId("setlists");
    setlists.fields.removeByName("lineup_contacts");
    app.save(setlists);
    app.delete(app.findCollectionByNameOrId("contacts"));
  },
);
