import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/band_view.dart' show BandView;
import '../data/database.dart' show SongEntry;
import '../data/person_name.dart';
import '../providers.dart';
import 'account/sign_in_screen.dart';
import 'bands/band_screen.dart';
import 'bands/bands_screen.dart';
import 'bands/close_organization.dart' show ClosedOrganizationsScreen;
import 'bands/delete_band.dart' show DeletedBandsScreen;
import 'bands/join_screen.dart';
import 'bands/organization_screen.dart';
import 'live/live_screen.dart';
import 'overview/overview_screen.dart';
import 'overview/recent_changes.dart' show RecentChangesScreen;
import 'sets/repertoire_screen.dart';
import 'sets/set_screen.dart';
import 'sets/sets_screen.dart';
import 'settings/midi_test_screen.dart';
import 'settings/song_display_settings.dart' show SongDisplayEditorScreen;
import 'settings_screen.dart';
import 'songs/library_usage_screen.dart';
import 'songs/song_editor_screen.dart';
import 'songs/song_screen.dart';
import 'songs/songs_screen.dart';
import 'trash/trash_screen.dart';
import 'widgets/logo.dart' show SplashScreen;

/// The paths of the app's screens (ADR-0065). Screens are opened with
/// `context.push(AppPaths.…)`, never with a page route of their own, so
/// every screen has a URL: the browser's back and forward buttons follow
/// the app, a reload keeps the screen and a link can open it.
///
/// Records are named by their id (the same on every device), never by a
/// name. What a screen needs besides the path travels as a JSON `extra`
/// (see the `…Extra` helpers), which the browser history keeps; a screen
/// opened without it (a reload, a link) works without it.
abstract final class AppPaths {
  static const overview = '/';
  static const sets = '/sets';
  static const songs = '/songs';
  static const settings = '/settings';

  static String set(String setId) => '/sets/$setId';

  /// Live mode of a set at its item [index], or at its first song.
  static String setLive(
    String setId, {
    int index = 0,
    bool firstSong = false,
  }) => Uri(
    path: '/sets/$setId/live',
    queryParameters: {
      if (firstSong) 'first': '1' else if (index > 0) 'index': '$index',
    },
  ).toString().replaceFirst(RegExp(r'\?$'), '');

  static const songNew = '/songs/new';
  static String song(String songId) => '/songs/$songId';
  static String songEdit(String songId) => '/songs/$songId/edit';

  /// Live mode of a song by itself, with [attachmentId] showing that PDF.
  static String songLive(String songId, {String? attachmentId}) => Uri(
    path: '/songs/$songId/live',
    queryParameters: {'attachment': ?attachmentId},
  ).toString().replaceFirst(RegExp(r'\?$'), '');

  static String settingsCategory(SettingsCategory category) =>
      '/settings/${category.name}';
  static const songDisplayEditor = '/settings/display-editor';
  static const midiTest = '/settings/midi-test';

  static const bands = '/bands';
  static const closedOrganizations = '/bands/closed';
  static String band(String bandId) => '/bands/$bandId';
  static String repertoire(String bandId) => '/bands/$bandId/repertoire';
  static String setsTrash(String bandId) => '/bands/$bandId/trash';
  static String organization(String organizationId) =>
      '/organizations/$organizationId';
  static String deletedBands(String organizationId) =>
      '/organizations/$organizationId/deleted-bands';
  static String songsTrash(String libraryId) => '/libraries/$libraryId/trash';
  static String libraryUsage(String libraryId) => '/libraries/$libraryId/usage';
  static const recentChanges = '/recent-changes';

  static const join = '/join';
  static String invite(String token) => '/invite/$token';
  static const signIn = '/sign-in';

  /// The query parameter of the overview with the location a signed-out
  /// web visitor wanted, opened after signing in.
  static const nextParameter = 'next';
}

/// The location the web client was opened at: the page's own URL. The
/// engine's default route can be `/` although the page was loaded at a
/// deeper path (a reload, a link), so the router starts here instead.
String webStartLocation(Uri page) {
  final path = page.path.isEmpty ? AppPaths.overview : page.path;
  return Uri(
    path: path,
    query: page.query.isEmpty ? null : page.query,
  ).toString();
}

/// The extra of [AppPaths.song]: the set it was opened from (#729) and
/// whether to pick a PDF right away.
Map<String, Object?> songExtra({
  List<String>? setSongs,
  int setIndex = 0,
  bool pickPdfOnOpen = false,
}) => {
  'setSongs': ?setSongs,
  if (setSongs != null) 'setIndex': setIndex,
  if (pickPdfOnOpen) 'pickPdf': true,
};

/// The extra of [AppPaths.songEdit] and [AppPaths.songNew].
Map<String, Object?> editorExtra({
  String? initialSource,
  bool selectFirstProblem = false,
}) => {'source': ?initialSource, if (selectFirstProblem) 'problem': true};

/// The extra of [AppPaths.signIn].
Map<String, Object?> signInExtra({
  bool signUp = false,
  String? invite,
  ({PersonName name, String? email})? prefill,
}) => {
  if (signUp) 'signUp': true,
  'invite': ?invite,
  if (prefill != null)
    'prefill': {
      'first': prefill.name.firstName,
      'last': prefill.name.lastName,
      'nickname': prefill.name.nickname,
      'email': prefill.email,
    },
};

Map<String, Object?> _extra(GoRouterState state) =>
    state.extra is Map ? (state.extra! as Map).cast<String, Object?>() : {};

/// The app's router (ADR-0065). The main navigation is a
/// [StatefulShellRoute] built by [shell]; every other screen is a child of
/// a tab's route shown above it on the root navigator, so a screen opened
/// from a link or after a reload still has a back button to its tab.
///
/// With [home] (tests) there is no main navigation: [home] is shown above
/// an empty page (so it may close itself, as a pushed screen does) and the
/// tabs' screens are plain routes.
GoRouter createAppRouter({
  required Widget Function(
    BuildContext context,
    StatefulNavigationShell navigation,
  )
  shell,
  WidgetBuilder? home,
  GoRouterRedirect? redirect,
  String initialLocation = AppPaths.overview,
}) {
  // The URL shows the screen on top, also one opened with push.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final root = GlobalKey<NavigatorState>(debugLabel: 'root');
  final routes = _Routes(root);
  return GoRouter(
    navigatorKey: root,
    initialLocation: home != null ? _testHome : initialLocation,
    // The given location wins over the engine's default route, which can
    // miss the page's path on the web (see [webStartLocation]).
    overridePlatformDefaultLocation: home != null || initialLocation != '/',
    redirect: redirect,
    routes: home != null
        ? [
            GoRoute(
              path: AppPaths.overview,
              builder: (_, _) => const Scaffold(),
              routes: [
                GoRoute(
                  path: _testHome.substring(1),
                  pageBuilder: (context, state) =>
                      _HomePage(key: state.pageKey, child: home(context)),
                ),
                ...routes.overview,
                GoRoute(
                  path: 'sets',
                  parentNavigatorKey: root,
                  builder: (_, _) => const SetsScreen(),
                  routes: routes.sets,
                ),
                GoRoute(
                  path: 'songs',
                  parentNavigatorKey: root,
                  builder: (_, _) => const SongsScreen(),
                  routes: routes.songs,
                ),
                GoRoute(
                  path: 'settings',
                  parentNavigatorKey: root,
                  builder: (_, _) => const SettingsScreen(),
                  routes: routes.settings,
                ),
              ],
            ),
          ]
        : [
            StatefulShellRoute.indexedStack(
              builder: (context, _, navigation) => shell(context, navigation),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: AppPaths.overview,
                      builder: (_, _) => const OverviewScreen(),
                      routes: routes.overview,
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: AppPaths.sets,
                      builder: (_, _) => const SetsScreen(),
                      routes: routes.sets,
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: AppPaths.songs,
                      builder: (_, _) => const SongsScreen(),
                      routes: routes.songs,
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: AppPaths.settings,
                      builder: (_, _) => const SettingsScreen(),
                      routes: routes.settings,
                    ),
                  ],
                ),
              ],
            ),
          ],
  );
}

/// Where a test's home screen is shown ([createAppRouter]).
const _testHome = '/test-home';

/// The page of a test's home screen: like the start screen, it offers no
/// back button, although the empty page below it could be popped.
class _HomePage extends Page<void> {
  const _HomePage({super.key, required this.child});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _HomeRoute(this);
}

class _HomeRoute extends PageRoute<void> with MaterialRouteTransitionMixin {
  _HomeRoute(_HomePage page) : super(settings: page);

  @override
  Widget buildContent(BuildContext context) => (settings as _HomePage).child;

  @override
  bool get maintainState => true;

  @override
  bool get impliesAppBarDismissal => false;
}

/// The screens below the tabs, each shown on the root navigator.
class _Routes {
  _Routes(this.root);

  final GlobalKey<NavigatorState> root;

  GoRoute _page(
    String path,
    GoRouterWidgetBuilder builder, {
    List<RouteBase> routes = const [],
    ExitCallback? onExit,
  }) => GoRoute(
    path: path,
    parentNavigatorKey: root,
    builder: builder,
    routes: routes,
    onExit: onExit,
  );

  /// Children of the overview: the screens that belong to no tab.
  late final List<RouteBase> overview = [
    _page(
      'bands',
      (_, _) => const BandsScreen(),
      routes: [
        _page('closed', (_, _) => const ClosedOrganizationsScreen()),
        _page(
          ':bandId',
          (_, s) => BandScreen(bandId: s.pathParameters['bandId']!),
          routes: [
            _page(
              'repertoire',
              (_, s) => _BandRoute(
                bandId: s.pathParameters['bandId']!,
                builder: (band) => RepertoireScreen(band: band),
              ),
            ),
            _page(
              'trash',
              (_, s) => TrashScreen.sets(bandId: s.pathParameters['bandId']!),
            ),
          ],
        ),
      ],
    ),
    _page(
      'organizations/:organizationId',
      (_, s) => OrganizationScreen(
        organizationId: s.pathParameters['organizationId']!,
      ),
      routes: [
        _page(
          'deleted-bands',
          (_, s) => DeletedBandsScreen(
            organizationId: s.pathParameters['organizationId']!,
          ),
        ),
      ],
    ),
    _page(
      'libraries/:libraryId/trash',
      (_, s) => TrashScreen.songs(libraryId: s.pathParameters['libraryId']!),
    ),
    _page(
      'libraries/:libraryId/usage',
      (_, s) => _LibraryUsageRoute(libraryId: s.pathParameters['libraryId']!),
    ),
    _page('recent-changes', (_, _) => const RecentChangesScreen()),
    _page('join', (_, _) => const JoinScreen()),
    _page(
      'invite/:token',
      (_, s) => JoinScreen(initialLink: s.pathParameters['token']),
    ),
    _page('sign-in', (_, s) {
      final extra = _extra(s);
      final prefill = extra['prefill'] is Map
          ? (extra['prefill']! as Map).cast<String, Object?>()
          : null;
      return SignInScreen(
        signUp: extra['signUp'] == true,
        invite: extra['invite'] as String?,
        prefill: prefill == null
            ? null
            : (
                name: PersonName(
                  firstName: prefill['first'] as String? ?? '',
                  lastName: prefill['last'] as String? ?? '',
                  nickname: prefill['nickname'] as String? ?? '',
                ),
                email: prefill['email'] as String?,
              ),
      );
    }),
  ];

  late final List<RouteBase> sets = [
    _page(
      ':setId',
      (_, s) => SetScreen(setId: s.pathParameters['setId']!),
      routes: [
        _page('live', (_, s) {
          final query = s.uri.queryParameters;
          return LiveRoute(
            location: s.uri.toString(),
            setId: s.pathParameters['setId']!,
            index: int.tryParse(query['index'] ?? '') ?? 0,
            firstSong: query['first'] == '1',
          );
        }),
      ],
    ),
  ];

  late final List<RouteBase> songs = [
    _page(
      'new',
      (_, s) => SongEditorScreen(initialSource: _extra(s)['source'] as String?),
      onExit: (_, _) => SongEditorScreen.mayLeaveOpenEditor(),
    ),
    _page(
      ':songId',
      (_, s) {
        final extra = _extra(s);
        return SongScreen(
          songId: s.pathParameters['songId']!,
          pickPdfOnOpen: extra['pickPdf'] == true,
          setSongs: (extra['setSongs'] as List?)?.cast<String>(),
          setIndex: extra['setIndex'] as int? ?? 0,
        );
      },
      routes: [
        _page('edit', (_, s) {
          final extra = _extra(s);
          return _EditorRoute(
            songId: s.pathParameters['songId']!,
            source: extra['source'] as String?,
            selectFirstProblem: extra['problem'] == true,
          );
        }, onExit: (_, _) => SongEditorScreen.mayLeaveOpenEditor()),
        _page(
          'live',
          (_, s) => LiveRoute(
            location: s.uri.toString(),
            songId: s.pathParameters['songId']!,
            attachmentId: s.uri.queryParameters['attachment'],
          ),
        ),
      ],
    ),
  ];

  late final List<RouteBase> settings = [
    _page('display-editor', (_, _) => const SongDisplayEditorScreen()),
    _page('midi-test', (_, _) => const MidiTestScreen()),
    _page(':category', (context, s) {
      final category = SettingsCategory.values
          .asNameMap()[s.pathParameters['category']];
      if (category == null) return const _GoTo(AppPaths.settings);
      return SettingsScreen.categoryPage(category);
    }),
  ];
}

/// Live mode from its path: the items [LiveScreen.openSet] or
/// [LiveScreen.openSong] loaded, or loaded here after a reload or a link.
class LiveRoute extends ConsumerStatefulWidget {
  const LiveRoute({
    super.key,
    required this.location,
    this.setId,
    this.index = 0,
    this.firstSong = false,
    this.songId,
    this.attachmentId,
  });

  final String location;
  final String? setId;
  final int index;
  final bool firstSong;
  final String? songId;
  final String? attachmentId;

  @override
  ConsumerState<LiveRoute> createState() => _LiveRouteState();
}

class _LiveRouteState extends ConsumerState<LiveRoute> {
  List<LiveItem>? _items;
  int _start = 0;

  @override
  void initState() {
    super.initState();
    final loaded = LiveScreen.takeLoaded(widget.location);
    if (loaded != null) {
      _items = loaded;
      _start = widget.index;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final List<LiveItem> items;
    var start = 0;
    if (widget.setId case final setId?) {
      final loaded = await LiveScreen.loadSet(
        container,
        setId,
        index: widget.index,
        firstSong: widget.firstSong,
      );
      items = loaded.items;
      start = loaded.start;
    } else {
      items = await LiveScreen.loadSong(
        container,
        widget.songId!,
        attachmentId: widget.attachmentId,
      );
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _start = start;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) return const Scaffold(body: SplashScreen(busy: true));
    // Nothing to play (an empty or missing set): back where it came from.
    if (items.isEmpty) {
      return _GoTo(
        widget.setId != null
            ? AppPaths.set(widget.setId!)
            : AppPaths.song(widget.songId!),
      );
    }
    return LiveScreen(items: items, initialIndex: _start);
  }
}

/// The editor of a song: with the [source] the song screen passed, or the
/// song's source loaded here after a reload or a link, never an empty text
/// that saving would write over the song.
class _EditorRoute extends ConsumerStatefulWidget {
  const _EditorRoute({
    required this.songId,
    required this.source,
    required this.selectFirstProblem,
  });

  final String songId;
  final String? source;
  final bool selectFirstProblem;

  @override
  ConsumerState<_EditorRoute> createState() => _EditorRouteState();
}

class _EditorRouteState extends ConsumerState<_EditorRoute> {
  late final Future<SongEntry?> _song = ref
      .read(songRepositoryProvider)
      .getSong(widget.songId);

  @override
  Widget build(BuildContext context) {
    Widget editor(String source) => SongEditorScreen(
      songId: widget.songId,
      initialSource: source,
      selectFirstProblem: widget.selectFirstProblem,
    );
    if (widget.source case final source?) return editor(source);
    return FutureBuilder(
      future: _song,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: SplashScreen(busy: true));
        }
        final song = snapshot.data;
        if (song == null) return _GoTo(AppPaths.song(widget.songId));
        return editor(song.chordproSource);
      },
    );
  }
}

/// A screen of a band of the person, looked up by its id.
class _BandRoute extends ConsumerWidget {
  const _BandRoute({required this.bandId, required this.builder});

  final String bandId;
  final Widget Function(BandView band) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bands = ref.watch(bandsProvider);
    final band = bands.value?.where((b) => b.id == bandId).firstOrNull;
    if (band != null) return builder(band);
    if (bands.isLoading) return const Scaffold(body: SplashScreen(busy: true));
    return const _GoTo(AppPaths.sets);
  }
}

/// The library usage of a library of the person, looked up by its id.
class _LibraryUsageRoute extends ConsumerWidget {
  const _LibraryUsageRoute({required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      LibraryUsageScreen(library: ref.watch(libraryProvider(libraryId)));
}

/// Goes to [location] instead of showing a screen that cannot be shown.
class _GoTo extends StatefulWidget {
  const _GoTo(this.location);

  final String location;

  @override
  State<_GoTo> createState() => _GoToState();
}

class _GoToState extends State<_GoTo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(widget.location);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
