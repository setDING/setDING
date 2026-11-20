import 'package:flutter_riverpod/flutter_riverpod.dart';

/// From this width the main navigation is a rail on the left instead of a
/// bar at the bottom, and the overview has two columns (ADR-0045).
const navigationRailWidth = 720.0;

/// The tabs of the main navigation, in order (ADR-0045).
enum HomeTab { overview, sets, songs, settings }

/// The tab shown by the main navigation. The app always starts on the
/// overview (ADR-0045, not a setting); other screens switch tabs through
/// it, e.g. the overview's *To do* card to the song list. Disposed with the
/// main navigation, so it starts on the overview again after signing in.
class HomeTabNotifier extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.overview;

  void select(HomeTab tab) => state = tab;
}

final homeTabProvider = NotifierProvider.autoDispose<HomeTabNotifier, HomeTab>(
  HomeTabNotifier.new,
);
