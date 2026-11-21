import 'package:chordpro/chordpro.dart';
import 'package:flutter/services.dart';

/// Closes brackets and section blocks while typing in the ChordPro editor
/// (#747), see [autoClose].
///
/// A formatter rather than key handling, so software keyboards (Android,
/// iOS) get it too; the closing part lands in the same undo step as the
/// keystroke. Text set by the editor itself (snippets, commands) does not
/// pass formatters and stays as it is.
class AutoCloseFormatter extends TextInputFormatter {
  const AutoCloseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final old = oldValue.selection;
    final sel = newValue.selection;
    // While an IME composes a word, the text is not final yet.
    if (!old.isValid ||
        !sel.isValid ||
        !sel.isCollapsed ||
        (newValue.composing.isValid && !newValue.composing.isCollapsed) ||
        oldValue.text == newValue.text) {
      return newValue;
    }
    final edit = autoClose(
      oldValue.text,
      old.start,
      old.end,
      newValue.text,
      sel.baseOffset,
    );
    if (edit == null) return newValue;
    return TextEditingValue(
      text: edit.text,
      selection: TextSelection(
        baseOffset: edit.base,
        extentOffset: edit.extent,
      ),
    );
  }
}
