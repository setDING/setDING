/// <reference path="../pb_data/types.d.ts" />

// Song play history, band repertoire (ADR-0046, issue #661): per band the
// number of months after which a song counts as "not played for a while"
// (`stale_after_months`, 1–36; 0 = the default of 6 months). Band leaders and
// organization admins change it like the rest of the band; set planners may
// change this field only, which `pb_hooks/bands.pb.js` enforces (ADR-0023).
const PLANNER =
  '(@collection.memberships:stale.band ?= id' +
  " && @collection.memberships:stale.user ?= @request.auth.id" +
  " && @collection.memberships:stale.deleted ?= false" +
  ' && @collection.memberships:stale.role ?= "planner")';

const PLANNER_UPDATE =
  ` || (@request.auth.collectionName = "users" && deleted = false && ${PLANNER})`;

migrate(
  (app) => {
    const bands = app.findCollectionByNameOrId("bands");
    bands.fields.add(
      new NumberField({ name: "stale_after_months", onlyInt: true, min: 0, max: 36 }),
    );
    bands.updateRule = `(${bands.updateRule})${PLANNER_UPDATE}`;
    app.save(bands);
  },
  (app) => {
    const bands = app.findCollectionByNameOrId("bands");
    bands.fields.removeByName("stale_after_months");
    const rule = bands.updateRule;
    bands.updateRule = rule.slice(1, rule.length - PLANNER_UPDATE.length - 1);
    app.save(bands);
  },
);
