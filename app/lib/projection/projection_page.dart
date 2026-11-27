/// The projected page (ADR-0068 §3): an app asset with placeholders for
/// the few texts it needs, filled in from the app's language.
library;

import 'dart:convert';

/// The asset of the projected page.
const projectionPageAsset = 'assets/projection/index.html';

/// The page [template] (the asset) with `{{lang}}` and `{{fullScreen}}`
/// filled in, HTML-escaped.
String projectionPage(
  String template, {
  required String lang,
  required String fullScreen,
}) {
  const escape = HtmlEscape(HtmlEscapeMode.attribute);
  return template
      .replaceAll('{{lang}}', escape.convert(lang))
      .replaceAll('{{fullScreen}}', escape.convert(fullScreen));
}
