/// <reference path="../pb_data/types.d.ts" />

// People without an account (ADR-0064, issue #1097). The access rules decide
// who may do what (pb_migrations/1797300000_contacts.js); the logic is in
// lib/contacts.js.

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/contacts.js`).onCreate(e);
  e.next();
}, "contacts");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/contacts.js`).onUpdate(e);
  e.next();
}, "contacts");

// Deleting a contact clears its mail address and revokes its invitations,
// whoever saves it (also a superuser in the admin UI).
onRecordUpdate((e) => {
  require(`${__hooks}/lib/contacts.js`).onDelete(e);
  e.next();
}, "contacts");

// The mail address only for those who may edit sets in some band of the
// organization (ADR-0064 decision 4).
onRecordEnrich((e) => {
  require(`${__hooks}/lib/contacts.js`).enrich(e);
  e.next();
}, "contacts");
