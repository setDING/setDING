// Invitation links (ADR-0005, ADR-0017). A link is
// `<app URL>/invite/<token>`; the server stores only the SHA-256 hash of the
// token. Links are valid for 7 days, can be used several times, can be
// revoked, and always grant the member role of the organization.

const VALID_DAYS = 7;
const TOKEN_LENGTH = 32;

function isOrgAdmin(app, userId, orgId) {
  return app.countRecords(
    "org_memberships",
    $dbx.hashExp({ user: userId, organization: orgId, role: "admin", deleted: false }),
  ) > 0;
}

/// Public base URL of the server: the application URL from the settings
/// (https://api.realchord.app in production), or the request's host.
function baseUrl(e) {
  const url = $app.settings().meta.appURL || "";
  if (url && url.indexOf("localhost") < 0) return url.replace(/\/+$/, "");
  return "http://" + e.request.host;
}

function findByToken(app, token) {
  if (!/^[A-Za-z0-9]{16,64}$/.test(token || "")) return null;
  try {
    return app.findFirstRecordByData("invites", "token_hash", $security.sha256(token));
  } catch (_) {
    return null;
  }
}

/// "valid", "expired" or "revoked".
function status(invite) {
  if (invite.getBool("revoked")) return "revoked";
  if (invite.getDateTime("expires").unix() < new DateTime().unix()) return "expired";
  return "valid";
}

function create(e) {
  const userId = e.auth.id;
  const orgId = (e.requestInfo().body || {}).organization || "";
  if (!orgId || !isOrgAdmin(e.app, userId, orgId)) {
    throw new ForbiddenError("Only organization admins can invite people.");
  }
  const token = $security.randomString(TOKEN_LENGTH);
  const expires = new Date(Date.now() + VALID_DAYS * 24 * 60 * 60 * 1000)
    .toISOString()
    .replace("T", " ");
  const invite = new Record(e.app.findCollectionByNameOrId("invites"));
  invite.set("organization", orgId);
  invite.set("token_hash", $security.sha256(token));
  invite.set("expires", expires);
  invite.set("created_by", userId);
  e.app.save(invite);
  return e.json(200, {
    id: invite.id,
    token: token,
    url: baseUrl(e) + "/invite/" + token,
    expires: invite.getDateTime("expires").string(),
  });
}

function preview(e) {
  const invite = findByToken(e.app, e.request.pathValue("token"));
  if (!invite) throw new NotFoundError("Unknown invitation.");
  const orgId = invite.getString("organization");
  const org = e.app.findRecordById("organizations", orgId);
  const member = e.app.countRecords(
    "org_memberships",
    $dbx.hashExp({ user: e.auth.id, organization: orgId, deleted: false }),
  ) > 0;
  return e.json(200, {
    organization: { id: orgId, name: org.getString("name") },
    status: status(invite),
    member: member,
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
      return;
    }
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
  });
  const org = e.app.findRecordById("organizations", orgId);
  return e.json(200, {
    organization: { id: orgId, name: org.getString("name") },
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
    title: "Einladung zu RealChord",
    invited: (org) => `Du bist eingeladen, ${org} auf RealChord beizutreten.`,
    open: "In RealChord öffnen",
    install:
      "Noch keine App? Installiere RealChord, öffne dann diesen Link nochmals " +
      "oder füge ihn in der App unter «Bands → Beitreten» ein.",
    invalid: "Diese Einladung ist ungültig, abgelaufen oder widerrufen. Bitte um einen neuen Link.",
  },
  en: {
    title: "Invitation to RealChord",
    invited: (org) => `You are invited to join ${org} on RealChord.`,
    open: "Open in RealChord",
    install:
      "No app yet? Install RealChord, then open this link again " +
      "or paste it in the app under “Bands → Join”.",
    invalid: "This invitation is invalid, expired or revoked. Please ask for a new link.",
  },
};

/// Landing page for people who open a link without the app (ADR-0005).
function landing(e) {
  const lang = (e.request.header.get("Accept-Language") || "").toLowerCase();
  const t = lang.indexOf("de") === 0 ? TEXTS.de : TEXTS.en;
  const token = e.request.pathValue("token");
  const invite = findByToken(e.app, token);
  let body;
  if (!invite || status(invite) !== "valid") {
    body = `<p>${escapeHtml(t.invalid)}</p>`;
  } else {
    const org = e.app.findRecordById("organizations", invite.getString("organization"));
    body =
      `<p>${escapeHtml(t.invited(org.getString("name")))}</p>` +
      `<p><a class="button" href="realchord://invite/${escapeHtml(token)}">${escapeHtml(t.open)}</a></p>` +
      `<p class="hint">${escapeHtml(t.install)}</p>`;
  }
  return e.html(
    200,
    `<!doctype html><html><head><meta charset="utf-8">` +
      `<meta name="viewport" content="width=device-width, initial-scale=1">` +
      `<meta name="robots" content="noindex">` +
      `<title>${escapeHtml(t.title)}</title><style>` +
      `body{font-family:system-ui,sans-serif;max-width:32rem;margin:3rem auto;padding:0 1rem;line-height:1.5}` +
      `.button{display:inline-block;padding:.75rem 1.25rem;background:#3f51b5;color:#fff;border-radius:.5rem;text-decoration:none}` +
      `.hint{color:#555}</style></head><body><h1>${escapeHtml(t.title)}</h1>${body}</body></html>`,
  );
}

const PACKAGE = "ch.realchord.realchord";

/// Android App Links verification; needs REALCHORD_ANDROID_CERT_SHA256 (one
/// or more comma-separated SHA-256 fingerprints of the signing certificate).
function assetLinks(e) {
  const prints = ($os.getenv("REALCHORD_ANDROID_CERT_SHA256") || "")
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s);
  if (prints.length === 0) throw new NotFoundError();
  return e.json(200, [{
    relation: ["delegate_permission/common.handle_all_urls"],
    target: { namespace: "android_app", package_name: PACKAGE, sha256_cert_fingerprints: prints },
  }]);
}

/// iOS Universal Links verification; needs REALCHORD_APPLE_TEAM_ID.
function appleAppSiteAssociation(e) {
  const team = ($os.getenv("REALCHORD_APPLE_TEAM_ID") || "").trim();
  if (!team) throw new NotFoundError();
  return e.json(200, {
    applinks: { details: [{ appIDs: [team + "." + PACKAGE], components: [{ "/": "/invite/*" }] }] },
  });
}

module.exports = { create, preview, redeem, landing, assetLinks, appleAppSiteAssociation };
