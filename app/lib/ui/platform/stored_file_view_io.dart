import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../data/attachment_storage.dart';
import '../../data/attachment_storage_io.dart';
import 'stored_file_view_memory.dart';

/// An image attachment, scaled to [width] × [height].
Widget storedImage(
  StoredFile file, {
  required double width,
  required double height,
}) {
  if (file is! IoStoredFile) {
    return memoryImage(file, width: width, height: height);
  }
  if (isSvgFile(file.name)) {
    return SvgPicture.file(file.file, width: width, height: height);
  }
  return Image.file(
    file.file,
    width: width,
    height: height,
    fit: BoxFit.contain,
  );
}

/// A PDF attachment; [file] must exist.
Widget storedPdfViewer(
  StoredFile file, {
  Key? key,
  PdfViewerController? controller,
  PdfViewerParams params = const PdfViewerParams(),
}) {
  if (file is! IoStoredFile) {
    return memoryPdfViewer(
      file,
      key: key,
      controller: controller,
      params: params,
    );
  }
  return PdfViewer.file(
    file.file.path,
    key: key,
    controller: controller,
    params: params,
  );
}

/// A reference to a PDF attachment, for page widgets; [file] must exist.
PdfDocumentRef storedPdfDocumentRef(StoredFile file) => file is IoStoredFile
    ? PdfDocumentRefFile(file.file.path)
    : memoryPdfDocumentRef(file);
