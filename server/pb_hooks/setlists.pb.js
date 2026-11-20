/// <reference path="../pb_data/types.d.ts" />

// Song play history (ADR-0046): a set item stores how its song was played
// (`played`), frozen on the gig day. Apps before 0.17.0 do not know the field
// and send the items without it when they save the set; the server keeps the
// stored value of an item with the same ID that is sent without `played`, so
// older apps do not erase the history and need no forced update. Apps from
// 0.17.0 on always send the field when it is known.

onRecordUpdateRequest((e) => {
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
    const played = {};
    for (const item of stored) {
      if (item && typeof item === "object" && item.id && item.played) {
        played[item.id] = item.played;
      }
    }
    let changed = false;
    for (const item of sent) {
      if (
        item &&
        typeof item === "object" &&
        item.id &&
        !("played" in item) &&
        played[item.id]
      ) {
        item.played = played[item.id];
        changed = true;
      }
    }
    if (changed) e.record.set("items", sent);
  }
  e.next();
}, "setlists");
