/// <reference path="../pb_data/types.d.ts" />

// Keyboard programs per device profile (ADR-0042): a map from the profile id
// (e.g. "nordStage3", "generic") to the raw MIDI values
// `{"msb"?, "lsb"?, "program"}`. v0.16.0 clients only know `midi` and push
// it with every change of the overlay, so they leave this field untouched.
// Empty = none.
migrate(
  (app) => {
    const overlays = app.findCollectionByNameOrId("overlays");
    overlays.fields.add(
      new JSONField({ name: "midi_programs", maxSize: 10000 }),
    );
    app.save(overlays);
  },
  (app) => {
    const overlays = app.findCollectionByNameOrId("overlays");
    overlays.fields.removeByName("midi_programs");
    app.save(overlays);
  },
);
