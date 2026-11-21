/// <reference path="../pb_data/types.d.ts" />

// Deleting an account (ADR-0052, issue #780): DELETE on the records API.
// Users delete only their own record (`deleteRule`) and confirm it with
// their password in the body; superusers in the admin UI go through the
// same hook without one. Refused while the person is the only admin of an
// organization that is not closed; otherwise the memberships are
// soft-deleted and the references cleared (lib/accounts.js) in the
// transaction of the delete, and the private data cascades.
onRecordDeleteRequest((e) => {
  const accounts = require(`${__hooks}/lib/accounts.js`);
  const superuser = !!(e.auth && e.auth.collection().name === "_superusers");
  if (!superuser) {
    const password = String(e.requestInfo().body["password"] || "");
    if (!password || !e.record.validatePassword(password)) {
      throw new BadRequestError("The password is wrong.", {
        password: new ValidationError("invalid_password", "The password is wrong."),
      });
    }
  }
  const organizations = accounts.soleAdminOf(e.app, e.record.id);
  if (organizations.length > 0) {
    const message = "The only admin of an organization cannot delete the account: " +
      organizations.join(", ");
    throw new BadRequestError(message, {
      organizations: new ValidationError("last_admin", organizations.join("\n")),
    });
  }
  e.app.runInTransaction((txApp) => {
    accounts.prepareDeletion(txApp, e.record.id);
    e.app = txApp;
    e.next();
  });
}, "users");
