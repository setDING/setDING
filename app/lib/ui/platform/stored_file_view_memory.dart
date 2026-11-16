import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../data/attachment_storage.dart';

/// An image attachment drawn from its bytes.
Widget memoryImage(
  StoredFile file, {
  required double width,
  required double height,
}) {
  final bytes = file.readStartSync(maxAttachmentBytes);
  if (bytes == null) return SizedBox(width: width, height: height);
  if (isSvgFile(file.name)) {
    return SvgPicture.memory(bytes, width: width, height: height);
  }
  return Image.memory(bytes, width: width, height: height, fit: BoxFit.contain);
}

/// A PDF attachment shown from its bytes.
Widget memoryPdfViewer(
  StoredFile file, {
  Key? key,
  PdfViewerController? controller,
  PdfViewerParams params = const PdfViewerParams(),
}) => PdfViewer.data(
  file.readStartSync(maxAttachmentBytes)!,
  sourceName: file.id,
  key: key,
  controller: controller,
  params: params,
);
