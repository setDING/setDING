import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../data/attachment_storage.dart';
import 'stored_file_view_memory.dart';

/// An image attachment, scaled to [width] × [height].
Widget storedImage(
  StoredFile file, {
  required double width,
  required double height,
}) => memoryImage(file, width: width, height: height);

/// A PDF attachment; [file] must exist.
Widget storedPdfViewer(
  StoredFile file, {
  Key? key,
  PdfViewerController? controller,
  PdfViewerParams params = const PdfViewerParams(),
}) => memoryPdfViewer(file, key: key, controller: controller, params: params);
