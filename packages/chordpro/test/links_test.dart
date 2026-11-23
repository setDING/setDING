import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('parseSongLink', () {
    test('URL and label', () {
      final link = parseSongLink(' https://youtu.be/abc | Live 2009 ')!;
      expect(link.uri.toString(), 'https://youtu.be/abc');
      expect(link.label, 'Live 2009');
      expect(link.service, LinkService.youtube);
      expect(link.domain, 'youtu.be');
    });

    test('without label, the whole value is the URL (spaces allowed)', () {
      final link = parseSongLink('https://example.com/my song.mp3')!;
      expect(link.label, isNull);
      expect(link.uri.path, '/my%20song.mp3');
    });

    test('URL with spaces and a label', () {
      final link = parseSongLink('https://example.com/a b c | Demo')!;
      expect(link.uri.toString(), 'https://example.com/a%20b%20c');
      expect(link.label, 'Demo');
    });

    test('the label starts after the last |', () {
      final link = parseSongLink('https://example.com/?q=a|b | Label')!;
      expect(link.uri.queryParameters['q'], 'a|b');
      expect(link.label, 'Label');
    });

    test('empty label is none', () {
      expect(parseSongLink('https://example.com |')!.label, isNull);
    });

    test('missing scheme gets https', () {
      final link = parseSongLink('open.spotify.com/track/1')!;
      expect(link.uri.scheme, 'https');
      expect(link.service, LinkService.spotify);
    });

    test('no usable URL', () {
      expect(parseSongLink(''), isNull);
      expect(parseSongLink('| Label'), isNull);
      expect(parseSongLink('just text'), isNull);
      expect(parseSongLink('ftp://example.com/a'), isNull);
      expect(parseSongLink('javascript:alert(1)'), isNull);
    });
  });

  test('services from the host', () {
    expect(linkServiceOf('www.youtube.com'), LinkService.youtube);
    expect(linkServiceOf('music.youtube.com'), LinkService.youtube);
    expect(linkServiceOf('open.spotify.com'), LinkService.spotify);
    expect(linkServiceOf('music.apple.com'), LinkService.appleMusic);
    expect(linkServiceOf('soundcloud.com'), LinkService.soundcloud);
    expect(linkServiceOf('www.deezer.com'), LinkService.deezer);
    expect(linkServiceOf('tidal.com'), LinkService.tidal);
    expect(linkServiceOf('notyoutube.com'), LinkService.other);
    expect(linkServiceOf('apple.com'), LinkService.other);
  });

  test('domain drops www.', () {
    expect(parseSongLink('https://www.youtube.com/x')!.domain, 'youtube.com');
  });

  test('Song.links in document order, unusable values skipped', () {
    final song = parseChordPro('''
{title: T}
{x_link: https://youtu.be/a | One}
{x_link: nonsense}
{x_link: https://open.spotify.com/track/b}
''');
    expect(song.links, [
      SongLink(uri: Uri.parse('https://youtu.be/a'), label: 'One'),
      SongLink(uri: Uri.parse('https://open.spotify.com/track/b')),
    ]);
  });

  test('songLinkDirective', () {
    expect(songLinkDirective(' https://a.com '), '{x_link: https://a.com}');
    expect(
      songLinkDirective('https://a.com', label: ' Live '),
      '{x_link: https://a.com | Live}',
    );
    expect(
      songLinkDirective('https://a.com', label: ''),
      '{x_link: https://a.com}',
    );
  });

  group('addSourceLink', () {
    test('after the last link', () {
      const source = '{title: T}\n{x_link: https://a.com}\n{key: G}\n\nLa';
      expect(
        addSourceLink(source, 'https://b.com', label: 'B'),
        '{title: T}\n{x_link: https://a.com}\n{x_link: https://b.com | B}\n'
        '{key: G}\n\nLa',
      );
    });

    test('at the end of the header without links', () {
      expect(
        addSourceLink('{title: T}\n{key: G}\n\n[G]La', 'https://a.com'),
        '{title: T}\n{key: G}\n{x_link: https://a.com}\n\n[G]La',
      );
      expect(
        addSourceLink('{title: T}', 'https://a.com'),
        '{title: T}\n{x_link: https://a.com}\n',
      );
      expect(addSourceLink('', 'https://a.com'), '{x_link: https://a.com}\n');
    });

    test('only in the first song', () {
      const source = '{title: A}\n\nLa\n{new_song}\n{x_link: https://x.com}';
      expect(
        parseChordPro(
          addSourceLink(source, 'https://a.com'),
        ).links.single.domain,
        'a.com',
      );
    });
  });

  group('replaceSourceLink', () {
    const source =
        '{title: T}\n{x_link: nonsense}\n{x_link: https://a.com}\n'
        '  {x_link: https://b.com | B}\n{key: G}\n\nLa';

    test('replaces the link at the index of Song.links', () {
      expect(parseChordPro(source).links.map((l) => l.domain), [
        'a.com',
        'b.com',
      ]);
      expect(
        replaceSourceLink(source, 1, 'https://c.com', label: 'C'),
        '{title: T}\n{x_link: nonsense}\n{x_link: https://a.com}\n'
        '  {x_link: https://c.com | C}\n{key: G}\n\nLa',
      );
      expect(
        replaceSourceLink(source, 0, 'https://c.com'),
        '{title: T}\n{x_link: nonsense}\n{x_link: https://c.com}\n'
        '  {x_link: https://b.com | B}\n{key: G}\n\nLa',
      );
    });

    test('removes the line without a URL', () {
      expect(
        replaceSourceLink(source, 0, null),
        '{title: T}\n{x_link: nonsense}\n'
        '  {x_link: https://b.com | B}\n{key: G}\n\nLa',
      );
      expect(
        replaceSourceLink('{title: T}\n{x_link: https://a.com}', 0, null),
        '{title: T}',
      );
      expect(replaceSourceLink('{x_link: https://a.com}', 0, null), '');
    });

    test('leaves the source unchanged without such a link', () {
      expect(replaceSourceLink(source, 2, 'https://c.com'), source);
      const twoSongs = '{title: A}\n{new_song}\n{x_link: https://x.com}';
      expect(replaceSourceLink(twoSongs, 0, null), twoSongs);
    });
  });

  group('songSelectUri', () {
    test('links a CCLI song number to its SongSelect page', () {
      expect(
        songSelectUri(' 7114209 '),
        Uri.parse('https://songselect.ccli.com/songs/7114209'),
      );
    });

    test('is null without a plain number', () {
      expect(songSelectUri(null), isNull);
      expect(songSelectUri(''), isNull);
      expect(songSelectUri('abc'), isNull);
      expect(songSelectUri('12/../34'), isNull);
      expect(songSelectUri('12 34'), isNull);
    });

    test('comes from {x_ccli} of a song', () {
      expect(
        parseChordPro('{title: T}\n{x_ccli: 7114209}\n\nLa').songSelect,
        Uri.parse('https://songselect.ccli.com/songs/7114209'),
      );
      expect(parseChordPro('{title: T}\n\nLa').songSelect, isNull);
    });
  });
}
