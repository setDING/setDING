// Shared helpers for the sync hooks (ADR-0004). PocketBase runs every hook
// handler in its own context, so handlers load this module with require().

/// Increments the server-wide revision counter and returns the new value.
/// Must run in the transaction that saves the record, so that revisions become
/// visible in increasing order (delta sync "all changes since revision X").
function nextRevision(app) {
  const row = new DynamicModel({ revision: 0 });
  app
    .db()
    .newQuery(
      "UPDATE setding_sync SET revision = revision + 1 WHERE id = 1 RETURNING revision",
    )
    .one(row);
  return row.revision;
}

/// ID of the signed-in user of a request, or "" for superusers and guests.
function requestUserId(e) {
  return e.auth && e.auth.collection().name === "users" ? e.auth.id : "";
}

/// Handles a create or update request of a synced record: records the author
/// and runs the save in a transaction (see nextRevision).
function handleWriteRequest(e) {
  e.record.set("updated_by", requestUserId(e));
  e.app.runInTransaction((txApp) => {
    e.app = txApp;
    e.next();
  });
}

module.exports = { nextRevision, requestUserId, handleWriteRequest };
