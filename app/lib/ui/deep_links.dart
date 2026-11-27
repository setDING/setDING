import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../sync/sync_backend.dart';
import 'routes.dart';
import '../util/log.dart';

const _log = Log('links');

/// Links that open the app (ADR-0005, ADR-0065): App Links / Universal
/// Links (`https://app.setding.app/sets/<id>`, `…/invite/<token>`) and
/// `setding://` links, including the link that started the app. Overridden
/// in tests.
final incomingLinksProvider = Provider<Stream<Uri>>((ref) {
  try {
    return AppLinks().uriLinkStream;
  } catch (e) {
    _log.warning('Deep links not available', e);
    return const Stream.empty();
  }
});

/// The screen a link opens, or null for a link the app does not know
/// (ADR-0065): invitations (`/invite/<token>`, ADR-0005) and sets and songs
/// (`/sets/<id>`, `/songs/<id>`), as App Links / Universal Links on any host
/// (the platform only hands over the app's own) or as `setding://` links
/// (`setding://sets/<id>`), which desktops open.
String? appLocationOf(Uri uri) {
  final List<String> segments;
  if (uri.scheme == 'setding') {
    segments = [uri.host, ...uri.pathSegments];
  } else if (uri.scheme == 'https' || uri.scheme == 'http') {
    segments = uri.pathSegments;
  } else {
    return null;
  }
  final parts = segments.where((s) => s.isNotEmpty).toList();
  if (parts.length != 2) return null;
  final id = parts[1];
  return switch (parts[0]) {
    'invite' => switch (inviteTokenFrom('invite/$id')) {
      final token? => AppPaths.invite(token),
      null => null,
    },
    'sets' when _recordId.hasMatch(id) => AppPaths.set(id),
    // `/songs/new` is the editor of a new song, not a song.
    'songs' when _recordId.hasMatch(id) && id != 'new' => AppPaths.song(id),
    _ => null,
  };
}

/// The id of a set or song in a link: no path, query or other surprises.
final _recordId = RegExp(r'^[A-Za-z0-9-]{1,64}$');

/// Opens the screen of a link through the router ([appLocationOf]).
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref
        .read(incomingLinksProvider)
        .listen(
          _open,
          onError: (Object e) => _log.warning('Deep link failed', e),
        );
  }

  void _open(Uri uri) {
    final location = appLocationOf(uri);
    if (location == null || !mounted) return;
    // On the web the router already opened the link of the page (ADR-0065).
    final router = GoRouter.of(context);
    if (router.state.uri.path == location) return;
    router.push(location);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
