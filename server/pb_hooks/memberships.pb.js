/// <reference path="../pb_data/types.d.ts" />

// Every band must always keep at least one admin (ADR-0005): demoting or
// removing the last active admin is refused.
onRecordUpdate((e) => {
  const before = e.record.original();
  const wasAdmin = before.getString("role") === "admin" && !before.getBool("deleted");
  const isAdmin = e.record.getString("role") === "admin" && !e.record.getBool("deleted");
  if (wasAdmin && !isAdmin) {
    const others = e.app.countRecords(
      "memberships",
      $dbx.hashExp({ band: e.record.getString("band"), role: "admin", deleted: false }),
      $dbx.not($dbx.hashExp({ id: e.record.id })),
    );
    if (others === 0) {
      throw new BadRequestError("A band must keep at least one admin.", {
        role: new ValidationError("last_admin", "A band must keep at least one admin."),
      });
    }
  }
  e.next();
}, "memberships");
