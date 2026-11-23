/// <reference path="../pb_data/types.d.ts" />

// First name, last name and nickname of accounts (ADR-0062, issue #1039);
// the logic is in lib/names.js.

// Sign-up is checked in registration.pb.js, after the invitation, so a
// sign-up without one is refused as such (403) first.

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/names.js`).check(e, false);
  e.next();
}, "users");
