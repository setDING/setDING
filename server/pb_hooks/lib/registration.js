// Registration mode and email verification set by the server operator in
// the environment (/etc/setding/pocketbase.env, ADR-0024).

/// "invite_only" (default) or "open" (SETDING_REGISTRATION).
function mode() {
  const value = ($os.getenv("SETDING_REGISTRATION") || "").trim().toLowerCase();
  return value === "open" ? "open" : "invite_only";
}

function inviteOnly() {
  return mode() === "invite_only";
}

/// Whether SETDING_EMAIL_VERIFICATION asks for verification.
function verificationRequested() {
  const value = ($os.getenv("SETDING_EMAIL_VERIFICATION") || "").trim().toLowerCase();
  return value === "required";
}

/// "required" only if requested and the server can send mail (SMTP), so a
/// configuration mistake locks nobody out; otherwise "off".
function emailVerification(app) {
  return verificationRequested() && app.settings().smtp.enabled ? "required" : "off";
}

/// Whether a request comes from a superuser (operator, admin UI).
function isSuperuser(e) {
  return !!(e.auth && e.auth.collection().name === "_superusers");
}

/// Rejects creating an organization (directly or through a band without
/// one) on an invite-only server; there organizations come from founder
/// invitations only.
function requireOrganizationCreation(e) {
  if (!inviteOnly() || isSuperuser(e)) return;
  throw new ForbiddenError(
    "New organizations need a founder invitation on this server.",
    { organization: new ValidationError("founder_invitation_required", "A founder invitation is needed.") },
  );
}

/// Rejects a sign-up without a valid invitation (`invite` in the body) on an
/// invite-only server. The invitation is redeemed by the app after sign-in.
function requireSignupInvitation(e) {
  if (!inviteOnly() || isSuperuser(e)) return;
  const token = (e.requestInfo().body || {}).invite || "";
  const invites = require(`${__hooks}/lib/invites.js`);
  const invite = invites.findByToken(e.app, String(token));
  if (!invite || invites.status(invite) !== "valid") {
    throw new ForbiddenError(
      "An invitation is needed to create an account on this server.",
      { invite: new ValidationError("invitation_required", "A valid invitation is needed.") },
    );
  }
}

module.exports = {
  mode,
  inviteOnly,
  verificationRequested,
  emailVerification,
  isSuperuser,
  requireOrganizationCreation,
  requireSignupInvitation,
};
