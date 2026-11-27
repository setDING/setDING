// Invitation links (ADR-0005, ADR-0017). A link is
// `<app URL>/invite/<token>`; the server finds a token by its SHA-256 hash
// and keeps the token itself only encrypted with `SETDING_INVITE_KEY`, so
// the people who manage links can show an active one again. Links are valid for 7 days, can be used several times, can be
// revoked, and always grant the member role of the organization.
//
// Invitations of a band leader (ADR-0023) also carry the `band`: redeeming
// one adds the person to the band as well.
//
// Founder invitations (ADR-0024) have no organization but a `founder_name`:
// redeeming one creates that organization with the person as its admin.
// The server operator creates them (console command `founder-invite`); they
// can be used once (`used_by`).
//
// Personal invitations (ADR-0064) carry a `contact`, a person of the
// organization without an account: they can be used once, the sign-up is
// prefilled from the contact, and redeeming one links the contact to the
// account and puts the account in its place in every lineup.

const VALID_DAYS = 7;
const TOKEN_LENGTH = 32;

function isOrgAdmin(app, userId, orgId) {
  return app.countRecords(
    "org_memberships",
    $dbx.hashExp({ user: userId, organization: orgId, role: "admin", deleted: false }),
  ) > 0;
}

/// Whether the organization was closed (ADR-0044).
function isClosed(app, orgId) {
  try {
    return app.findRecordById("organizations", orgId).getBool("deleted");
  } catch (_) {
    return false;
  }
}

function isBandLeader(app, userId, bandId) {
  return app.countRecords(
    "memberships",
    $dbx.hashExp({ user: userId, band: bandId, role: "admin", deleted: false }),
  ) > 0;
}

function isBandMember(app, userId, bandId) {
  return app.countRecords(
    "memberships",
    $dbx.hashExp({ user: userId, band: bandId, deleted: false }),
  ) > 0;
}

/// Fallback when no application URL is set: the local default address.
const LOCAL_URL = "http://127.0.0.1:8090";

/// Public base URL of the server: the application URL from the settings
/// (https://api.setding.app in production), or the local default address.
/// Never the request's Host header, which the client controls.
function baseUrl(app) {
  const url = (app.settings().meta.appURL || "").trim();
  return (url || LOCAL_URL).replace(/\/+$/, "");
}

function findByToken(app, token) {
  if (!/^[A-Za-z0-9]{16,64}$/.test(token || "")) return null;
  try {
    return app.findFirstRecordByData("invites", "token_hash", $security.sha256(token));
  } catch (_) {
    return null;
  }
}

function isFounder(invite) {
  return !invite.getString("organization") && !!invite.getString("founder_name");
}

function isPersonal(invite) {
  return !!invite.getString("contact");
}

/// "valid", "expired", "revoked" or "used" (founder and personal
/// invitations).
function status(invite) {
  if (invite.getBool("revoked")) return "revoked";
  if ((isFounder(invite) || isPersonal(invite)) && invite.getString("used_by")) return "used";
  if (invite.getDateTime("expires").unix() < new DateTime().unix()) return "expired";
  return "valid";
}

function newToken() {
  return $security.randomString(TOKEN_LENGTH);
}

/// AES key for stored tokens, derived from `SETDING_INVITE_KEY`
/// (`/etc/setding/setding.env` on the owner's servers, or the container's
/// environment); the server does not start without it (ADR-0063).
function tokenKey() {
  const secret = $os.getenv("SETDING_INVITE_KEY") || "";
  return secret ? $security.sha256("setding-invite:" + secret).substring(0, 32) : "";
}

/// Sets the hash and, with a key, the encrypted token of a new invitation.
function setToken(invite, token) {
  invite.set("token_hash", $security.sha256(token));
  const key = tokenKey();
  if (key) invite.set("token_enc", $security.encrypt(token, key));
}

/// The token of an invitation, or "" when it cannot be shown (created
/// before tokens were stored, without a key, or with another key).
function storedToken(invite) {
  const key = tokenKey();
  const enc = invite.getString("token_enc");
  if (!key || !enc) return "";
  try {
    const token = $security.decrypt(enc, key);
    return $security.sha256(token) === invite.getString("token_hash") ? token : "";
  } catch (_) {
    return "";
  }
}

function expiry() {
  return new Date(Date.now() + VALID_DAYS * 24 * 60 * 60 * 1000)
    .toISOString()
    .replace("T", " ");
}

/// Organization of an invitation as shown before joining: the existing one,
/// or the one a founder invitation creates (no id yet).
function organizationOf(app, invite) {
  if (isFounder(invite)) return { id: "", name: invite.getString("founder_name") };
  const orgId = invite.getString("organization");
  return { id: orgId, name: app.findRecordById("organizations", orgId).getString("name") };
}

/// Creates a founder invitation for a new organization `name` (server
/// operator only, ADR-0024). Returns the token once.
function createFounder(app, name, base) {
  name = String(name || "").trim();
  if (!name) throw new Error("The organization needs a name.");
  const token = newToken();
  const invite = new Record(app.findCollectionByNameOrId("invites"));
  invite.set("founder_name", name);
  setToken(invite, token);
  invite.set("expires", expiry());
  app.save(invite);
  return {
    id: invite.id,
    token: token,
    url: base.replace(/\/+$/, "") + "/invite/" + token,
    expires: invite.getDateTime("expires").string(),
  };
}

/// Organization admins invite into the organization, optionally into one of
/// its bands; band leaders invite into their band (ADR-0023).
function create(e) {
  const userId = e.auth.id;
  const body = e.requestInfo().body || {};
  const orgId = body.organization || "";
  const bandId = body.band || "";
  const contactId = body.contact || "";
  if (orgId && isClosed(e.app, orgId)) {
    throw new BadRequestError("The organization is closed.", {
      organization: new ValidationError("closed", "The organization is closed."),
    });
  }
  let allowed = !!orgId && isOrgAdmin(e.app, userId, orgId);
  if (bandId) {
    let band = null;
    try {
      band = e.app.findRecordById("bands", bandId);
    } catch (_) {
      band = null;
    }
    if (!band || band.getBool("deleted") || band.getString("organization") !== orgId) {
      throw new BadRequestError("The band does not belong to the organization.", {
        band: new ValidationError("invalid_band", "The band does not belong to the organization."),
      });
    }
    allowed = allowed || isBandLeader(e.app, userId, bandId);
  }
  if (!allowed) {
    throw new ForbiddenError("Only organization admins and band leaders can invite people.");
  }
  if (contactId) {
    let contact = null;
    try {
      contact = e.app.findRecordById("contacts", contactId);
    } catch (_) {
      contact = null;
    }
    if (!contact || contact.getBool("deleted") || contact.getString("organization") !== orgId) {
      throw new BadRequestError("The contact does not belong to the organization.", {
        contact: new ValidationError(
          "invalid_contact",
          "The contact does not belong to the organization.",
        ),
      });
    }
  }
  const token = newToken();
  const expires = expiry();
  const invite = new Record(e.app.findCollectionByNameOrId("invites"));
  invite.set("organization", orgId);
  if (bandId) invite.set("band", bandId);
  if (contactId) invite.set("contact", contactId);
  setToken(invite, token);
  invite.set("expires", expires);
  invite.set("created_by", userId);
  e.app.save(invite);
  return e.json(200, {
    id: invite.id,
    token: token,
    url: baseUrl(e.app) + "/invite/" + token,
    expires: invite.getDateTime("expires").string(),
  });
}

/// Whether a band or organization membership stops being an active admin
/// in this update.
function lostAdmin(membership) {
  const before = membership.original();
  return before.getString("role") === "admin" && !before.getBool("deleted") &&
    (membership.getString("role") !== "admin" || membership.getBool("deleted"));
}

/// Revokes the open invitations [userId] created and may no longer create
/// (issue #1193): after losing the lead of [bandId], those for that band
/// unless they are still an admin of its organization; after losing the
/// admin role of [orgId], those of the organization except band invitations
/// of bands they still lead. Used founder and personal invitations stay.
function revokeLostRights(app, userId, scope) {
  let filter;
  let params;
  if (scope.band) {
    const band = app.findRecordById("bands", scope.band);
    if (isOrgAdmin(app, userId, band.getString("organization"))) return;
    filter = "created_by = {:user} && band = {:band} && revoked = false && used_by = ''";
    params = { user: userId, band: scope.band };
  } else {
    filter = "created_by = {:user} && organization = {:org} && revoked = false && used_by = ''";
    params = { user: userId, org: scope.organization };
  }
  for (const invite of app.findRecordsByFilter("invites", filter, "", 0, 0, params)) {
    const bandId = invite.getString("band");
    if (!scope.band && bandId && isBandLeader(app, userId, bandId)) continue;
    invite.set("revoked", true);
    app.save(invite);
  }
}

/// Shows an active link again to the people who may list it (organization
/// admins, band leaders for their band): its URL and expiry. 404 for links
/// they cannot see, 410 for inactive ones, 409 when the token is not stored.
function link(e) {
  let invite = null;
  try {
    invite = e.app.findRecordById("invites", e.request.pathValue("id"));
  } catch (_) {
    invite = null;
  }
  const rule = e.app.findCollectionByNameOrId("invites").viewRule;
  if (!invite || !e.app.canAccessRecord(invite, e.requestInfo(), rule)) {
    throw new NotFoundError("Unknown invitation.");
  }
  const state = status(invite);
  if (state !== "valid") {
    throw new ApiError(410, "The invitation is " + state + ".", {
      token: new ValidationError(state, "The invitation is " + state + "."),
    });
  }
  const token = storedToken(invite);
  if (!token) {
    throw new ApiError(409, "The link of this invitation is not stored.", {
      token: new ValidationError("not_stored", "The link of this invitation is not stored."),
    });
  }
  return e.json(200, {
    id: invite.id,
    url: baseUrl(e.app) + "/invite/" + token,
    expires: invite.getDateTime("expires").string(),
  });
}

/// Also answers without an account, so the app can show "Join X?" before
/// signing up (ADR-0024).
function preview(e) {
  const invite = findByToken(e.app, e.request.pathValue("token"));
  if (!invite) throw new NotFoundError("Unknown invitation.");
  const org = organizationOf(e.app, invite);
  const userId = require(`${__hooks}/lib/sync.js`).requestUserId(e);
  const bandId = invite.getString("band");
  const member = !!org.id && !!userId && e.app.countRecords(
    "org_memberships",
    $dbx.hashExp({ user: userId, organization: org.id, deleted: false }),
  ) > 0 && (!bandId || isBandMember(e.app, userId, bandId));
  return e.json(200, {
    organization: org,
    band: bandOf(e.app, invite),
    status: status(invite),
    member: member,
    founder: isFounder(invite),
    // For prefilling the sign-up; only to whoever holds the valid link.
    contact: status(invite) === "valid" ? contactOf(e.app, invite) : null,
  });
}

/// Names and mail address of the contact of a personal invitation, or null.
function contactOf(app, invite) {
  const contactId = invite.getString("contact");
  if (!contactId) return null;
  try {
    const contact = app.findRecordById("contacts", contactId);
    if (contact.getBool("deleted")) return null;
    return Object.assign(require(`${__hooks}/lib/contacts.js`).names(contact), {
      email: contact.getString("email"),
    });
  } catch (_) {
    return null;
  }
}

/// Links the contact of a personal invitation to [userId] (ADR-0064
/// decision 5): every set of the organization with the contact in its
/// lineup gets the user in its place (a new revision each), the contact
/// is linked and deleted, the invitation used. Runs in the redeeming
/// transaction.
function linkContact(txApp, invite, userId) {
  const fresh = txApp.findRecordById("invites", invite.id);
  if (fresh.getString("used_by") || fresh.getBool("revoked")) {
    throw new ApiError(410, "The invitation is used.", {
      token: new ValidationError("used", "The invitation is used."),
    });
  }
  const contact = txApp.findRecordById("contacts", fresh.getString("contact"));
  if (contact.getBool("deleted")) {
    throw new ApiError(410, "The invitation is revoked.", {
      token: new ValidationError("revoked", "The invitation is revoked."),
    });
  }
  const sets = txApp.findRecordsByFilter(
    "setlists",
    "band.organization = {:org} && lineup_contacts ~ {:contact}",
    "",
    0,
    0,
    { org: fresh.getString("organization"), contact: contact.id },
  );
  for (const set of sets) {
    const contacts = set.getStringSlice("lineup_contacts");
    if (contacts.indexOf(contact.id) < 0) continue;
    set.set("lineup_contacts", contacts.filter((id) => id !== contact.id));
    const lineup = set.getStringSlice("lineup");
    if (lineup.indexOf(userId) < 0) set.set("lineup", lineup.concat([userId]));
    set.set("updated_by", userId);
    txApp.save(set);
  }
  contact.set("linked_user", userId);
  contact.set("deleted", true);
  contact.set("updated_by", userId);
  txApp.save(contact);
  fresh.set("used_by", userId);
  txApp.save(fresh);
}

/// The band an invitation also leads into, or null.
function bandOf(app, invite) {
  const bandId = invite.getString("band");
  if (!bandId) return null;
  try {
    const band = app.findRecordById("bands", bandId);
    return band.getBool("deleted") ? null : { id: band.id, name: band.getString("name") };
  } catch (_) {
    return null;
  }
}

/// Adds the user to the band as a member (or back, after leaving); keeps an
/// existing membership and its role.
function joinBand(txApp, userId, bandId) {
  let membership = null;
  try {
    membership = txApp.findFirstRecordByFilter(
      "memberships",
      "user = {:user} && band = {:band}",
      { user: userId, band: bandId },
    );
  } catch (_) {
    membership = null;
  }
  if (membership && !membership.getBool("deleted")) return false;
  if (!membership) {
    membership = new Record(txApp.findCollectionByNameOrId("memberships"));
    membership.set("user", userId);
    membership.set("band", bandId);
  }
  membership.set("role", "member");
  membership.set("deleted", false);
  membership.set("updated_by", userId);
  txApp.save(membership);
  return true;
}

/// Creates the organization of a founder invitation with the user as its
/// admin (pb_hooks/organizations.pb.js) and marks the invitation used.
function redeemFounder(e, invite, userId) {
  let orgId = "";
  e.app.runInTransaction((txApp) => {
    const fresh = txApp.findRecordById("invites", invite.id);
    if (fresh.getString("used_by")) {
      throw new ApiError(410, "The invitation is used.", {
        token: new ValidationError("used", "The invitation is used."),
      });
    }
    const org = new Record(txApp.findCollectionByNameOrId("organizations"));
    org.set("name", fresh.getString("founder_name"));
    org.set("updated_by", userId);
    txApp.save(org);
    orgId = org.id;
    fresh.set("used_by", userId);
    txApp.save(fresh);
  });
  const org = e.app.findRecordById("organizations", orgId);
  return e.json(200, {
    organization: { id: orgId, name: org.getString("name") },
    alreadyMember: false,
    founder: true,
  });
}

function redeem(e) {
  const invite = findByToken(e.app, e.request.pathValue("token"));
  if (!invite) throw new NotFoundError("Unknown invitation.");
  const state = status(invite);
  if (state !== "valid") {
    throw new ApiError(410, "The invitation is " + state + ".", {
      token: new ValidationError(state, "The invitation is " + state + "."),
    });
  }
  const userId = e.auth.id;
  if (isFounder(invite)) return redeemFounder(e, invite, userId);
  const orgId = invite.getString("organization");
  let alreadyMember = false;
  e.app.runInTransaction((txApp) => {
    let membership = null;
    try {
      membership = txApp.findFirstRecordByFilter(
        "org_memberships",
        "user = {:user} && organization = {:org}",
        { user: userId, org: orgId },
      );
    } catch (_) {
      membership = null;
    }
    if (membership && !membership.getBool("deleted")) {
      alreadyMember = true;
    } else {
      if (!membership) {
        membership = new Record(txApp.findCollectionByNameOrId("org_memberships"));
        membership.set("user", userId);
        membership.set("organization", orgId);
      }
      membership.set("role", "member");
      membership.set("deleted", false);
      membership.set("invite", invite.id);
      membership.set("updated_by", userId);
      txApp.save(membership);
    }
    const band = bandOf(txApp, invite);
    if (band && joinBand(txApp, userId, band.id)) alreadyMember = false;
    if (isPersonal(invite)) linkContact(txApp, invite, userId);
  });
  const org = e.app.findRecordById("organizations", orgId);
  return e.json(200, {
    organization: { id: orgId, name: org.getString("name") },
    band: bandOf(e.app, invite),
    alreadyMember: alreadyMember,
  });
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const TEXTS = {
  de: {
    title: "Einladung zu setDING",
    invited: (org) => `Du bist eingeladen, ${org} auf setDING beizutreten.`,
    found: (org) => `Du bist eingeladen, die Organisation ${org} auf setDING zu gründen.`,
    open: "In setDING öffnen",
    browser: "Im Browser öffnen",
    browserHint: "Oder ohne Installation im Browser verwalten:",
    install:
      "Noch keine App? Installiere setDING, öffne dann diesen Link nochmals " +
      "oder füge ihn in der App unter «Bands → Beitreten» ein.",
    invalid: "Diese Einladung ist ungültig, abgelaufen oder widerrufen. Bitte um einen neuen Link.",
  },
  en: {
    title: "Invitation to setDING",
    invited: (org) => `You are invited to join ${org} on setDING.`,
    found: (org) => `You are invited to found the organization ${org} on setDING.`,
    open: "Open in setDING",
    browser: "Open in the browser",
    browserHint: "Or manage without installing, in the browser:",
    install:
      "No app yet? Install setDING, then open this link again " +
      "or paste it in the app under “Bands → Join”.",
    invalid: "This invitation is invalid, expired or revoked. Please ask for a new link.",
  },
};

/// Landing page for people who open a link without the app (ADR-0005).
/// On the web client's hostname the link opens the web client instead,
/// which takes the token from the URL (ADR-0018).
function landing(e) {
  const web = require(`${__hooks}/lib/web.js`);
  if (web.isWebHost(e)) {
    const html = web.index();
    if (html !== null) return e.html(200, html);
  }
  const lang = (e.request.header.get("Accept-Language") || "").toLowerCase();
  const t = lang.indexOf("de") === 0 ? TEXTS.de : TEXTS.en;
  const token = e.request.pathValue("token");
  const invite = findByToken(e.app, token);
  let body;
  if (!invite || status(invite) !== "valid") {
    body = `<p>${escapeHtml(t.invalid)}</p>`;
  } else {
    const org = organizationOf(e.app, invite);
    body =
      `<p>${escapeHtml(isFounder(invite) ? t.found(org.name) : t.invited(org.name))}</p>` +
      `<p><a class="button" href="setding://invite/${escapeHtml(token)}">${escapeHtml(t.open)}</a></p>` +
      `<p class="hint">${escapeHtml(t.install)}</p>` +
      (web.available()
        ? `<p class="hint">${escapeHtml(t.browserHint)}</p>` +
          `<p><a class="button secondary" href="${escapeHtml(web.webUrl())}/invite/${escapeHtml(token)}">` +
          `${escapeHtml(t.browser)}</a></p>`
        : "");
  }
  return e.html(
    200,
    `<!doctype html><html><head><meta charset="utf-8">` +
      `<meta name="viewport" content="width=device-width, initial-scale=1">` +
      `<meta name="robots" content="noindex">` +
      `<title>${escapeHtml(t.title)}</title><style>` +
      `body{font-family:system-ui,sans-serif;max-width:32rem;margin:3rem auto;padding:0 1rem;line-height:1.5}` +
      `.button{display:inline-block;padding:.75rem 1.25rem;background:#3f51b5;color:#fff;border-radius:.5rem;text-decoration:none}` +
      `.secondary{background:#fff;color:#3f51b5;border:1px solid #3f51b5}` +
      `.hint{color:#555}</style></head><body><h1>${escapeHtml(t.title)}</h1>${body}</body></html>`,
  );
}

const PACKAGE = "app.setding";

/// Android App Links verification; needs SETDING_ANDROID_CERT_SHA256 (one
/// or more comma-separated SHA-256 fingerprints of the signing certificate).
function assetLinks(e) {
  const prints = ($os.getenv("SETDING_ANDROID_CERT_SHA256") || "")
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s);
  if (prints.length === 0) throw new NotFoundError();
  return e.json(200, [{
    relation: ["delegate_permission/common.handle_all_urls"],
    target: { namespace: "android_app", package_name: PACKAGE, sha256_cert_fingerprints: prints },
  }]);
}

/// iOS Universal Links verification; needs SETDING_APPLE_TEAM_ID.
function appleAppSiteAssociation(e) {
  const team = ($os.getenv("SETDING_APPLE_TEAM_ID") || "").trim();
  if (!team) throw new NotFoundError();
  return e.json(200, {
    applinks: {
      details: [{
        appIDs: [team + "." + PACKAGE],
        // Invitations (ADR-0005) and links to sets and songs (ADR-0065).
        components: [{ "/": "/invite/*" }, { "/": "/sets/*" }, { "/": "/songs/*" }],
      }],
    },
  });
}

module.exports = {
  baseUrl,
  findByToken,
  status,
  isFounder,
  lostAdmin,
  revokeLostRights,
  create,
  createFounder,
  link,
  preview,
  redeem,
  landing,
  assetLinks,
  appleAppSiteAssociation,
};
