// Shared helpers for membership hooks (ADR-0005, ADR-0017).

/// Refuses to demote or remove the last active admin of a band or an
/// organization. `scopeField` is "band" or "organization".
function keepLastAdmin(e, collection, scopeField) {
  // A person removed from the organization leaves its bands even as their
  // last admin; organization admins still manage those bands (ADR-0017).
  if (scopeField === "band" && !isOrgMember(e.app, e.record)) return;
  // A deleted band takes all its memberships with it (ADR-0044).
  if (scopeField === "band" && e.app.findRecordById("bands", e.record.getString("band")).getBool("deleted")) {
    return;
  }
  // A closed organization keeps no admin when its last one deletes their
  // account (ADR-0052); it takes no other writes (ADR-0044).
  if (scopeField === "organization" &&
    e.app.findRecordById("organizations", e.record.getString("organization")).getBool("deleted")) {
    return;
  }
  const before = e.record.original();
  const wasAdmin = before.getString("role") === "admin" && !before.getBool("deleted");
  const isAdmin = e.record.getString("role") === "admin" && !e.record.getBool("deleted");
  if (!wasAdmin || isAdmin) return;
  const others = e.app.countRecords(
    collection,
    $dbx.hashExp({
      [scopeField]: e.record.getString(scopeField),
      role: "admin",
      deleted: false,
    }),
    $dbx.not($dbx.hashExp({ id: e.record.id })),
  );
  if (others === 0) {
    const message = scopeField === "band"
      ? "A band must keep at least one admin."
      : "An organization must keep at least one admin.";
    throw new BadRequestError(message, {
      role: new ValidationError("last_admin", message),
    });
  }
}

/// Whether the user of a band membership is an active member of the band's
/// organization.
function isOrgMember(app, membership) {
  const band = app.findRecordById("bands", membership.getString("band"));
  return app.countRecords(
    "org_memberships",
    $dbx.hashExp({
      user: membership.getString("user"),
      organization: band.getString("organization"),
      deleted: false,
    }),
  ) > 0;
}

/// Only members of the band's organization can be band members (ADR-0017).
function requireOrgMember(e) {
  if (e.record.getBool("deleted")) return;
  if (!isOrgMember(e.app, e.record)) {
    throw new BadRequestError("Only members of the organization can join its bands.", {
      user: new ValidationError("not_org_member", "Not a member of the organization."),
    });
  }
}

/// Creates an admin membership for `userId` in `collection`
/// ("memberships" with field "band", or "org_memberships" with "organization").
function addAdmin(app, collection, scopeField, scopeId, userId) {
  const membership = new Record(app.findCollectionByNameOrId(collection));
  membership.set("user", userId);
  membership.set(scopeField, scopeId);
  membership.set("role", "admin");
  membership.set("updated_by", userId);
  app.save(membership);
}

module.exports = { keepLastAdmin, addAdmin, requireOrgMember, isOrgMember };
