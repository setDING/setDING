import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/backup_providers.dart' show autoBackupProvider;
import '../data/trash.dart' show trashRetention;
import '../sync/sync_backend.dart' show ClosedOrganization;
import '../l10n/generated/app_localizations.dart';
import '../platform/web_client.dart' show webClientProvider;
import '../settings/settings.dart' show sharedPreferencesProvider;
import '../sync/auth_providers.dart' show clientVersionProvider;
import '../sync/sync_controller.dart';
import '../sync/update_check.dart';
import '../update/update_providers.dart';
import '../update/whats_new.dart';
import 'backup/auto_backup_tiles.dart';
import 'backup/full_backup.dart';
import 'home_tab.dart';
import 'sync_hints.dart';
import 'songs/song_reports.dart' show listenForReportAnswers;
import 'songs/refused_uploads.dart' show listenForRefusedUploads;
import 'widgets/app_update.dart';
import 'widgets/dialogs.dart';
import 'widgets/logo.dart';
import 'widgets/update_required_banner.dart';
import 'widgets/whats_new_dialog.dart';

/// Main navigation: overview (the start screen, ADR-0045), sets, songs,
/// settings ([HomeTab]). On wide screens the rail shows the logo mark at its
/// top.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.navigation});

  /// The tabs with their own navigation history (ADR-0065): the tab shown is
  /// part of the URL (`/`, `/sets`, `/songs`, `/settings`).
  final StatefulNavigationShell navigation;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Key of the navigation entry of the tab [i], e.g. `nav-sets`.
  static Key _navKey(int i) => Key('nav-${HomeTab.values[i].name}');

  /// How long the hint about a newer release stays (ADR-0036).
  static const _updateHintDuration = Duration(seconds: 6);

  /// How long the hint about the notes of a new version stays (ADR-0041).
  static const _whatsNewHintDuration = Duration(seconds: 8);

  /// Checks the automatic backup when the app goes to the background.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Another screen switched tabs (e.g. the overview's *To do* card): the
    // main navigation goes there, which changes the URL (ADR-0065).
    ref.listenManual(homeTabProvider, (_, tab) {
      if (tab.index != widget.navigation.currentIndex) {
        widget.navigation.goBranch(tab.index);
      }
    });
    // The automatic backup of the local library (ADR-0054): at the start
    // and when the app goes to the background, then a hint if it failed.
    _lifecycle = AppLifecycleListener(onHide: _autoBackup);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _autoBackup();
      _autoBackupHint();
    });
    // A newer release (ADR-0036): one short hint per version. Also for an
    // update already known from an earlier start.
    ref.listenManual(updateCheckProvider, (_, version) {
      if (version == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify(version));
    }, fireImmediately: true);
    // The local library is not on a server: a reminder when it changed and
    // was not backed up for 30 days (#639), at most every 7 days.
    ref.listenManual(backupReminderProvider, (_, days) {
      if (days.value case final days?) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _remind(days));
      }
    }, fireImmediately: true);
    // After an update, the notes of the new version (ADR-0041), once.
    ref.listenManual(pendingWhatsNewProvider, (_, pending) {
      if (pending == null) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _offerWhatsNew(pending),
      );
    }, fireImmediately: true);
  }

  /// Offers the notes of [pending] once, like the update hint: only while
  /// the main navigation is on top, otherwise at a later start.
  void _offerWhatsNew(({VersionNotes? notes}) pending) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final current = ref.read(clientVersionProvider);
    final seen = ref.read(sharedPreferencesProvider).getString(whatsNewSeenKey);
    if (current == null || seen == current) return;
    markWhatsNewSeen(ref);
    final notes = pending.notes;
    if (notes == null) return;
    final l10n = AppLocalizations.of(context);
    // Queued behind another hint, e.g. the update hint, not replacing it.
    showMessageOn(
      ScaffoldMessenger.of(context),
      l10n.whatsNewAvailable(current),
      key: const Key('whats-new-snackbar'),
      duration: _whatsNewHintDuration,
      queue: true,
      action: (
        key: const Key('whats-new-show'),
        label: l10n.whatsNewShow,
        onPressed: () => showWhatsNew(context, notes),
      ),
    );
  }

  /// Makes [homeTabProvider] follow the tab of the URL, e.g. after the
  /// browser's back button.
  void _syncTab() {
    final tab = HomeTab.values[widget.navigation.currentIndex];
    if (ref.read(homeTabProvider) != tab) {
      ref.read(homeTabProvider.notifier).select(tab);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Writes an automatic backup when one is due; only while the main
  /// navigation is on top, so never in live mode or during an import or
  /// export (their dialogs are on top).
  Future<void> _autoBackup() async {
    if (!mounted || ref.read(webClientProvider)) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final l10n = AppLocalizations.of(context);
    final written = await ref
        .read(autoBackupProvider.notifier)
        .controller
        .runIfDue(libraryName: l10n.bandLocal);
    if (written) ref.invalidate(backupReminderProvider);
  }

  /// The hint about a failed automatic backup, at most once a day, with an
  /// action to choose the folder again.
  void _autoBackupHint() {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final controller = ref.read(autoBackupProvider.notifier).controller;
    final error = controller.state.error;
    if (error == null || !controller.takeErrorHint()) return;
    final l10n = AppLocalizations.of(context);
    showMessageOn(
      ScaffoldMessenger.of(context),
      l10n.autoBackupHintFailed(autoBackupErrorText(l10n, error)),
      key: const Key('auto-backup-failed'),
      duration: _whatsNewHintDuration,
      queue: true,
      action: (
        key: const Key('auto-backup-failed-action'),
        label: l10n.autoBackupChooseFolder,
        onPressed: () => chooseAutoBackupFolder(context, ref),
      ),
    );
  }

  /// Reminds of a backup of the local library, like the other hints only
  /// while the main navigation is on top (never in live mode).
  void _remind(int days) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (!takeBackupReminder(ref)) return;
    final l10n = AppLocalizations.of(context);
    // Queued behind another hint, not replacing it.
    showMessageOn(
      ScaffoldMessenger.of(context),
      l10n.backupReminder(days),
      key: const Key('backup-reminder'),
      duration: _whatsNewHintDuration,
      queue: true,
      action: (
        key: const Key('backup-reminder-action'),
        label: l10n.backupReminderAction,
        onPressed: () async {
          await exportFullBackup(context, ref);
          ref.invalidate(backupReminderProvider);
        },
      ),
    );
  }

  /// Shows the hint for [version] once. Only while the main navigation is on
  /// top, so never in live mode or while editing; otherwise on a later start.
  void _notify(String version) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final check = ref.read(updateCheckProvider.notifier);
    if (!check.shouldNotify(version)) return;
    check.markNotified(version);
    final l10n = AppLocalizations.of(context);
    // Goes away by itself, despite the action: a hint, not a question.
    showMessageOn(
      ScaffoldMessenger.of(context),
      l10n.updateAvailableTitle(version),
      key: const Key('update-available-snackbar'),
      duration: _updateHintDuration,
      // The Windows app installs it itself (ADR-0035), after asking.
      action: ref.read(installableUpdateProvider) == version
          ? (
              key: const Key('update-available-install'),
              label: l10n.appUpdateInstall,
              onPressed: () => installAppUpdate(context, version),
            )
          : (
              key: null,
              label: l10n.updateAvailableDetails,
              onPressed: () => launchUrl(
                updatePageUrl(
                  version,
                  googlePlay: ref.read(installedFromGooglePlayProvider),
                ),
                mode: LaunchMode.externalApplication,
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
      // Bands that were deleted or the person was removed from (ADR-0044).
      final gone = report?.goneBands ?? const <String>[];
      if (gone.isNotEmpty) {
        showMessage(context, l10n.bandsGone(gone.length, gone.join(', ')));
      }
      // Organizations closed by one of their admins (ADR-0044).
      for (final ClosedOrganization org
          in report?.closedOrganizations ?? const <ClosedOrganization>[]) {
        final days = trashRetention.inDays;
        showMessage(
          context,
          org.closedBy == null
              ? l10n.orgClosedNoticeAnonymous(org.name, days)
              : l10n.orgClosedNotice(org.name, org.closedBy!, days),
        );
      }
    });
    // What others changed during live mode, summed up once (#691).
    listenForLiveSummary(context, ref);
    // Answers to the person's mistake reports (ADR-0060).
    listenForReportAnswers(context, ref);
    // Attachments the server refused to take (#1225).
    listenForRefusedUploads(context, ref);
    // A dot on the settings, where the update is described (ADR-0036).
    final update = ref.watch(updateCheckProvider) != null;
    final destinations = [
      (Icons.dashboard_outlined, Icons.dashboard, l10n.navOverview, false),
      (Icons.queue_music_outlined, Icons.queue_music, l10n.navSets, false),
      (Icons.library_music_outlined, Icons.library_music, l10n.navSongs, false),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings, update),
    ];
    Widget icon(IconData data, bool dot) => Badge(
      key: dot ? const Key('update-available-dot') : null,
      isLabelVisible: dot,
      child: Icon(data),
    );
    // The URL decides the tab; [homeTabProvider] follows it, and other
    // screens switch tabs through it (see initState).
    final tab = widget.navigation.currentIndex;
    if (ref.read(homeTabProvider).index != tab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncTab();
      });
    }
    void select(int i) =>
        ref.read(homeTabProvider.notifier).select(HomeTab.values[i]);
    final pages = widget.navigation;
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

    if (MediaQuery.sizeOf(context).width >= navigationRailWidth) {
      NavigationRailDestination railDestination(int i) {
        final (outlined, selected, label, dot) = destinations[i];
        return NavigationRailDestination(
          icon: icon(outlined, dot),
          selectedIcon: icon(selected, dot),
          label: Text(label, key: _navKey(i)),
        );
      }

      // Settings are pinned to the bottom of the rail, apart from the
      // content tabs (#937). A second rail with the one destination keeps
      // the look, indicator and animation of the others; its intrinsic
      // height lets it sit in the rail's trailing slot.
      final settings = HomeTab.settings.index;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              key: const Key('nav-rail'),
              selectedIndex: tab < settings ? tab : null,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              scrollable: true,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(
                  label: 'setDING',
                  image: true,
                  child: const SetdingMark(key: Key('nav-logo'), size: 40),
                ),
              ),
              destinations: [
                for (var i = 0; i < settings; i++) railDestination(i),
              ],
              trailingAtBottom: true,
              trailing: IntrinsicHeight(
                child: NavigationRail(
                  key: const Key('nav-rail-bottom'),
                  selectedIndex: tab == settings ? 0 : null,
                  onDestinationSelected: (_) => select(settings),
                  labelType: NavigationRailLabelType.all,
                  destinations: [railDestination(settings)],
                ),
              ),
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
        selectedIndex: tab,
        onDestinationSelected: select,
        destinations: [
          for (final (i, (outlined, selected, label, dot))
              in destinations.indexed)
            NavigationDestination(
              key: _navKey(i),
              icon: icon(outlined, dot),
              selectedIcon: icon(selected, dot),
              label: label,
            ),
        ],
      ),
    );
  }
}
