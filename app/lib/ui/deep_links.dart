import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_backend.dart';
import 'bands/join_screen.dart';
import '../util/log.dart';

const _log = Log('links');

/// Links that open the app (ADR-0005): App Links / Universal Links
/// (`https://api.realchord.app/invite/<token>`) and `realchord://invite/<token>`,
/// including the link that started the app. Overridden in tests.
final incomingLinksProvider = Provider<Stream<Uri>>((ref) {
  try {
    return AppLinks().uriLinkStream;
  } catch (e) {
    _log.warning('Deep links not available', e);
    return const Stream.empty();
  }
});

/// Opens the join screen for invitation links.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
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
    final token = inviteTokenFrom(uri.toString());
    if (token == null) return;
    widget.navigatorKey.currentState?.push(
      MaterialPageRoute<bool>(builder: (_) => JoinScreen(initialLink: token)),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
