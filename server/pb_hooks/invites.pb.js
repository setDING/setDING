/// <reference path="../pb_data/types.d.ts" />

// Invitation links (ADR-0005, ADR-0017); the logic is in lib/invites.js.

// Creates a link for an organization (organization admins). Returns the
// token once; only its hash is stored.
routerAdd("POST", "/api/setding/invites", (e) =>
  require(`${__hooks}/lib/invites.js`).create(e), $apis.requireAuth("users"));

// Organization name and state of a link, for "Join X?"; also without an
// account, before signing up with the link (ADR-0024).
routerAdd("GET", "/api/setding/invites/{token}", (e) =>
  require(`${__hooks}/lib/invites.js`).preview(e));

// Joins the organization with the member role, or founds the organization
// of a founder invitation (ADR-0024).
routerAdd("POST", "/api/setding/invites/{token}/redeem", (e) =>
  require(`${__hooks}/lib/invites.js`).redeem(e), $apis.requireAuth("users"));

// Landing page of the link for people without the app.
routerAdd("GET", "/invite/{token}", (e) =>
  require(`${__hooks}/lib/invites.js`).landing(e));

// Deep-link verification files (configured with environment variables).
routerAdd("GET", "/.well-known/assetlinks.json", (e) =>
  require(`${__hooks}/lib/invites.js`).assetLinks(e));
routerAdd("GET", "/.well-known/apple-app-site-association", (e) =>
  require(`${__hooks}/lib/invites.js`).appleAppSiteAssociation(e));
