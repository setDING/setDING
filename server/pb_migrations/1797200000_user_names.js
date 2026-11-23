/// <reference path="../pb_data/types.d.ts" />

// First name, last name and nickname of accounts (ADR-0062, issue #1039).
// The fields are not `required` in the schema, so accounts from before keep
// working until their owner completes the name (the app asks after sign-in);
// the hook in pb_hooks/names.pb.js requires them on sign-up and refuses
// clearing them. Existing names are split: two or more words become first
// name(s) and last name, a single word becomes the nickname.
migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    for (const name of ["first_name", "last_name", "nickname"]) {
      users.fields.add(new TextField({ name, max: 100 }));
    }
    app.save(users);

    for (const user of app.findAllRecords("users")) {
      const words = String(user.getString("name") || "").trim().split(/\s+/).filter((w) => w);
      if (words.length >= 2) {
        user.set("first_name", words.slice(0, -1).join(" "));
        user.set("last_name", words[words.length - 1]);
      } else {
        user.set("nickname", words.join(""));
      }
      app.saveNoValidate(user);
    }
  },
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    for (const name of ["first_name", "last_name", "nickname"]) {
      users.fields.removeByName(name);
    }
    app.save(users);
  },
);
