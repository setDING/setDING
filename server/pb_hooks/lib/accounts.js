// Deleting an account (ADR-0052, issue #780). Loaded with require() by
// `users.pb.js`.

/// Names of the organizations, not closed, in which `userId` is the only
/// active admin. Deleting the account is refused while there are any.
function soleAdminOf(app, userId) {
  const names = [];
  const mine = app.findRecordsByFilter(
    "org_memberships",
    "user = {:user} && role = 'admin' && deleted = false && organization.deleted = false",
    "",
    0,
    0,
    { user: userId },
  );
  for (const m of mine) {
    const orgId = m.getString("organization");
    const others = app.countRecords(
      "org_memberships",
      $dbx.hashExp({ organization: orgId, role: "admin", deleted: false }),
      $dbx.not($dbx.hashExp({ id: m.id })),
    );
    if (others === 0) names.push(app.findRecordById("organizations", orgId).getString("name"));
  }
  return names;
}

/// Everything that happens before the user record is deleted, in the
/// transaction of the delete (`app` is the transaction's app):
/// - organization memberships are soft-deleted, which takes the band
///   memberships of the organization with them (`org_memberships.pb.js`);
///   band memberships left over are soft-deleted as well;
/// - open invitations the user created are revoked;
/// - every reference to the user that does not cascade is cleared with a
///   direct update, without a new revision: memberships become tombstones
///   without a person, and `updated_by`, `created_by` and `used_by` do not
///   make every device download every record the person ever edited.
/// Private data (personal adjustments, annotations, personal settings)
/// cascades when PocketBase deletes the record.
function prepareDeletion(app, userId) {
  for (const m of app.findRecordsByFilter(
    "org_memberships", "user = {:user} && deleted = false", "", 0, 0, { user: userId },
  )) {
    m.set("deleted", true);
    app.saveNoValidate(m);
  }
  for (const m of app.findRecordsByFilter(
    "memberships", "user = {:user} && deleted = false", "", 0, 0, { user: userId },
  )) {
    m.set("deleted", true);
    app.saveNoValidate(m);
  }
  app
    .db()
    .newQuery("UPDATE invites SET revoked = TRUE WHERE created_by = {:user} AND used_by = ''")
    .bind({ user: userId })
    .execute();

  const users = app.findCollectionByNameOrId("users");
  for (const collection of app.findAllCollections()) {
    if (collection.type === "view" || collection.id === users.id) continue;
    for (const field of collection.fields) {
      if (field.type() !== "relation" || field.collectionId !== users.id) continue;
      if (field.cascadeDelete) continue;
      if (field.maxSelect > 1) {
        throw new Error(`${collection.name}.${field.name}: multiple users are not supported`);
      }
      app
        .db()
        .newQuery(
          `UPDATE {{${collection.name}}} SET [[${field.name}]] = '' WHERE [[${field.name}]] = {:user}`,
        )
        .bind({ user: userId })
        .execute();
    }
  }
}

module.exports = { soleAdminOf, prepareDeletion };
