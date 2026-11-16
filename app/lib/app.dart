import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'settings/settings.dart';
import 'sync/sync_controller.dart';
import 'ui/deep_links.dart';
import 'ui/start_screen.dart';

/// Root widget: theme, localization (ADR-0008), navigation, invitation
/// links (ADR-0005) and the sign-in gate of the web client (ADR-0018).
class RealChordApp extends ConsumerStatefulWidget {
  const RealChordApp({super.key, this.home});

  /// Overrides the start screen (used in tests).
  final Widget? home;

  static ThemeData theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F51B5),
      brightness: brightness,
    ),
    useMaterial3: true,
  );

  @override
  ConsumerState<RealChordApp> createState() => _RealChordAppState();
}

class _RealChordAppState extends ConsumerState<RealChordApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Only what the app shell needs: other settings do not rebuild it.
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final locale = ref.watch(settingsProvider.select((s) => s.locale));
    // Keeps the sync running while the app is open (ADR-0004).
    ref.watch(syncControllerProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: RealChordApp.theme(Brightness.light),
      darkTheme: RealChordApp.theme(Brightness.dark),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('de', 'CH'), Locale('de'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (locales, supported) =>
          resolveLocale(null, locales ?? const []),
      home: DeepLinkListener(
        navigatorKey: _navigatorKey,
        child: widget.home ?? const StartScreen(),
      ),
    );
  }
}
