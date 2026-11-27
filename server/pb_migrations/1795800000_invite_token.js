/// <reference path="../pb_data/types.d.ts" />

// Showing an active invitation link again (ADR-0005, issue #579): besides
// its hash, the server stores the token encrypted with the key
// `SETDING_INVITE_KEY` from `pocketbase.env` (pb_hooks/lib/invites.js).
// Hidden like the hash, and never set through the records API.

/// [rule] with the first [from] replaced by [to]; throws if [rule] does not
/// contain [from], so a migration never silently leaves a rule unchanged
/// (issue #1201).
function replaceInRule(rule, from, to) {
  const i = rule === null ? -1 : rule.indexOf(from);
  if (i < 0) throw new Error(`Rule does not contain: ${from}`);
  return rule.slice(0, i) + to + rule.slice(i + from.length);
}

migrate(
  (app) => {
    const invites = app.findCollectionByNameOrId("invites");
    invites.fields.add(new TextField({ name: "token_enc", hidden: true }));
    invites.updateRule += " && @request.body.token_enc:isset = false";
    app.save(invites);
  },
  (app) => {
    const invites = app.findCollectionByNameOrId("invites");
    invites.fields.removeByName("token_enc");
    invites.updateRule = replaceInRule(
      invites.updateRule,
      " && @request.body.token_enc:isset = false",
      "",
    );
    app.save(invites);
  },
);
