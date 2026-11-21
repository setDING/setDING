// Helpers for the song hooks: language versions (ADR-0053).

/// Fields of a song that are last writer wins per field and never part of
/// the conflict check: the language version group and the language.
const LINK_FIELDS = ["work_id", "language"];

/// Fields whose change is a change of the song's content (ADR-0004): the
/// conflict check and `content_revision` follow them.
const CONTENT_FIELDS = ["organization", "title", "chordpro", "deleted", "deleted_at", "purged"];

/// True if an update request changes only link fields (besides an optional
/// base revision).
function isLinkOnlyRequest(e) {
  const keys = Object.keys(e.requestInfo().body || {}).filter((k) => k !== "revision");
  return keys.length > 0 && keys.every((k) => LINK_FIELDS.includes(k));
}

/// True if an update changes the content of the song.
function contentChanged(record) {
  const original = record.original();
  return CONTENT_FIELDS.some((f) => String(record.get(f)) !== String(original.get(f)));
}

/// Refuses a group ID that a song of another organization already uses:
/// language versions stay within one library (ADR-0017, ADR-0053).
function checkWorkId(e) {
  const workId = e.record.getString("work_id");
  if (workId === "") return;
  const others = e.app.findRecordsByFilter(
    "songs",
    "work_id = {:work} && organization != {:org}",
    "",
    1,
    0,
    { work: workId, org: e.record.getString("organization") },
  );
  if (others.length > 0) {
    throw new BadRequestError("The group belongs to another organization.", {
      work_id: new ValidationError("other_organization", "The group belongs to another organization."),
    });
  }
}

module.exports = { LINK_FIELDS, isLinkOnlyRequest, contentChanged, checkWorkId };
