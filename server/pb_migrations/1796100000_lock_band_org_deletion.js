/// <reference path="../pb_data/types.d.ts" />

// Bands and organizations cannot be deleted through the API (issue #627):
// the app offers neither action and ADR-0023's permission matrix does not
// grant it, but the update rules let band leaders and organization admins
// set `deleted`. Deleting a band and closing an organization become
// features of their own, with their rules decided then.
const LOCK = " && @request.body.deleted:changed = false";

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
    for (const name of ["bands", "organizations"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.updateRule += LOCK;
      app.save(collection);
    }
  },
  (app) => {
    for (const name of ["bands", "organizations"]) {
      const collection = app.findCollectionByNameOrId(name);
      collection.updateRule = replaceInRule(collection.updateRule, LOCK, "");
      app.save(collection);
    }
  },
);
