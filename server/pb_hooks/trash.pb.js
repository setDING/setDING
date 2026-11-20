/// <reference path="../pb_data/types.d.ts" />

// Trash (ADR-0043): `deleted_at` and `purged` of songs, sets and
// attachments, and the daily purge after 30 days. The purge runs at night
// and can be started by a superuser (operators, tests).

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/trash.js`).handleTrashRequest(e);
  e.next();
}, "songs", "setlists", "attachments");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/trash.js`).handleTrashRequest(e);
  e.next();
}, "songs", "setlists", "attachments");

cronAdd("setding_trash_purge", "17 3 * * *", () => {
  const purged = require(`${__hooks}/lib/trash.js`).purgeTrash($app);
  if (purged > 0) $app.logger().info("Trash purged", "records", purged);
});

routerAdd(
  "POST",
  "/api/setding/trash/purge",
  (e) => e.json(200, { purged: require(`${__hooks}/lib/trash.js`).purgeTrash(e.app) }),
  $apis.requireSuperuserAuth(),
);
