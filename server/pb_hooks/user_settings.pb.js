/// <reference path="../pb_data/types.d.ts" />

// Personal settings (ADR-0027): an update merges the sent keys into the
// stored settings (last writer wins per key), so two devices that changed
// different settings offline keep both changes.

onRecordUpdateRequest((e) => {
  const parse = (record) => {
    try {
      const value = JSON.parse(record.getString("data") || "{}");
      return value && typeof value === "object" && !Array.isArray(value)
        ? value
        : {};
    } catch (_) {
      return {};
    }
  };
  const stored = parse(e.record.original());
  const sent = parse(e.record);
  e.record.set("data", Object.assign({}, stored, sent));
  e.next();
}, "user_settings");
