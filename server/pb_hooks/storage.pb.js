/// <reference path="../pb_data/types.d.ts" />

// Storage limit per organization (ADR-0070); the logic is in lib/storage.js.

// The check and the insert run in one write transaction (PocketBase writes
// through a single connection), so parallel uploads cannot both pass it;
// sync.pb.js runs the save in this transaction too.
onRecordCreateRequest((e) => {
  e.app.runInTransaction((txApp) => {
    e.app = txApp;
    require(`${__hooks}/lib/storage.js`).checkUpload(e);
    e.next();
  });
}, "attachments");

// `size_bytes` belongs to the file, which never changes (attachments.pb.js):
// users cannot change it afterwards.
onRecordUpdateRequest((e) => {
  if (e.auth && e.auth.collection().name === "users") {
    e.record.set("size_bytes", e.record.original().getInt("size_bytes"));
  }
  e.next();
}, "attachments");

routerAdd("GET", "/api/setding/organizations/{id}/storage", (e) =>
  require(`${__hooks}/lib/storage.js`).storage(e), $apis.requireAuth("users"));
