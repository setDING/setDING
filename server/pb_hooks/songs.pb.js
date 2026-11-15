/// <reference path="../pb_data/types.d.ts" />

// Conflict detection for songs (ADR-0004): a client sends the revision its
// change is based on in `revision`. If the server has moved on, the update is
// refused with 409 and the client shows both versions; songs are never
// silently overwritten. Sets use last writer wins and are not checked.
onRecordUpdateRequest((e) => {
  const isUser = e.auth && e.auth.collection().name === "users";
  const base = e.requestInfo().body["revision"];
  if (base === undefined || base === null || base === "") {
    if (isUser) {
      throw new BadRequestError("Missing base revision.", {
        revision: new ValidationError("missing_base_revision", "Send the revision the change is based on."),
      });
    }
  } else if (Number(base) !== e.record.original().getInt("revision")) {
    throw new ApiError(409, "The song was changed on the server.", {
      revision: new ValidationError("conflict", "The song was changed on the server."),
    });
  }
  e.next();
}, "songs");
