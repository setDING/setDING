import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/app_menu_entry.dart';

/// Where the desktop's application menu entry of setDING points (#1006).
enum AppMenuEntryState {
  /// No entry.
  missing,

  /// An entry that starts this AppImage.
  installed,

  /// An entry that starts another copy (an unpacked tar.gz, another
  /// AppImage): adding replaces it.
  elsewhere,
}

/// The application menu entry of the Linux AppImage (ADR-0038, #1006): the
/// AppImage has no desktop entry or icon outside its file, so the app adds
/// them for the current user on request.
abstract class AppMenuEntry {
  /// Whether there is an entry, and whether it starts this AppImage.
  Future<AppMenuEntryState> state();

  /// Writes the desktop entry and the icon (replacing another entry).
  Future<void> install();

  /// Removes the desktop entry and the icon.
  Future<void> remove();

  /// Points an entry added by an AppImage at this AppImage again when the
  /// file it starts is gone (the AppImage was moved or renamed). Returns
  /// whether it changed the entry.
  Future<bool> repairIfMoved();
}

/// The application menu entry of this app, or null where it has none (all
/// platforms but the Linux AppImage).
final appMenuEntryProvider = Provider<AppMenuEntry?>(
  (ref) => createAppMenuEntry(),
);

/// The state of [appMenuEntryProvider]'s entry, with adding and removing it.
final appMenuEntryStateProvider =
    AsyncNotifierProvider<AppMenuEntryController, AppMenuEntryState?>(
      AppMenuEntryController.new,
    );

class AppMenuEntryController extends AsyncNotifier<AppMenuEntryState?> {
  @override
  Future<AppMenuEntryState?> build() async =>
      ref.watch(appMenuEntryProvider)?.state();

  /// Adds the entry (or replaces another one).
  Future<void> install() => _change((entry) => entry.install());

  /// Removes the entry.
  Future<void> remove() => _change((entry) => entry.remove());

  Future<void> _change(Future<void> Function(AppMenuEntry) change) async {
    final entry = ref.read(appMenuEntryProvider);
    if (entry == null) return;
    try {
      await change(entry);
    } finally {
      state = AsyncData(await entry.state());
    }
  }
}
