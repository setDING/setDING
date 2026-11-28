import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chordpro/chordpro.dart' show ImageLine;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/attachment_storage.dart';
import '../platform/stored_file_view.dart';
import 'song_style.dart';

/// Finds the file of an `{image: src=…}` (an attachment of the song).
typedef ImageLookup = StoredFile? Function(String src);

/// The file and placement of an `{image}`, or null if the image is not
/// attached to the song or cannot be read.
(StoredFile, ImageBox)? resolveImage(ImageLine line, ImageLookup? lookup) {
  final src = line.src;
  if (lookup == null || src == null || src.isEmpty) return null;
  final file = lookup(src);
  if (file == null) return null;
  final natural = imageFileSize(file);
  if (natural == null) return null;
  return (file, ImageBox.fromAttributes(line.attributes, natural));
}

/// Pixels of an image that correspond to one unit of font size, so that
/// images scale with the text in live mode.
const imagePixelsPerUnit = 20.0;

/// Points per unit of font size (12 pt = normal text size).
const pointsPerUnit = 12.0;

/// Size and placement of an image, independent of the font size.
class ImageBox {
  const ImageBox({
    this.widthUnits,
    this.widthFraction,
    required this.aspect,
    this.alignment = Alignment.center,
  });

  /// Width in units of the font size, or null if [widthFraction] is used.
  final double? widthUnits;

  /// Width as a fraction of the column width (`width="50%"`).
  final double? widthFraction;

  /// Width / height.
  final double aspect;

  final Alignment alignment;

  /// Displayed width at [fontSize] in a column of [columnWidth].
  double width(double fontSize, double columnWidth) {
    final wanted = widthFraction != null
        ? widthFraction! * columnWidth
        : widthUnits! * fontSize;
    return math.max(1, math.min(wanted, columnWidth));
  }

  double height(double fontSize, double columnWidth) =>
      width(fontSize, columnWidth) / aspect;

  /// Placement from ChordPro image attributes (`width`, `height`, `scale`,
  /// `align`) and the image's natural size in pixels.
  factory ImageBox.fromAttributes(
    Map<String, String> attributes,
    Size natural,
  ) {
    final aspect = natural.height <= 0 ? 1.0 : natural.width / natural.height;
    double? units(String? value) {
      if (value == null) return null;
      final v = value.trim().toLowerCase().replaceAll('pt', '');
      final n = double.tryParse(v);
      return n == null ? null : n / pointsPerUnit;
    }

    double? fraction(String? value) {
      if (value == null || !value.trim().endsWith('%')) return null;
      final n = double.tryParse(value.trim().replaceAll('%', ''));
      return n == null ? null : n / 100;
    }

    double scale = 1;
    final scaleText = attributes['scale'];
    if (scaleText != null) {
      final first = scaleText.split(',').first.trim();
      scale = first.endsWith('%')
          ? (double.tryParse(first.replaceAll('%', '')) ?? 100) / 100
          : double.tryParse(first) ?? 1;
    }

    final widthText = attributes['width'];
    final heightText = attributes['height'];
    double? widthUnits;
    double? widthFraction = fraction(widthText);
    if (widthFraction == null) widthUnits = units(widthText);
    if (widthUnits == null && widthFraction == null) {
      final heightFraction = fraction(heightText);
      final heightUnits = units(heightText);
      if (heightUnits != null) {
        widthUnits = heightUnits * aspect;
      } else if (heightFraction == null) {
        widthUnits = natural.width / imagePixelsPerUnit;
      } else {
        widthUnits = natural.width / imagePixelsPerUnit;
      }
    }
    if (widthUnits != null) widthUnits *= scale;
    if (widthFraction != null) widthFraction *= scale;

    final alignment = switch ((attributes['align'] ??
            attributes['center'] ??
            '')
        .trim()
        .toLowerCase()) {
      'left' || '0' => Alignment.centerLeft,
      'right' => Alignment.centerRight,
      _ => Alignment.center,
    };
    return ImageBox(
      widthUnits: widthUnits,
      widthFraction: widthFraction,
      aspect: aspect,
      alignment: alignment,
    );
  }
}

final _sizeCache = <String, Size?>{};

/// Natural size of an image file in pixels (PNG, GIF, JPEG, WebP, SVG),
/// read from the file header. Null if unknown. A file that is not there
/// yet is not remembered: the web client loads it later (#1227).
Size? imageFileSize(StoredFile file) {
  if (_sizeCache.containsKey(file.id)) return _sizeCache[file.id];
  final bytes = file.readStartSync(256 * 1024);
  if (bytes == null) return null;
  Size? size;
  try {
    size = isSvgFile(file.name)
        ? svgSize(String.fromCharCodes(bytes))
        : imageBytesSize(bytes);
  } catch (_) {
    size = null;
  }
  return _sizeCache[file.id] = size;
}

/// Natural size from raster image bytes.
Size? imageBytesSize(Uint8List b) {
  int be16(int i) => (b[i] << 8) | b[i + 1];
  int be32(int i) =>
      (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  int le16(int i) => b[i] | (b[i + 1] << 8);
  int le24(int i) => b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);

  if (b.length >= 24 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E) {
    return Size(be32(16).toDouble(), be32(20).toDouble()); // PNG IHDR
  }
  if (b.length >= 10 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
    return Size(le16(6).toDouble(), le16(8).toDouble()); // GIF
  }
  if (b.length >= 30 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[8] == 0x57 &&
      b[9] == 0x45) {
    final chunk = String.fromCharCodes(b.sublist(12, 16));
    if (chunk == 'VP8X') {
      return Size((le24(24) + 1).toDouble(), (le24(27) + 1).toDouble());
    }
    if (chunk == 'VP8 ') {
      return Size(
        (le16(26) & 0x3FFF).toDouble(),
        (le16(28) & 0x3FFF).toDouble(),
      );
    }
    if (chunk == 'VP8L') {
      final bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
      return Size(
        ((bits & 0x3FFF) + 1).toDouble(),
        (((bits >> 14) & 0x3FFF) + 1).toDouble(),
      );
    }
  }
  if (b.length >= 4 && b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = b[i + 1];
      final length = be16(i + 2);
      final isFrame =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isFrame) {
        return Size(be16(i + 7).toDouble(), be16(i + 5).toDouble());
      }
      i += 2 + length;
    }
  }
  return null;
}

final _svgTag = RegExp(r'<svg\b[^>]*>', caseSensitive: false);
final _svgAttr = RegExp(
  r'''\b(width|height|viewBox)\s*=\s*["']([^"']*)["']''',
  caseSensitive: false,
);

/// Natural size of an SVG document: `width`/`height` (absolute units), or
/// the `viewBox`, or the browser default of 300 × 150.
Size svgSize(String svg) {
  final tag = _svgTag.firstMatch(svg)?.group(0);
  double? width;
  double? height;
  List<double>? viewBox;
  if (tag != null) {
    for (final m in _svgAttr.allMatches(tag)) {
      final value = m.group(2)!.trim();
      switch (m.group(1)!.toLowerCase()) {
        case 'width':
          width = _svgLength(value);
        case 'height':
          height = _svgLength(value);
        case 'viewbox':
          final parts = value.split(RegExp(r'[\s,]+')).map(double.tryParse);
          if (parts.length == 4 && parts.every((p) => p != null)) {
            viewBox = [for (final p in parts) p!];
          }
      }
    }
  }
  if (width != null && height != null) return Size(width, height);
  if (viewBox != null && viewBox[2] > 0 && viewBox[3] > 0) {
    if (width != null) return Size(width, width * viewBox[3] / viewBox[2]);
    if (height != null) return Size(height * viewBox[2] / viewBox[3], height);
    return Size(viewBox[2], viewBox[3]);
  }
  return const Size(300, 150);
}

double? _svgLength(String value) {
  final m = RegExp(r'^([\d.]+)\s*(px|pt|mm|cm|in)?$').firstMatch(value);
  if (m == null) return null;
  final n = double.tryParse(m.group(1)!);
  if (n == null) return null;
  return switch (m.group(2)) {
    'pt' => n * 4 / 3,
    'mm' => n * 96 / 25.4,
    'cm' => n * 96 / 2.54,
    'in' => n * 96,
    _ => n,
  };
}

/// An image placed according to its [ImageBox], fitting the column.
class SongImageView extends StatelessWidget {
  const SongImageView({
    super.key,
    required this.box,
    required this.fontSize,
    this.file,
    this.svg,
  });

  final ImageBox box;
  final double fontSize;
  final StoredFile? file;

  /// SVG source (`{start_of_svg}`).
  final String? svg;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = box.width(fontSize, constraints.maxWidth);
      final height = width / box.aspect;
      final Widget image;
      if (svg != null) {
        image = SvgPicture.string(svg!, width: width, height: height);
      } else {
        image = storedImage(file!, width: width, height: height);
      }
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: fontSize * SongSpacing.lineItemPadding,
        ),
        child: Align(alignment: box.alignment, child: image),
      );
    },
  );
}
