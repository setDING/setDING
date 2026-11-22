/// <reference path="../pb_data/types.d.ts" />

// Trash (ADR-0043): `deleted_at` and `purged` of songs, sets and
// attachments, deleting permanently from the trash (#866) and the daily
// purge after 30 days. The purge runs at night
// and can be started by a superuser (operators, tests).

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/trash.js`).handleTrashRequest(e);
  e.next();
}, "songs", "setlists", "attachments");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/trash.js`).handleTrashRequest(e);
  e.next();
}, "songs", "setlists", "attachments");

// A song purged by a user (#866) takes its attachments with it, as the
// daily purge does, in the same transaction and before the response (code
// after `e.next()` of a request hook runs once the response is sent).
onRecordUpdateExecute((e) => {
  const purging = e.record.getBool("purged") && !e.record.original().getBool("purged");
  e.next();
  if (purging) require(`${__hooks}/lib/trash.js`).purgeAttachmentsOf(e.app, e.record);
}, "songs");

cronAdd("setding_trash_purge", "17 3 * * *", () => {
  const purged = require(`${__hooks}/lib/trash.js`).purgeTrash($app);
  if (purged > 0) $app.logger().info("Trash purged", "records", purged);
});

// With `{"collection": "bands" | "organizations", "id": "…"}` the operator
// purges one deleted band or closed organization at once instead of
// waiting for the 30 days (ADR-0044).
routerAdd(
  "POST",
  "/api/setding/trash/purge",
  (e) => {
    const body = e.requestInfo().body || {};
    if (body.collection || body.id) {
      return e.json(200, { purged: require(`${__hooks}/lib/trash.js`).purgeNow(e.app, body.collection, body.id) });
    }
    return e.json(200, { purged: require(`${__hooks}/lib/trash.js`).purgeTrash(e.app) });
  },
  $apis.requireSuperuserAuth(),
);
