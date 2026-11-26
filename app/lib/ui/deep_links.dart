import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../sync/sync_backend.dart';
import 'routes.dart';
import '../util/log.dart';

const _log = Log('links');

/// Links that open the app (ADR-0005): App Links / Universal Links
/// (`https://api.setding.app/invite/<token>`) and `setding://invite/<token>`,
/// including the link that started the app. Overridden in tests.
final incomingLinksProvider = Provider<Stream<Uri>>((ref) {
  try {
    return AppLinks().uriLinkStream;
  } catch (e) {
    _log.warning('Deep links not available', e);
    return const Stream.empty();
  }
});

/// Opens the join screen for invitation links, through the router.
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
    final token = inviteTokenFrom(uri.toString());
    if (token == null) return;
    if (!mounted) return;
    // On the web the router already opened the link of the page (ADR-0065).
    final router = GoRouter.of(context);
    final location = AppPaths.invite(token);
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
