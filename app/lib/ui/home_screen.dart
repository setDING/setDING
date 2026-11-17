import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import 'sets/sets_screen.dart';
import 'settings_screen.dart';
import 'songs/songs_screen.dart';
import 'widgets/logo.dart';

/// Main navigation: sets, songs, settings. On wide screens the rail shows
/// the logo mark at its top.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _pages = [SetsScreen(), SongsScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (Icons.queue_music_outlined, Icons.queue_music, l10n.navSets),
      (Icons.library_music_outlined, Icons.library_music, l10n.navSongs),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];
    final body = IndexedStack(index: _tab, children: _pages);

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
                for (final (icon, selected, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
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
          for (final (icon, selected, label) in destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}
