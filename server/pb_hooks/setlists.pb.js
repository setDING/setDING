/// <reference path="../pb_data/types.d.ts" />

// Fields of a set item that older apps do not know and drop when they save
// a set; the server keeps the stored value of an item with the same ID that
// is sent without the field, so older apps do not erase it and need no
// forced update. Newer apps always send the fields they know.
//
// - `played` (ADR-0046): how a song was played, frozen on the gig day;
//   known from 0.17.0 on.
// - `icon` (ADR-0047): the icon of a set marker; apps from 0.17.0 keep it
//   as an unknown field, older ones drop it.

onRecordUpdateRequest((e) => {
  const kept = ["played", "icon"];
  const parse = (record) => {
    try {
      const value = JSON.parse(record.getString("items") || "[]");
      return Array.isArray(value) ? value : null;
    } catch (_) {
      return null;
    }
  };
  const stored = parse(e.record.original());
  const sent = parse(e.record);
  if (stored && sent) {
    const byId = {};
    for (const item of stored) {
      if (item && typeof item === "object" && item.id) byId[item.id] = item;
    }
    let changed = false;
    for (const item of sent) {
      if (!item || typeof item !== "object" || !item.id) continue;
      const before = byId[item.id];
      if (!before) continue;
      for (const field of kept) {
        if (!(field in item) && before[field]) {
          item[field] = before[field];
          changed = true;
        }
      }
    }
    if (changed) e.record.set("items", sent);
  }
  e.next();
}, "setlists");
