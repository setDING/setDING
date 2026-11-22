import 'package:material_ui/material_ui.dart';

// The path of the backup folder in one line (#889): when it does not fit,
// the folders in the middle give way to "…", so the start (the home folder
// or the drive) and the folder itself stay visible.

/// [path] shortened in the middle until [fits] says it fits: the first
/// part, "…", and as many of the last parts as fit, at least the last one.
/// Unchanged when it fits or has too few parts to shorten.
String shortenPath(String path, bool Function(String text) fits) {
  if (fits(path)) return path;
  final separator = path.contains('/') ? '/' : r'\';
  final parts = path.split(separator);
  if (parts.length < 3) return path;
  for (var tail = parts.length - 2; tail >= 1; tail--) {
    final text = [
      parts.first,
      '…',
      ...parts.sublist(parts.length - tail),
    ].join(separator);
    if (fits(text) || tail == 1) return text;
  }
  return path;
}

/// A folder path in one line, shortened in the middle when it is too long.
class FolderPathText extends StatelessWidget {
  const FolderPathText(this.path, {super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        bool fits(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout(maxWidth: constraints.maxWidth);
          final overflows = painter.didExceedMaxLines;
          painter.dispose();
          return !overflows;
        }

        return Text(
          constraints.hasBoundedWidth ? shortenPath(path, fits) : path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        );
      },
    );
  }
}
