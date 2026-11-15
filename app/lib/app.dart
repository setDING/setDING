import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'settings/settings.dart';
import 'ui/home_screen.dart';

/// Root widget: theme, localization (ADR-0008) and navigation.
class RealChordApp extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [Locale('de', 'CH'), Locale('de'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (locales, supported) =>
          resolveLocale(null, locales ?? const []),
      home: home ?? const HomeScreen(),
    );
  }
}
