/// Song sources: setDING's custom directive `{x_link}`, e.g.
/// `{x_link: https://www.youtube.com/watch?v=… | Live 2009}`.
///
/// The directive can be repeated. The label after the last `|` is optional;
/// without `|` the whole value is the URL, so URLs may contain spaces.
library;

/// Service a [SongLink] points to, detected from its host.
enum LinkService {
  youtube,
  spotify,
  appleMusic,
  soundcloud,
  deezer,
  tidal,
  other,
}

/// One source of a song from `{x_link}`.
class SongLink {
  const SongLink({required this.uri, this.label});

  /// The link, always `http` or `https` with a host.
  final Uri uri;

  /// Label after `|`; null if none was given.
  final String? label;

  /// Host without a leading `www.`, e.g. `open.spotify.com`.
  String get domain =>
      uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;

  /// Service detected from the host.
  LinkService get service => linkServiceOf(uri.host);

  @override
  bool operator ==(Object other) =>
      other is SongLink && other.uri == uri && other.label == label;

  @override
  int get hashCode => Object.hash(uri, label);

  @override
  String toString() => label == null ? '$uri' : '$uri | $label';
}

const _serviceHosts = {
  'youtube.com': LinkService.youtube,
  'youtu.be': LinkService.youtube,
  'spotify.com': LinkService.spotify,
  'spotify.link': LinkService.spotify,
  'music.apple.com': LinkService.appleMusic,
  'soundcloud.com': LinkService.soundcloud,
  'deezer.com': LinkService.deezer,
  'deezer.page.link': LinkService.deezer,
  'tidal.com': LinkService.tidal,
};

/// The service of [host] (`music.youtube.com` is YouTube).
LinkService linkServiceOf(String host) {
  final h = host.toLowerCase();
  for (final MapEntry(:key, :value) in _serviceHosts.entries) {
    if (h == key || h.endsWith('.$key')) return value;
  }
  return LinkService.other;
}

/// Parses the value of `{x_link}`. Returns null when it holds no `http` or
/// `https` URL with a host; a URL without a scheme (`youtu.be/…`) gets
/// `https://`.
SongLink? parseSongLink(String value) {
  var url = value.trim();
  String? label;
  final bar = url.lastIndexOf('|');
  if (bar >= 0) {
    label = url.substring(bar + 1).trim();
    url = url.substring(0, bar).trim();
    if (label.isEmpty) label = null;
  }
  if (url.isEmpty) return null;
  if (!url.contains('://')) url = 'https://$url';
  final uri = Uri.tryParse(url);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      !uri.host.contains('.')) {
    return null;
  }
  return SongLink(uri: uri, label: label);
}

/// The `{x_link}` directive for [url] and an optional [label], for
/// inserting into a source.
String songLinkDirective(String url, {String? label}) {
  final l = label?.trim() ?? '';
  return l.isEmpty ? '{x_link: ${url.trim()}}' : '{x_link: ${url.trim()} | $l}';
}
