// People without an account (ADR-0064, issue #1097). PocketBase runs every
// hook handler in its own context, so handlers load this module with
// require().

/// Whether [userId] may edit sets in some band of [orgId], and so create and
/// edit its contacts and see their mail addresses: organization admins, and
/// band leaders and set planners of a band of the organization (ADR-0023).
function editsContacts(app, orgId, userId) {
  if (!userId || !orgId) return false;
  const memberships = app.findRecordsByFilter(
    "org_memberships",
    "organization = {:org} && user = {:user} && deleted = false",
    "",
    1,
    0,
    { org: orgId, user: userId },
  );
  if (memberships.length === 0) return false;
  if (memberships[0].getString("role") === "admin") return true;
  return (
    app.findRecordsByFilter(
      "memberships",
      "user = {:user} && deleted = false && (role = 'admin' || role = 'planner')" +
        " && band.organization = {:org} && band.deleted = false",
      "",
      1,
      0,
      { org: orgId, user: userId },
    ).length > 0
  );
}

function onCreate(e) {
  const userId = require(`${__hooks}/lib/sync.js`).requestUserId(e);
  if (!userId) return;
  e.record.set("created_by", userId);
  e.record.set("linked_user", "");
  e.record.set("deleted", false);
  e.record.set("deleted_at", "");
}

function onUpdate(e) {
  const original = e.record.original();
  e.record.set("created_by", original.getString("created_by"));
  if (require(`${__hooks}/lib/sync.js`).requestUserId(e)) {
    e.record.set("linked_user", original.getString("linked_user"));
  }
}

/// A contact that becomes deleted loses its mail address at once, gets its
/// `deleted_at`, and its open invitations are revoked; the name stays, so
/// old sets keep showing it (ADR-0064 decision 7).
function onDelete(e) {
  if (!e.record.getBool("deleted") || e.record.original().getBool("deleted")) return;
  e.record.set("email", "");
  if (e.record.getDateTime("deleted_at").isZero()) e.record.set("deleted_at", new DateTime());
  e.app
    .db()
    .newQuery("UPDATE invites SET revoked = TRUE WHERE contact = {:contact} AND used_by = ''")
    .bind({ contact: e.record.id })
    .execute();
}

function enrich(e) {
  const info = e.requestInfo;
  const auth = info && info.auth;
  if (auth && auth.collection().name === "_superusers") return;
  const userId = auth && auth.collection().name === "users" ? auth.id : "";
  if (!editsContacts(e.app, e.record.getString("organization"), userId)) {
    e.record.hide("email");
  }
}

/// The names of a contact, as the lineup routes return them.
function names(contact) {
  return {
    id: contact.id,
    first_name: contact.getString("first_name"),
    last_name: contact.getString("last_name"),
    nickname: contact.getString("nickname"),
  };
}

module.exports = { editsContacts, onCreate, onUpdate, onDelete, enrich, names };
