import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings.dart';

/// Whether the past sets on the sets tab are collapsed (stored per device,
/// #265). Collapsed until the user expands them on this device (#282).
class PastSetsCollapsedNotifier extends Notifier<bool> {
  static const _key = 'pastSetsCollapsed';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> toggle() async {
    state = !state;
    await ref.read(sharedPreferencesProvider).setBool(_key, state);
  }
}

final pastSetsCollapsedProvider =
    NotifierProvider<PastSetsCollapsedNotifier, bool>(
      PastSetsCollapsedNotifier.new,
    );

/// The set chosen on the sets tab (#266): shown next to the list on wide
/// screens. Kept outside the widgets, so it survives a change of layout
/// (e.g. rotating a tablet); null shows the next gig.
class SelectedSetNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? setId) => state = setId;
}

final selectedSetProvider = NotifierProvider<SelectedSetNotifier, String?>(
  SelectedSetNotifier.new,
);
