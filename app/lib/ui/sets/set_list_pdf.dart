import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/marker_icons.dart';
import 'set_list.dart';

/// Fonts embedded in the PDF (ADR-0013): the standard PDF fonts only cover
/// Latin-1.
class SetListFonts {
  const SetListFonts(this.regular, this.bold);

  final pw.Font regular;
  final pw.Font bold;

  static Future<SetListFonts> load() async => SetListFonts(
    pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf')),
    pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf')),
  );
}

/// Largest and smallest font size of the song rows, in points.
const setListMaxFontSize = 18.0;
const setListMinFontSize = 12.0;

/// A rendered set list PDF and the font size of its song rows.
typedef SetListPdf = ({Uint8List bytes, double fontSize, int pages});

/// Printable set list (ADR-0013): A4 portrait, black on white, one row per
/// song with number, title, key and sequence. The font shrinks from
/// [setListMaxFontSize] down to [setListMinFontSize] so that the set fits on
/// one page; longer sets continue on further pages with page numbers.
Future<SetListPdf> setListPdf(SetList list, SetListFonts fonts) async {
  for (var size = setListMaxFontSize; ; size--) {
    final doc = _build(list, fonts, size);
    final bytes = await doc.save();
    final pages = doc.document.pdfPageList.pages.length;
    if (pages == 1 || size <= setListMinFontSize) {
      return (bytes: bytes, fontSize: size, pages: pages);
    }
  }
}

const _muted = PdfColor.fromInt(0xff555555);
const _line = PdfColor.fromInt(0xffbbbbbb);

pw.Document _build(SetList list, SetListFonts fonts, double size) {
  final doc = pw.Document(
    title: list.name,
    creator: 'setDING',
    theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
  );
  final regular = pw.TextStyle(fontSize: size);
  final bold = pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold);
  final muted = pw.TextStyle(fontSize: size * 0.8, color: _muted);
  final cellPadding = pw.EdgeInsets.symmetric(vertical: size * 0.3);

  pw.Widget songTable(List<SetListSong> songs) => pw.Table(
    columnWidths: {
      0: pw.FixedColumnWidth(size * 2),
      1: const pw.FlexColumnWidth(5),
      2: pw.FixedColumnWidth(size * 3),
      3: const pw.FlexColumnWidth(4),
    },
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      bottom: pw.BorderSide(color: _line, width: 0.5),
    ),
    children: [
      for (final song in songs)
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.top,
          children: [
            pw.Padding(
              padding: cellPadding,
              child: pw.Text(
                '${song.number}',
                style: regular.copyWith(color: _muted),
              ),
            ),
            pw.Padding(
              padding: cellPadding.copyWith(right: size * 0.5),
              child: pw.Text(song.title, style: bold),
            ),
            pw.Padding(
              padding: cellPadding,
              child: pw.Text(song.key ?? '', style: bold),
            ),
            pw.Padding(
              padding: cellPadding,
              child: pw.Text(song.sequence ?? '', style: regular),
            ),
          ],
        ),
    ],
  );

  // Every marker is a divider with its title in the middle (ADR-0047). A
  // longer text of an older app is shortened so the line stays visible.
  pw.Widget marker(SetListMarker marker) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: size * 0.4),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Divider(color: _muted, thickness: 1)),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: size * 0.5),
          child: pw.Text(shortenMarkerText(marker.text), style: muted),
        ),
        pw.Expanded(child: pw.Divider(color: _muted, thickness: 1)),
      ],
    ),
  );

  // Consecutive songs form one table; markers sit between the tables.
  final body = <pw.Widget>[];
  var songs = <SetListSong>[];
  void flush() {
    if (songs.isNotEmpty) body.add(songTable(songs));
    songs = [];
  }

  for (final row in list.rows) {
    switch (row) {
      case SetListSong():
        songs.add(row);
      case SetListMarker():
        flush();
        body.add(marker(row));
    }
  }
  flush();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(15 * PdfPageFormat.mm),
      header: (context) => context.pageNumber > 1
          ? pw.Padding(
              padding: pw.EdgeInsets.only(bottom: size * 0.5),
              child: pw.Text(list.name, style: muted),
            )
          : pw.SizedBox(),
      footer: (context) => context.pagesCount > 1
          ? pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: muted,
              ),
            )
          : pw.SizedBox(),
      build: (context) => [
        pw.Text(
          list.name,
          style: pw.TextStyle(
            fontSize: size * 1.6,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (list.details case final details?)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: size * 0.2),
            child: pw.Text(details, style: muted),
          ),
        pw.SizedBox(height: size),
        ...body,
      ],
    ),
  );
  return doc;
}

/// [text] shortened with an ellipsis to the longest marker text
/// ([MarkerIcons.maxTextLength]); notes of older apps may be longer.
String shortenMarkerText(String text) {
  final chars = text.characters;
  return chars.length <= MarkerIcons.maxTextLength
      ? text
      : '${chars.take(MarkerIcons.maxTextLength - 1).toString().trimRight()}…';
}
