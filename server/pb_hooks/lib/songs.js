// Helpers for the song hooks: language versions (ADR-0053) and the review
// status (ADR-0060).

/// Fields of a song that are last writer wins per field and never part of
/// the conflict check: the language version group, the language and the
/// review status.
const LINK_FIELDS = ["work_id", "language", "review_state", "review_reason"];

/// Fields of the review status a client writes; `reviewed_by` and
/// `reviewed_at` follow them and are set by the server.
const REVIEW_FIELDS = ["review_state", "review_reason"];

/// Fields whose change is a change of the song's content (ADR-0004): the
/// conflict check and `content_revision` follow them.
const CONTENT_FIELDS = ["organization", "title", "chordpro", "deleted", "deleted_at", "purged"];

/// True if an update request changes only link or review fields (besides an
/// optional base revision).
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

/// Keeps the review fields of a song consistent for a write request: an
/// approved song has no reason, and `reviewed_by` / `reviewed_at` name who
/// set the current state and when. Clients cannot set them.
function handleReview(e) {
  const record = e.record;
  if (record.getString("review_state") === "") record.set("review_reason", "");
  const original = record.isNew() ? null : record.original();
  const changed = original
    ? REVIEW_FIELDS.some((f) => record.getString(f) !== original.getString(f))
    : record.getString("review_state") !== "";
  if (changed) {
    record.set("reviewed_by", require(`${__hooks}/lib/sync.js`).requestUserId(e));
    record.set("reviewed_at", new DateTime());
  } else if (original) {
    record.set("reviewed_by", original.getString("reviewed_by"));
    record.set("reviewed_at", original.getString("reviewed_at"));
  } else {
    record.set("reviewed_by", "");
    record.set("reviewed_at", "");
  }
}

module.exports = { LINK_FIELDS, isLinkOnlyRequest, contentChanged, checkWorkId, handleReview };
