// Lineup per set and substitutes (ADR-0061, issue #1007).

function activeOrgMember(app, orgId, userId) {
  return (
    app.countRecords(
      "org_memberships",
      $dbx.hashExp({ organization: orgId, user: userId, deleted: false }),
    ) > 0
  );
}

/// Whether [userId] sees the sets of [band] through the records API: an
/// active member of the band or an active admin of its organization
/// (the `setlists` list rule).
function seesBand(app, band, userId) {
  if (
    app.countRecords(
      "memberships",
      $dbx.hashExp({ band: band.id, user: userId, deleted: false }),
    ) > 0
  ) {
    return true;
  }
  return (
    app.countRecords(
      "org_memberships",
      $dbx.hashExp({
        organization: band.getString("organization"),
        user: userId,
        role: "admin",
        deleted: false,
      }),
    ) > 0
  );
}

/// Whether [userId] may edit the sets of [band]: band leaders, set planners
/// and organization admins (ADR-0023).
function editsSets(app, band, userId) {
  const managers = app.findRecordsByFilter(
    "memberships",
    "band = {:band} && user = {:user} && deleted = false && (role = 'admin' || role = 'planner')",
    "",
    1,
    0,
    { band: band.id, user: userId },
  );
  if (managers.length > 0) return true;
  return (
    app.countRecords(
      "org_memberships",
      $dbx.hashExp({
        organization: band.getString("organization"),
        user: userId,
        role: "admin",
        deleted: false,
      }),
    ) > 0
  );
}

/// Create and update requests of `setlists`: a set without its own lineup
/// stores nobody, and every person added to a lineup must be an active member
/// of the band's organization. People already in the stored lineup stay,
/// so a set can still be edited after somebody left the organization.
function validate(e) {
  const record = e.record;
  if (!record.getBool("lineup_custom")) {
    record.set("lineup", []);
    record.set("lineup_contacts", []);
    return;
  }
  const lineup = record.getStringSlice("lineup");
  const before = {};
  if (!record.isNew()) {
    for (const id of record.original().getStringSlice("lineup")) before[id] = true;
  }
  let band = null;
  try {
    band = e.app.findRecordById("bands", record.getString("band"));
  } catch (_) {
    band = null;
  }
  if (!band) return; // The band relation itself is refused by the rules.
  const orgId = band.getString("organization");
  for (const id of lineup) {
    if (before[id]) continue;
    if (!activeOrgMember(e.app, orgId, id)) {
      throw new BadRequestError("Only people of the organization can be in a set's lineup.", {
        lineup: new ValidationError(
          "not_in_organization",
          "Only people of the organization can be in a set's lineup.",
        ),
      });
    }
  }
  validateContacts(e, record, orgId);
}

/// Every contact added to a lineup must be a contact of the band's
/// organization that is not deleted (ADR-0064); contacts already in the
/// stored lineup stay, so old sets keep a contact deleted later.
function validateContacts(e, record, orgId) {
  const before = {};
  if (!record.isNew()) {
    for (const id of record.original().getStringSlice("lineup_contacts")) before[id] = true;
  }
  for (const id of record.getStringSlice("lineup_contacts")) {
    if (before[id]) continue;
    let contact = null;
    try {
      contact = e.app.findRecordById("contacts", id);
    } catch (_) {
      contact = null;
    }
    if (!contact || contact.getBool("deleted") || contact.getString("organization") !== orgId) {
      throw new BadRequestError("Only contacts of the organization can be in a set's lineup.", {
        lineup_contacts: new ValidationError(
          "not_in_organization",
          "Only contacts of the organization can be in a set's lineup.",
        ),
      });
    }
  }
}

/// The contacts with [ids], deleted ones too (old sets keep their names).
function contactsByIds(app, ids) {
  return ids.length > 0 ? app.findRecordsByIds("contacts", ids) : [];
}

function songsOf(set) {
  let items = [];
  try {
    items = JSON.parse(set.getString("items") || "[]");
  } catch (_) {
    items = [];
  }
  const songs = {};
  if (!Array.isArray(items)) return songs;
  for (const item of items) {
    if (item && typeof item === "object" && typeof item.song === "string" && item.song) {
      songs[item.song] = true;
    }
  }
  return songs;
}

function person(user) {
  return {
    id: user.id,
    name: user.getString("name"),
    first_name: user.getString("first_name"),
    last_name: user.getString("last_name"),
    nickname: user.getString("nickname"),
  };
}

/// GET /api/setding/lineup: the sets the signed-in user plays as a
/// substitute, i.e. sets with their own lineup that contains them, in a band
/// whose sets they do not see through the records API, while they are an
/// active member of its organization. With the band's name, the names of the
/// lineups and the band arrangements of the songs in those sets; nothing
/// else of the band. The client replaces its substitute data with the result.
function substituteSets(e) {
  const userId = e.auth.id;
  const candidates = e.app.findRecordsByFilter(
    "setlists",
    "deleted = false && lineup_custom = true && lineup ~ {:user}" +
      " && band.deleted = false && band.organization.deleted = false",
    "",
    0,
    0,
    { user: userId },
  );
  const sets = [];
  const bands = {};
  const people = {};
  const contactIds = {};
  const songsByBand = {};
  for (const set of candidates) {
    // `~` matches the JSON text of the relation; the exact check follows.
    const lineup = set.getStringSlice("lineup");
    if (lineup.indexOf(userId) < 0) continue;
    const bandId = set.getString("band");
    let band = bands[bandId];
    if (!band) {
      band = e.app.findRecordById("bands", bandId);
      if (seesBand(e.app, band, userId)) continue;
      if (!activeOrgMember(e.app, band.getString("organization"), userId)) continue;
      bands[bandId] = band;
    }
    sets.push(set);
    for (const id of lineup) people[id] = true;
    for (const id of set.getStringSlice("lineup_contacts")) contactIds[id] = true;
    const songs = songsByBand[bandId] || {};
    const inSet = songsOf(set);
    for (const song in inSet) songs[song] = true;
    songsByBand[bandId] = songs;
  }
  const arrangements = [];
  for (const bandId in songsByBand) {
    for (const a of e.app.findRecordsByFilter(
      "arrangements",
      "band = {:band} && deleted = false",
      "",
      0,
      0,
      { band: bandId },
    )) {
      if (songsByBand[bandId][a.getString("song")]) arrangements.push(a);
    }
  }
  const users = [];
  const ids = Object.keys(people);
  if (ids.length > 0) {
    for (const user of e.app.findRecordsByIds("users", ids)) users.push(person(user));
  }
  return e.json(200, {
    sets: sets,
    bands: Object.keys(bands).map((id) => ({
      id: id,
      name: bands[id].getString("name"),
      organization: bands[id].getString("organization"),
    })),
    people: users,
    // People without an account in those lineups, names only (ADR-0064).
    contacts: contactsByIds(e.app, Object.keys(contactIds)).map((c) =>
      require(`${__hooks}/lib/contacts.js`).names(c),
    ),
    arrangements: arrangements,
  });
}

/// GET /api/setding/lineup/{set}/emails: names and mail addresses of the
/// people in a set's lineup (the band's active members when the set has no
/// lineup of its own), to notify them; and the contacts of the lineup with a
/// mail address (ADR-0064). Only for those who may edit the set;
/// everyone else gets 404, as if it did not exist.
function lineupEmails(e) {
  const userId = e.auth.id;
  const notFound = () => new NotFoundError("The requested resource wasn't found.");
  let set = null;
  try {
    set = e.app.findRecordById("setlists", e.request.pathValue("set"));
  } catch (_) {
    set = null;
  }
  if (!set || set.getBool("deleted")) throw notFound();
  const band = e.app.findRecordById("bands", set.getString("band"));
  if (band.getBool("deleted")) throw notFound();
  const org = e.app.findRecordById("organizations", band.getString("organization"));
  if (org.getBool("deleted")) throw notFound();
  if (!editsSets(e.app, band, userId)) throw notFound();

  let ids = [];
  if (set.getBool("lineup_custom")) {
    ids = set
      .getStringSlice("lineup")
      .filter((id) => activeOrgMember(e.app, org.id, id));
  } else {
    ids = e.app
      .findRecordsByFilter(
        "memberships",
        "band = {:band} && deleted = false && user != ''",
        "",
        0,
        0,
        { band: band.id },
      )
      .map((m) => m.getString("user"));
  }
  const result = [];
  if (ids.length > 0) {
    for (const user of e.app.findRecordsByIds("users", ids)) {
      result.push(Object.assign(person(user), { email: user.email() }));
    }
  }
  const contacts = [];
  if (set.getBool("lineup_custom")) {
    const names = require(`${__hooks}/lib/contacts.js`).names;
    for (const contact of contactsByIds(e.app, set.getStringSlice("lineup_contacts"))) {
      if (contact.getBool("deleted") || !contact.getString("email")) continue;
      contacts.push(Object.assign(names(contact), { email: contact.getString("email") }));
    }
  }
  return e.json(200, { people: result, contacts: contacts });
}

module.exports = { validate, substituteSets, lineupEmails };
