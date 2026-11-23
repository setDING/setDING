import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'midi/midi_connection.dart';
import 'settings/settings.dart';
import 'sync/sync_controller.dart';
import 'ui/account/person_name_form.dart';
import 'ui/deep_links.dart';
import 'ui/start_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/app_shortcuts.dart';
import 'ui/widgets/escape_goes_back.dart';

/// Root widget: theme, localization (ADR-0008), navigation, invitation
/// links (ADR-0005), the sign-in gate of the web client (ADR-0018) and the
/// prompt for a missing full name (ADR-0062).
class SetdingApp extends ConsumerStatefulWidget {
  const SetdingApp({super.key, this.home});

  /// Overrides the start screen (used in tests).
  final Widget? home;

  static ThemeData theme(
    Brightness brightness, [
    AccentColor accent = AccentColor.brand,
  ]) => appTheme(brightness, accent);

  @override
  ConsumerState<SetdingApp> createState() => _SetdingAppState();
}

class _SetdingAppState extends ConsumerState<SetdingApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

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
    // Esc goes back on every screen, like the app bar's back button (#726).
    // ? lists all shortcuts (#729).
    return EscapeGoesBack(
      child: ShortcutHelpKey(
        child: MaterialApp(
          navigatorKey: _navigatorKey,
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
          home: CompleteNamePrompt(
            child: DeepLinkListener(
              navigatorKey: _navigatorKey,
              child: widget.home ?? const StartScreen(),
            ),
          ),
        ),
      ),
    );
  }
}
