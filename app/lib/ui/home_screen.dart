import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../sync/sync_controller.dart';
import '../sync/update_check.dart';
import '../update/update_providers.dart';
import 'sets/sets_screen.dart';
import 'settings_screen.dart';
import 'songs/songs_screen.dart';
import 'widgets/app_update.dart';
import 'widgets/dialogs.dart';
import 'widgets/logo.dart';
import 'widgets/update_required_banner.dart';

/// Main navigation: sets, songs, settings. On wide screens the rail shows
/// the logo mark at its top.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  static const _pages = [SetsScreen(), SongsScreen(), SettingsScreen()];

  /// How long the hint about a newer release stays (ADR-0036).
  static const _updateHintDuration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    // A newer release (ADR-0036): one short hint per version. Also for an
    // update already known from an earlier start.
    ref.listenManual(updateCheckProvider, (_, version) {
      if (version == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify(version));
    }, fireImmediately: true);
  }

  /// Shows the hint for [version] once. Only while the main navigation is on
  /// top, so never in live mode or while editing; otherwise on a later start.
  void _notify(String version) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final check = ref.read(updateCheckProvider.notifier);
    if (!check.shouldNotify(version)) return;
    check.markNotified(version);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('update-available-snackbar'),
          // Goes away by itself, despite the action: a hint, not a question.
          persist: false,
          duration: _updateHintDuration,
          content: Text(l10n.updateAvailableTitle(version)),
          // The Windows app installs it itself (ADR-0035), after asking.
          action: ref.read(installableUpdateProvider) == version
              ? SnackBarAction(
                  key: const Key('update-available-install'),
                  label: l10n.appUpdateInstall,
                  onPressed: () => installAppUpdate(context, version),
                )
              : SnackBarAction(
                  label: l10n.updateAvailableDetails,
                  onPressed: () => launchUrl(
                    releasePageUrl(version),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The first sync after signing in on this device applied the settings
    // of the account (ADR-0027).
    ref.listen(syncControllerProvider.select((s) => s.lastReport), (_, report) {
      if (report?.settingsTakenOver ?? false) {
        showMessage(context, l10n.settingsTakenOver);
      }
    });
    // A dot on the settings, where the update is described (ADR-0036).
    final update = ref.watch(updateCheckProvider) != null;
    final destinations = [
      (Icons.queue_music_outlined, Icons.queue_music, l10n.navSets, false),
      (Icons.library_music_outlined, Icons.library_music, l10n.navSongs, false),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings, update),
    ];
    Widget icon(IconData data, bool dot) => Badge(
      key: dot ? const Key('update-available-dot') : null,
      isLabelVisible: dot,
      child: Icon(data),
    );
    final pages = IndexedStack(index: _tab, children: _pages);
    // Above all tabs when the server refused this version (ADR-0029); the
    // banner takes the top inset, so the app bars below do not add it again.
    final body = ref.watch(updateRequiredProvider)
        ? Column(
            children: [
              SafeArea(bottom: false, child: const UpdateRequiredBanner()),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: pages,
                ),
              ),
            ],
          )
        : pages;

    if (MediaQuery.sizeOf(context).width >= 720) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(
                  label: 'setDING',
                  image: true,
                  child: const SetdingMark(key: Key('nav-logo'), size: 40),
                ),
              ),
              destinations: [
                for (final (outlined, selected, label, dot) in destinations)
                  NavigationRailDestination(
                    icon: icon(outlined, dot),
                    selectedIcon: icon(selected, dot),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final (outlined, selected, label, dot) in destinations)
            NavigationDestination(
              icon: icon(outlined, dot),
              selectedIcon: icon(selected, dot),
              label: label,
            ),
        ],
      ),
    );
  }
}
