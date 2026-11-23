/// <reference path="../pb_data/types.d.ts" />

// First name, last name and nickname of accounts (ADR-0062, issue #1039);
// the logic is in lib/names.js.

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/names.js`).check(e, true);
  e.next();
}, "users");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/names.js`).check(e, false);
  e.next();
}, "users");
