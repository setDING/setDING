/// <reference path="../pb_data/types.d.ts" />

// Registration mode and email verification set by the server operator
// (ADR-0024); the logic is in lib/registration.js.

// Explains the effective settings in the log; a requested verification
// without SMTP stays off so nobody is locked out.
onBootstrap((e) => {
  e.next();
  const reg = require(`${__hooks}/lib/registration.js`);
  if (reg.verificationRequested() && reg.emailVerification(e.app) === "off") {
    console.error(
      "SETDING_EMAIL_VERIFICATION=required needs SMTP (Settings → Mail settings); " +
        "email verification stays off.",
    );
  }
});

// Settings the app needs before signing in or up.
routerAdd("GET", "/api/setding/config", (e) => {
  const reg = require(`${__hooks}/lib/registration.js`);
  return e.json(200, {
    registration: reg.mode(),
    emailVerification: reg.emailVerification(e.app),
    // Lowest app version this server accepts (ADR-0029).
    minClientVersion: require(`${__hooks}/lib/compat.js`).minClientVersion(),
    // Version deployed with make server-release (git workflow section 10).
    serverVersion: require(`${__hooks}/lib/compat.js`).serverVersion(),
    // Newest app release, for the update hint (ADR-0036).
    latestClientVersion: require(`${__hooks}/lib/compat.js`).latestClientVersion(),
  });
});

// Sign-up only with a valid invitation on an invite-only server, and only
// with first and last name (ADR-0062).
onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/registration.js`).requireSignupInvitation(e);
  require(`${__hooks}/lib/names.js`).check(e, true);
  e.next();
}, "users");

// Sends the verification mail right after sign-up when it is required.
onRecordAfterCreateSuccess((e) => {
  e.next();
  const reg = require(`${__hooks}/lib/registration.js`);
  if (reg.emailVerification(e.app) !== "required" || e.record.verified()) return;
  try {
    $mails.sendRecordVerification(e.app, e.record);
  } catch (err) {
    e.app.logger().error("Sending the verification mail failed", "error", String(err));
  }
}, "users");

// No sign-in or session refresh with an unconfirmed address when
// verification is required; the mail is sent again.
onRecordAuthRequest((e) => {
  const reg = require(`${__hooks}/lib/registration.js`);
  if (reg.emailVerification(e.app) === "required" && !e.record.verified()) {
    try {
      $mails.sendRecordVerification(e.app, e.record);
    } catch (err) {
      e.app.logger().error("Sending the verification mail failed", "error", String(err));
    }
    throw new ForbiddenError("Please confirm your email address first.", {
      email: new ValidationError("email_not_verified", "The email address is not confirmed."),
    });
  }
  e.next();
}, "users");

// Organizations are created directly only on open servers.
onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/registration.js`).requireOrganizationCreation(e);
  e.next();
}, "organizations");

// Founder invitation for a new organization (server operator, ADR-0024):
//   pocketbase founder-invite "Music school" --dir=… --hooksDir=… --migrationsDir=…
$app.rootCmd.addCommand(new Command({
  use: "founder-invite [organization name]",
  short: "Creates a one-time invitation that founds an organization (setDING)",
  run: (cmd, args) => {
    const name = (args || []).join(" ").trim();
    if (!name) throw new Error("Usage: founder-invite <organization name>");
    const invites = require(`${__hooks}/lib/invites.js`);
    const r = invites.createFounder($app, name, invites.baseUrl($app));
    console.log(JSON.stringify(r));
  },
}));
