/// <reference path="../pb_data/types.d.ts" />

// Keyboard program per user and song (ADR-0039): raw MIDI values
// `{"msb"?, "lsb"?, "program"}` in a field of its own, not a key in the
// overlay's `data`. Older clients send only `data` and `deleted`, so they
// leave it untouched when they change other adjustments. Empty = none.
migrate(
  (app) => {
    const overlays = app.findCollectionByNameOrId("overlays");
    overlays.fields.add(new JSONField({ name: "midi", maxSize: 1000 }));
    app.save(overlays);
  },
  (app) => {
    const overlays = app.findCollectionByNameOrId("overlays");
    overlays.fields.removeByName("midi");
    app.save(overlays);
  },
);
