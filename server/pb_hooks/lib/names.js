/// <reference path="../../pb_data/types.d.ts" />

// Names of people (ADR-0062, issue #1039): every account has a first and a
// last name (required) and an optional nickname. The old `name` field is
// maintained by the server as the display name (nickname, otherwise the
// full name), for older app versions and server routes that only know it.

const MAX = 100;

function clean(value) {
  return String(value == null ? "" : value).trim().replace(/\s+/g, " ");
}

/// Splits a single name as older app versions sent it: two or more words
/// become first name(s) and last name, a single word becomes the nickname.
function split(name) {
  const words = clean(name).split(" ").filter((w) => w);
  if (words.length >= 2) {
    return { first: words.slice(0, -1).join(" "), last: words[words.length - 1], nickname: "" };
  }
  return { first: "", last: "", nickname: words.join("") };
}

/// Nickname, otherwise "First Last".
function display(first, last, nickname) {
  const nick = clean(nickname);
  if (nick) return nick;
  return clean(`${clean(first)} ${clean(last)}`);
}

/// Cleans the name fields of [record] and sets `name` from them.
function apply(record) {
  for (const field of ["first_name", "last_name", "nickname"]) {
    record.set(field, clean(record.getString(field)));
  }
  record.set(
    "name",
    display(record.getString("first_name"), record.getString("last_name"), record.getString("nickname")),
  );
}

function has(body, key) {
  return Object.prototype.hasOwnProperty.call(body, key);
}

function missing() {
  return new ValidationError("validation_required", "Cannot be blank.");
}

/// Create and update requests on `users`: first and last name are required
/// on sign-up and cannot be cleared later. A request of an older app that
/// only sends `name` is split (see [split]); `name` itself is never taken
/// from a client.
function check(e, creating) {
  // Before the migration of ADR-0062 (migration tests) there are no fields.
  if (!e.record.collection().fields.getByName("first_name")) return;
  const body = e.requestInfo().body || {};
  const fields = ["first_name", "last_name", "nickname"];
  if (has(body, "name") && !fields.some((f) => has(body, f))) {
    const parts = split(body["name"]);
    if (creating || parts.first) {
      e.record.set("first_name", parts.first);
      e.record.set("last_name", parts.last);
    }
    e.record.set("nickname", parts.nickname);
  }
  apply(e.record);
  const errors = {};
  for (const field of ["first_name", "last_name"]) {
    const value = e.record.getString(field);
    if ((creating || has(body, field)) && !value) errors[field] = missing();
    if (value.length > MAX) errors[field] = new ValidationError("validation_max_text_constraint", `At most ${MAX} characters.`);
  }
  if (e.record.getString("nickname").length > MAX) {
    errors.nickname = new ValidationError("validation_max_text_constraint", `At most ${MAX} characters.`);
  }
  if (Object.keys(errors).length > 0) {
    // Older apps only show errors of `name`.
    if (!fields.some((f) => has(body, f))) errors.name = missing();
    throw new BadRequestError("First and last name are required.", errors);
  }
}

module.exports = { MAX, clean, split, display, apply, check };
