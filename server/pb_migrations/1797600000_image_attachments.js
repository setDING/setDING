/// <reference path="../pb_data/types.d.ts" />

// Image attachments for ChordPro `{image}` are synced like PDFs (ADR-0009,
// ADR-0012, issue #1227): the `file` field of `attachments` also accepts the
// image types the app supports (PNG, JPEG, GIF, WebP, SVG). PocketBase
// detects the type from the file's content, not from its name. The limits of
// ADR-0070 apply unchanged: at most 1 MB per file (`maxSize`), counted
// toward the organization's storage limit (pb_hooks/lib/storage.js counts
// every attachment that has a file).
//
// SVG files stay protected like every attachment, and PocketBase serves
// them as a download (`Content-Disposition: attachment`) with a sandboxing
// Content-Security-Policy, never inline as a document (test/image_attachments_test.dart).
const PDF = ["application/pdf"];
const WITH_IMAGES = [
  "application/pdf",
  "image/png",
  "image/jpeg",
  "image/gif",
  "image/webp",
  "image/svg+xml",
];

migrate(
  (app) => {
    const attachments = app.findCollectionByNameOrId("attachments");
    attachments.fields.getByName("file").mimeTypes = WITH_IMAGES;
    app.save(attachments);
  },
  (app) => {
    const attachments = app.findCollectionByNameOrId("attachments");
    attachments.fields.getByName("file").mimeTypes = PDF;
    app.save(attachments);
  },
);
