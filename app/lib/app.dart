import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'l10n/generated/app_localizations.dart';
import 'midi/midi_connection.dart';
import 'providers.dart';
import 'settings/settings.dart';
import 'sync/auth_providers.dart';
import 'sync/sync_controller.dart';
import 'ui/account/person_name_form.dart';
import 'ui/deep_links.dart';
import 'ui/routes.dart';
import 'ui/start_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/app_shortcuts.dart';
import 'ui/widgets/escape_goes_back.dart';

/// Root widget: theme, localization (ADR-0008), navigation with a URL per
/// screen (ADR-0065), invitation links (ADR-0005), the sign-in gate of the
/// web client (ADR-0018) and the prompt for a missing full name (ADR-0062).
class SetdingApp extends ConsumerStatefulWidget {
  const SetdingApp({super.key, this.home});

  /// Overrides the start screen and the main navigation (used in tests):
  /// `/` shows it, the other screens open above it.
  final Widget? home;

  static ThemeData theme(
    Brightness brightness, [
    AccentColor accent = AccentColor.brand,
  ]) => appTheme(brightness, accent);

  @override
  ConsumerState<SetdingApp> createState() => _SetdingAppState();
}

class _SetdingAppState extends ConsumerState<SetdingApp> {
  late GoRouter _router = _createRouter();

  GoRouter _createRouter() {
    final home = widget.home;
    return createAppRouter(
      home: home == null
          ? null
          : (_) => CompleteNamePrompt(child: DeepLinkListener(child: home)),
      shell: (_, navigation) => CompleteNamePrompt(
        child: DeepLinkListener(child: StartScreen(navigation: navigation)),
      ),
      redirect: (_, state) => _redirect(state.uri),
      initialLocation: kIsWeb ? webStartLocation(Uri.base) : AppPaths.overview,
    );
  }

  @override
  void didUpdateWidget(SetdingApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tests pump the app again with another start screen: a new router
    // starts there, as MaterialApp's home did.
    if (!identical(oldWidget.home, widget.home)) {
      final old = _router;
      _router = _createRouter();
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  /// The web client shows only the sign-in gate (on the overview, ADR-0018)
  /// and the invitation screens to visitors who are not signed in; a link
  /// they opened is opened after signing in.
  String? _redirect(Uri uri) {
    if (!ref.read(webClientProvider)) return null;
    final signedIn = ref.read(authProvider) != null;
    final path = uri.path;
    if (signedIn) return _next(uri);
    final open =
        path == AppPaths.overview ||
        path == AppPaths.join ||
        path == AppPaths.signIn ||
        path.startsWith(AppPaths.invite(''));
    if (open) return null;
    return Uri(
      path: AppPaths.overview,
      queryParameters: {AppPaths.nextParameter: uri.toString()},
    ).toString();
  }

  /// The link a signed-out web visitor opened, on the overview's URL.
  static String? _next(Uri uri) {
    final next = uri.queryParameters[AppPaths.nextParameter];
    if (uri.path != AppPaths.overview || next == null) return null;
    return next.startsWith('/') ? next : null;
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only what the app shell needs: other settings do not rebuild it.
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final accent = ref.watch(settingsProvider.select((s) => s.accent));
    final locale = ref.watch(settingsProvider.select((s) => s.locale));
    // Keeps the sync running while the app is open (ADR-0004).
    ref.watch(syncControllerProvider);
    // Keeps the keyboard connected from app start (ADR-0039), without
    // rebuilding the app when its state changes.
    ref.listen(midiConnectionProvider, (_, _) {});
    // Signed in on the web: on to the link opened before (_redirect). Not
    // a refresh of the router, which would bring back a sign-in screen that
    // is closing.
    ref.listen(authProvider.select((u) => u != null), (_, signedIn) {
      if (!signedIn || !ref.read(webClientProvider)) return;
      if (_next(_router.state.uri) case final next?) _router.go(next);
    });
    // Esc goes back on every screen, like the app bar's back button (#726).
    // ? lists all shortcuts (#729).
    return EscapeGoesBack(
      child: ShortcutHelpKey(
        child: MaterialApp.router(
          routerConfig: _router,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: SetdingApp.theme(Brightness.light, accent),
          darkTheme: SetdingApp.theme(Brightness.dark, accent),
          themeMode: themeMode,
          locale: locale,
          supportedLocales: supportedUiLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeListResolutionCallback: (locales, supported) =>
              resolveLocale(null, locales ?? const []),
        ),
      ),
    );
  }
}
