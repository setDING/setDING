/// <reference path="../pb_data/types.d.ts" />

// Attachment files are immutable (ADR-0004, ADR-0009): a new file is uploaded
// as a new attachment record, so there are never file conflicts.
onRecordUpdate((e) => {
  if (e.record.getString("file") !== e.record.original().getString("file")) {
    throw new BadRequestError("Attachment files cannot be replaced; create a new attachment.", {
      file: new ValidationError("immutable", "Attachment files cannot be replaced."),
    });
  }
  e.next();
}, "attachments");
