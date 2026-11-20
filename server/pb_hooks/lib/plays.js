// Song play history across the bands of an organization (ADR-0046, #662).

/// GET /api/setding/plays/{organization}: per song and band of the
/// organization, how often the band played the song (each past set once),
/// when it played it last and in which key (from the frozen `played`
/// values of the most recent set that has one). Never set names or set
/// contents. For active members of the organization only; everyone else
/// gets 404, as if it did not exist.
function plays(e) {
  const userId = e.auth.id;
  const orgId = e.request.pathValue("organization");
  let org = null;
  try {
    org = e.app.findRecordById("organizations", orgId);
  } catch (_) {
    org = null;
  }
  const member =
    org &&
    !org.getBool("deleted") &&
    e.app.countRecords(
      "org_memberships",
      $dbx.hashExp({ organization: orgId, user: userId, deleted: false }),
    ) > 0;
  if (!member) throw new NotFoundError("The requested resource wasn't found.");

  // A gig today is still upcoming, as in the app.
  const today = new Date().toISOString().slice(0, 10) + " 00:00:00.000Z";
  const bands = e.app.findRecordsByFilter(
    "bands",
    "organization = {:org} && deleted = false",
    "",
    0,
    0,
    { org: orgId },
  );
  const result = [];
  for (const band of bands) {
    const sets = e.app.findRecordsByFilter(
      "setlists",
      "band = {:band} && deleted = false && gig_date != '' && gig_date < {:today}",
      "-gig_date",
      0,
      0,
      { band: band.id, today: today },
    );
    const bySong = {};
    for (const set of sets) {
      let items = [];
      try {
        items = JSON.parse(set.getString("items") || "[]");
      } catch (_) {
        items = [];
      }
      if (!Array.isArray(items)) continue;
      const date = set.getString("gig_date");
      const seen = {};
      for (const item of items) {
        if (!item || item.type !== "song" || !item.song || seen[item.song]) continue;
        seen[item.song] = true;
        const entry = bySong[item.song] || { count: 0, last: date, key: null };
        entry.count++;
        // Newest first: the first key found is the most recent one.
        if (entry.key === null && item.played && typeof item.played.key === "string") {
          entry.key = item.played.key;
        }
        bySong[item.song] = entry;
      }
    }
    for (const song in bySong) {
      result.push({
        song: song,
        band: band.id,
        bandName: band.getString("name"),
        count: bySong[song].count,
        last: bySong[song].last,
        key: bySong[song].key,
      });
    }
  }
  return e.json(200, { plays: result });
}

module.exports = { plays };
